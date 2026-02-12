"""Real-time microphone input driving a bitHuman avatar.

Captures audio from your microphone, detects speech vs silence,
and animates the avatar in real time with optional audio echo.

Usage:
    python live_avatar.py --model avatar.imx
    python live_avatar.py --model avatar.imx --echo  # hear yourself back
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

SILENCE_TIMEOUT = 3.0  # seconds of silence before dropping buffered audio


async def read_and_push_audio(
    runtime: AsyncBithuman,
    audio_io: LocalAudioIO,
    volume: float = 1.0,
    silent_threshold_db: int = -40,
):
    """Read mic audio and push to bitHuman runtime with silence detection."""
    # Wait for microphone to be ready
    while audio_io._agent.input.audio is None:
        await asyncio.sleep(0.1)
    logger.info("Microphone ready")

    audio_stream = utils.audio.AudioByteStream(sample_rate=16000, num_channels=1, samples_per_channel=160)
    buffer: asyncio.Queue[rtc.AudioFrame] = asyncio.Queue()

    async def read_mic():
        async for frame in audio_io._agent.input.audio:
            for f in audio_stream.push(frame.data):
                await buffer.put(f)

    async def push_to_runtime():
        last_speech_time = asyncio.get_running_loop().time()
        speaking = True

        while True:
            frame = await buffer.get()
            now = asyncio.get_running_loop().time()

            if audio_io._micro_db > silent_threshold_db:
                last_speech_time = now
                speaking = True
            elif now - last_speech_time > SILENCE_TIMEOUT:
                # Drain stale audio when silent
                while buffer.qsize() > 10:
                    buffer.get_nowait()
                speaking = False

            audio_data = bytes(frame.data)
            if volume != 1.0 and speaking:
                samples = np.frombuffer(frame.data, dtype=np.int16)
                samples = np.clip(samples * volume, -32768, 32767).astype(np.int16)
                audio_data = samples.tobytes()

            await runtime.push_audio(audio_data, frame.sample_rate, last_chunk=False)

    await asyncio.gather(read_mic(), push_to_runtime())


async def main():
    parser = argparse.ArgumentParser(description="bitHuman live avatar — microphone input")
    parser.add_argument("--model", default=os.getenv("BITHUMAN_AVATAR_MODEL"))
    parser.add_argument("--api-secret", default=os.getenv("BITHUMAN_API_SECRET"))
    parser.add_argument("--volume", type=float, default=1.0, help="Mic volume multiplier")
    parser.add_argument("--silent-threshold-db", type=int, default=-40)
    parser.add_argument("--echo", action="store_true", help="Play avatar audio back through speakers")
    args = parser.parse_args()

    runtime = await AsyncBithuman.create(
        model_path=args.model, api_secret=args.api_secret, input_buffer_size=5,
    )

    audio_io = LocalAudioIO(AgentSession(), QueueAudioOutput(), buffer_size=3)
    await audio_io.start()

    video_player = LocalVideoPlayer(window_size=runtime.get_frame_size(), buffer_size=3)
    fps = FPSController(target_fps=25)

    mic_task = asyncio.create_task(
        read_and_push_audio(runtime, audio_io, args.volume, args.silent_threshold_db)
    )

    try:
        async for frame in runtime.run(out_buffer_empty=video_player.buffer_empty, idle_timeout=0.5):
            sleep_time = fps.wait_next_frame(sleep=False)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

            if frame.has_image:
                await video_player.capture_frame(frame, fps=fps.average_fps, exp_time=runtime.get_expiration_time())

            if args.echo and frame.audio_chunk:
                await audio_io.capture_frame(frame.audio_chunk)

            fps.update()
    finally:
        mic_task.cancel()
        await video_player.aclose()
        await audio_io.aclose()
        await runtime.stop()


if __name__ == "__main__":
    asyncio.run(main())
