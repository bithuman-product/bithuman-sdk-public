"""Local avatar -- load a .imx model, push audio, display video frames.

Setup:
    export BITHUMAN_API_SECRET=your_secret
    pip install -r requirements.txt
    python local-avatar.py --model avatar.imx --audio speech.wav
"""

import argparse
import asyncio
import os

import cv2

from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True, help="Path to .imx model file")
    p.add_argument("--audio", required=True, help="Path to WAV/MP3 audio file")
    args = p.parse_args()

    secret = os.environ.get("BITHUMAN_API_SECRET")
    if not secret:
        raise SystemExit("Set BITHUMAN_API_SECRET env var")

    runtime = await AsyncBithuman.create(model_path=args.model, api_secret=secret)
    await runtime.start()

    # Push audio in 10ms chunks
    pcm, sr = load_audio(args.audio)
    pcm = float32_to_int16(pcm)
    chunk = sr // 100
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr, last_chunk=False)
    await runtime.flush()

    # Display frames
    async for frame in runtime.run():
        if frame.has_image:
            cv2.imshow("bitHuman", frame.bgr_image)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    cv2.destroyAllWindows()
    await runtime.stop()


if __name__ == "__main__":
    asyncio.run(main())
