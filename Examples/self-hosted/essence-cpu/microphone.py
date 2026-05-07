"""Real-time microphone input driving a self-hosted bitHuman Essence avatar.

Captures audio from your microphone, detects speech vs silence,
and animates the avatar in real time with optional audio echo.

Usage:
    python microphone.py --model avatar.imx
    python microphone.py --model avatar.imx --echo   # hear yourself back
"""

import argparse
import asyncio
import os
import sys
import threading

import cv2
import numpy as np
import sounddevice as sd
from dotenv import load_dotenv
from loguru import logger

from bithuman import AsyncBithuman
from bithuman.utils import FPSController

load_dotenv()
logger.remove()
logger.add(sys.stdout, level="INFO")

SAMPLE_RATE = 16000
MIC_CHUNK = 160       # 10ms at 16kHz
SILENCE_TIMEOUT = 3.0  # seconds of silence before draining stale audio


async def read_and_push_audio(
    runtime: AsyncBithuman,
    audio_queue: asyncio.Queue,
    volume: float = 1.0,
    silent_threshold_db: int = -40,
):
    """Read mic audio from queue and push to bitHuman runtime with silence detection."""
    last_speech_time = asyncio.get_running_loop().time()

    while True:
        audio_data, rms_db = await audio_queue.get()
        now = asyncio.get_running_loop().time()

        if rms_db > silent_threshold_db:
            last_speech_time = now
        elif now - last_speech_time > SILENCE_TIMEOUT:
            while audio_queue.qsize() > 10:
                audio_queue.get_nowait()

        if volume != 1.0:
            samples = np.frombuffer(audio_data, dtype=np.int16)
            samples = np.clip(samples * volume, -32768, 32767).astype(np.int16)
            audio_data = samples.tobytes()

        await runtime.push_audio(audio_data, SAMPLE_RATE, last_chunk=False)


async def main():
    parser = argparse.ArgumentParser(description="bitHuman Essence -- microphone input")
    parser.add_argument("--model", default=os.getenv("BITHUMAN_MODEL_PATH"),
                        help="Path to .imx avatar model")
    parser.add_argument("--api-secret", default=os.getenv("BITHUMAN_API_SECRET"))
    parser.add_argument("--volume", type=float, default=1.0, help="Mic volume multiplier")
    parser.add_argument("--silent-threshold-db", type=int, default=-40)
    parser.add_argument("--echo", action="store_true", help="Play avatar audio back through speakers")
    args = parser.parse_args()

    if not args.model:
        print("Error: Provide --model or set BITHUMAN_MODEL_PATH")
        print("Download .imx models from https://www.bithuman.ai")
        return

    runtime = await AsyncBithuman.create(
        model_path=args.model, api_secret=args.api_secret, input_buffer_size=5,
    )

    width, height = runtime.get_frame_size()
    cv2.namedWindow("bitHuman", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("bitHuman", width, height)

    loop = asyncio.get_running_loop()
    audio_queue: asyncio.Queue = asyncio.Queue()
    speaker_buf = bytearray()
    speaker_lock = threading.Lock()

    def mic_callback(indata, frames, time_info, status):
        samples = indata[:, 0].copy()
        int16 = (samples * 32767).astype(np.int16)
        rms = np.sqrt(np.mean(samples ** 2))
        db = 20 * np.log10(rms + 1e-9)
        asyncio.run_coroutine_threadsafe(audio_queue.put((int16.tobytes(), db)), loop)

    def speaker_callback(outdata, frames, time_info, status):
        n_bytes = frames * 2
        with speaker_lock:
            avail = min(len(speaker_buf), n_bytes)
            outdata[:avail // 2, 0] = np.frombuffer(speaker_buf[:avail], dtype=np.int16)
            outdata[avail // 2:, 0] = 0
            del speaker_buf[:avail]

    mic_stream = sd.InputStream(
        samplerate=SAMPLE_RATE, channels=1, dtype="float32",
        blocksize=MIC_CHUNK, callback=mic_callback,
    )
    speaker_stream = None
    if args.echo:
        speaker_stream = sd.OutputStream(
            samplerate=SAMPLE_RATE, channels=1, dtype="int16",
            blocksize=640, callback=speaker_callback,
        )
        speaker_stream.start()

    mic_stream.start()
    logger.info("Microphone started -- press Q in the video window to quit")

    await runtime.start()
    mic_task = asyncio.create_task(
        read_and_push_audio(runtime, audio_queue, args.volume, args.silent_threshold_db)
    )

    fps = FPSController(target_fps=25)
    try:
        async for frame in runtime.run(idle_timeout=0.5):
            sleep_time = fps.wait_next_frame(sleep=False)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

            if frame.has_image:
                cv2.imshow("bitHuman", frame.bgr_image)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

            if args.echo and frame.audio_chunk:
                with speaker_lock:
                    speaker_buf.extend(frame.audio_chunk.array.tobytes())

            fps.update()
    finally:
        mic_task.cancel()
        mic_stream.stop()
        if speaker_stream:
            speaker_stream.stop()
        cv2.destroyAllWindows()
        await runtime.stop()


if __name__ == "__main__":
    asyncio.run(main())
