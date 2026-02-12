"""bitHuman avatar with audio clip playback.

Press 1 to play the audio file, 2 to interrupt, q to quit.
"""

import argparse
import asyncio
import os
import sys
import threading

import cv2
import numpy as np
from dotenv import load_dotenv
from loguru import logger

from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio

try:
    import sounddevice as sd
except ImportError:
    sd = None

logger.remove()
logger.add(sys.stdout, level="INFO")

# --- Audio output via sounddevice callback ---
_audio_buf = bytearray()
_audio_lock = threading.Lock()


def _audio_callback(outdata, frames, _time, _status):
    with _audio_lock:
        n = frames * 2  # int16 = 2 bytes per sample
        chunk = bytes(_audio_buf[:n])
        del _audio_buf[:n]
    data = np.frombuffer(chunk, dtype=np.int16)
    outdata[: len(data), 0] = data
    outdata[len(data) :, 0] = 0


async def push_audio(runtime: AsyncBithuman, path: str, delay: float = 0.0):
    """Stream an audio file into the runtime."""
    audio_np, sr = load_audio(path)
    audio_np = float32_to_int16(audio_np)
    await asyncio.sleep(delay)
    chunk_size = sr // 100
    for i in range(0, len(audio_np), chunk_size):
        await runtime.push_audio(audio_np[i : i + chunk_size].tobytes(), sr, last_chunk=False)
    await runtime.flush()


async def main(args):
    runtime = await AsyncBithuman.create(
        model_path=args.model,
        token=args.token,
        api_secret=args.api_secret,
        insecure=args.insecure,
    )

    # Open audio output stream
    stream = None
    if sd:
        stream = sd.OutputStream(
            callback=_audio_callback, dtype="int16", channels=1,
            samplerate=16000, blocksize=640,
        )
        stream.start()

    # Open video window
    w, h = runtime.get_frame_size()
    cv2.namedWindow("bitHuman", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("bitHuman", w, h)

    await runtime.start()
    task = asyncio.create_task(push_audio(runtime, args.audio_file, delay=1.0)) if args.audio_file else None

    try:
        async for frame in runtime.run():
            if frame.has_image:
                cv2.imshow("bitHuman", frame.bgr_image)

            if frame.audio_chunk and stream:
                data = frame.audio_chunk.array
                if data.dtype == np.float32:
                    data = (data * 32768).astype(np.int16)
                with _audio_lock:
                    _audio_buf.extend(data.tobytes())

            key = cv2.waitKey(1) & 0xFF
            if key == ord("1") and args.audio_file:
                if task and not task.done():
                    task.cancel()
                task = asyncio.create_task(push_audio(runtime, args.audio_file))
            elif key == ord("2"):
                if task and not task.done():
                    task.cancel()
                runtime.interrupt()
            elif key == ord("q"):
                break
    finally:
        if task and not task.done():
            task.cancel()
        if stream:
            stream.stop()
            stream.close()
        cv2.destroyAllWindows()
        await runtime.stop()


if __name__ == "__main__":
    load_dotenv()

    parser = argparse.ArgumentParser(description="bitHuman avatar with audio clip playback")
    parser.add_argument("--model", default=os.environ.get("BITHUMAN_MODEL_PATH"), help="Path to .imx model")
    parser.add_argument("--token", default=os.environ.get("BITHUMAN_RUNTIME_TOKEN"), help="JWT token")
    parser.add_argument("--api-secret", default=os.environ.get("BITHUMAN_API_SECRET"), help="API secret")
    parser.add_argument("--audio-file", default=os.environ.get("BITHUMAN_AUDIO_PATH"), help="Audio file to play")
    parser.add_argument("--insecure", action="store_true", help="Disable SSL verification")
    args = parser.parse_args()

    try:
        asyncio.run(main(args))
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
