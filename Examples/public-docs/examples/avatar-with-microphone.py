"""bitHuman avatar driven by live microphone input.

Captures audio from the default microphone, detects silence, and streams
speech into the bitHuman runtime. Press q in the video window to quit.
"""

import argparse
import asyncio
import os
import sys

import numpy as np
from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import AgentSession, utils
from livekit.agents.voice.avatar import QueueAudioOutput
from loguru import logger

from bithuman import AsyncBithuman
from bithuman.utils import FPSController
from bithuman.utils.agent import LocalAudioIO, LocalVideoPlayer

load_dotenv()

logger.remove()
logger.add(sys.stdout, level="INFO")


async def stream_microphone(runtime: AsyncBithuman, audio_io: LocalAudioIO,
                            volume: float, silent_threshold_db: int):
    """Read microphone frames, apply volume, and push audio to the runtime."""
    # Wait for the audio input device to become available
    while audio_io._session.input.audio is None:
        await asyncio.sleep(0.1)
    logger.info("Audio input ready")

    buffer: asyncio.Queue[rtc.AudioFrame] = asyncio.Queue()
    resampler = utils.audio.AudioByteStream(sample_rate=24000, num_channels=1,
                                            samples_per_channel=240)

    async def fill_buffer():
        async for frame in audio_io._session.input.audio:
            for f in resampler.push(frame.data):
                await buffer.put(f)

    async def push_to_runtime():
        last_speech_time = asyncio.get_running_loop().time()
        silent_timeout = 3.0  # seconds
        speaking = True

        while True:
            frame = await buffer.get()
            audio_data = bytes(frame.data)

            if volume != 1.0 and speaking:
                arr = np.frombuffer(audio_data, dtype=np.int16)
                arr = np.clip(arr * volume, -32768, 32767).astype(np.int16)
                audio_data = arr.tobytes()

            await runtime.push_audio(audio_data, frame.sample_rate, last_chunk=False)

            now = asyncio.get_running_loop().time()
            if audio_io._micro_db > silent_threshold_db:
                last_speech_time = now
                speaking = True
            elif now - last_speech_time > silent_timeout:
                # Drain stale frames when user is silent
                while buffer.qsize() > 10:
                    try:
                        buffer.get_nowait()
                    except asyncio.QueueEmpty:
                        break
                speaking = False

    await asyncio.gather(fill_buffer(), push_to_runtime())


async def main(args):
    runtime = await AsyncBithuman.create(
        model_path=args.model,
        token=args.token,
        api_secret=args.api_secret,
        insecure=args.insecure,
        input_buffer_size=5,
    )

    audio_io = LocalAudioIO(AgentSession(), QueueAudioOutput(), buffer_size=3)
    await audio_io.start()

    mic_task = asyncio.create_task(
        stream_microphone(runtime, audio_io, args.volume, args.silent_threshold_db)
    )

    video_player = LocalVideoPlayer(window_size=runtime.get_frame_size(), buffer_size=3)
    fps = FPSController(target_fps=25)

    try:
        async for frame in runtime.run(out_buffer_empty=video_player.buffer_empty,
                                       idle_timeout=0.5):
            sleep_time = fps.wait_next_frame(sleep=False)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

            if frame.has_image:
                await video_player.capture_frame(
                    frame, fps=fps.average_fps,
                    exp_time=runtime.get_expiration_time(),
                )

            if args.echo and frame.audio_chunk is not None:
                await audio_io.capture_frame(frame.audio_chunk)

            fps.update()
    finally:
        if not mic_task.done():
            mic_task.cancel()
        await video_player.aclose()
        await audio_io.aclose()
        await runtime.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bitHuman avatar with microphone input")
    parser.add_argument("--model", default=os.environ.get("BITHUMAN_MODEL_PATH"), help="Path to .imx model")
    parser.add_argument("--token", default=os.environ.get("BITHUMAN_RUNTIME_TOKEN"), help="JWT token")
    parser.add_argument("--api-secret", default=os.environ.get("BITHUMAN_API_SECRET"), help="API secret")
    parser.add_argument("--insecure", action="store_true", help="Disable SSL verification")
    parser.add_argument("--volume", type=float, default=1.0, help="Microphone volume multiplier")
    parser.add_argument("--silent-threshold-db", type=int, default=-40, help="Silence threshold in dB")
    parser.add_argument("--echo", action="store_true", help="Echo avatar audio back through speakers")
    args = parser.parse_args()

    try:
        asyncio.run(main(args))
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
