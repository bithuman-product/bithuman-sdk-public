"""Play an audio file through a self-hosted bitHuman Essence avatar.

Loads a local .imx model on CPU, streams audio in, shows the avatar in a
window, plays the synchronized audio back through the default speaker.

Usage:
    python quickstart.py --model avatar.imx --audio-file speech.wav
"""

import argparse
import asyncio
import os
import threading

import cv2
import numpy as np
import sounddevice as sd
from dotenv import load_dotenv

from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio

load_dotenv()


def make_speaker(sample_rate: int = 16_000):
    """Return (output_stream, append_pcm). append_pcm(int16_bytes) is thread-safe."""
    buf, lock = bytearray(), threading.Lock()

    def callback(outdata, frames, _time, _status):
        n = frames * 2  # int16 = 2 bytes
        with lock:
            take = min(len(buf), n)
            outdata[: take // 2, 0] = np.frombuffer(buf[:take], dtype=np.int16)
            outdata[take // 2 :, 0] = 0
            del buf[:take]

    stream = sd.OutputStream(
        samplerate=sample_rate, channels=1, dtype="int16", blocksize=640, callback=callback
    )

    def append(pcm: bytes):
        with lock:
            buf.extend(pcm)

    return stream, append


async def stream_audio(runtime: AsyncBithuman, audio_file: str) -> None:
    pcm, sr = load_audio(audio_file)
    pcm = float32_to_int16(pcm)
    chunk = sr // 100  # 10 ms
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr, last_chunk=False)
    await runtime.flush()


async def main() -> None:
    p = argparse.ArgumentParser(description="bitHuman Essence — play audio through a local avatar")
    p.add_argument("--model", default=os.getenv("BITHUMAN_MODEL_PATH"), help="Path to .imx model")
    p.add_argument("--audio-file", required=True, help="Path to WAV/MP3/FLAC/M4A")
    p.add_argument("--api-secret", default=os.getenv("BITHUMAN_API_SECRET"))
    args = p.parse_args()

    if not args.model:
        raise SystemExit("Provide --model or set BITHUMAN_MODEL_PATH (download .imx from https://www.bithuman.ai)")
    if not args.api_secret:
        raise SystemExit("Set BITHUMAN_API_SECRET")

    runtime = await AsyncBithuman.create(model_path=args.model, api_secret=args.api_secret)
    w, h = runtime.get_frame_size()
    cv2.namedWindow("bitHuman", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("bitHuman", w, h)

    speaker, append_pcm = make_speaker()
    speaker.start()
    await runtime.start()
    pusher = asyncio.create_task(stream_audio(runtime, args.audio_file))
    try:
        async for frame in runtime.run():
            if frame.has_image:
                cv2.imshow("bitHuman", frame.bgr_image)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
            if frame.audio_chunk:
                append_pcm(frame.audio_chunk.array.tobytes())
    finally:
        pusher.cancel()
        speaker.stop()
        cv2.destroyAllWindows()
        await runtime.stop()


if __name__ == "__main__":
    asyncio.run(main())
