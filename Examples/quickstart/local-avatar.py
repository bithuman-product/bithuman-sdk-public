"""Local avatar -- load a .imx model, push audio, display video frames.

Setup:
    export BITHUMAN_API_SECRET=your_secret
    pip install -r requirements.txt

Usage:
    python local-avatar.py                              # auto-downloads a sample model
    python local-avatar.py --model avatar.imx           # use your own model
    python local-avatar.py --model avatar.imx --audio speech.wav
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path

import cv2

from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio

# Public sample model (112 MB, "Coach Mason" avatar from bithuman.ai)
SAMPLE_MODEL_URL = "https://tmoobjxlwcwvxvjeppzq.supabase.co/storage/v1/object/public/bithuman/A71DAR6308/coach_mason_resilience_guide_20251122_143604_311004.imx"
SAMPLE_MODEL_NAME = "sample-avatar.imx"


def download_sample_model() -> str:
    """Download the sample .imx model if not already cached."""
    cache_dir = Path.home() / ".cache" / "bithuman" / "models"
    cache_dir.mkdir(parents=True, exist_ok=True)
    model_path = cache_dir / SAMPLE_MODEL_NAME

    if model_path.exists():
        print(f"Using cached sample model: {model_path}")
        return str(model_path)

    print(f"Downloading sample avatar model (112 MB, one-time)...")
    print(f"  Source: bithuman.ai agent A71DAR6308 (Coach Mason)")
    print(f"  Saving: {model_path}")

    import urllib.request

    def _progress(block_num, block_size, total_size):
        downloaded = block_num * block_size
        if total_size > 0:
            pct = min(100, downloaded * 100 // total_size)
            mb = downloaded / (1024 * 1024)
            total_mb = total_size / (1024 * 1024)
            print(f"\r  [{pct:3d}%] {mb:.0f} / {total_mb:.0f} MB", end="", flush=True)

    urllib.request.urlretrieve(SAMPLE_MODEL_URL, model_path, reporthook=_progress)
    print()  # newline after progress
    print(f"  Done!")
    return str(model_path)


async def main():
    p = argparse.ArgumentParser(description="bitHuman local avatar quickstart")
    p.add_argument("--model", help="Path to .imx model file (auto-downloads sample if omitted)")
    p.add_argument("--audio", default="speech.wav", help="Path to WAV/MP3 audio file (default: speech.wav)")
    args = p.parse_args()

    # Validate API secret
    secret = os.environ.get("BITHUMAN_API_SECRET")
    if not secret:
        print("Error: BITHUMAN_API_SECRET not set.")
        print()
        print("  1. Go to https://www.bithuman.ai → Developer → API Keys")
        print("  2. Copy your API secret")
        print("  3. Run: export BITHUMAN_API_SECRET='your_secret_here'")
        sys.exit(1)

    # Get model path (download sample if not specified)
    model_path = args.model or download_sample_model()
    if not Path(model_path).exists():
        print(f"Error: Model file not found: {model_path}")
        print("  Download one from https://www.bithuman.ai/#explore (click ... → Download)")
        sys.exit(1)

    # Check audio file
    if not Path(args.audio).exists():
        print(f"Error: Audio file not found: {args.audio}")
        print("  A sample speech.wav is included in this directory.")
        sys.exit(1)

    # Load the avatar runtime
    print(f"Loading model: {model_path}")
    print("  (First run may take 30s for format conversion — this is a one-time cost)")
    runtime = await AsyncBithuman.create(model_path=model_path, api_secret=secret)
    await runtime.start()
    print("  Model loaded!")

    # Push audio
    print(f"Playing audio: {args.audio}")
    pcm, sr = load_audio(args.audio)
    pcm = float32_to_int16(pcm)
    chunk = sr // 100
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr, last_chunk=False)
    await runtime.flush()

    # Display frames in a window
    print("Displaying avatar (press 'q' to quit)...")
    async for frame in runtime.run():
        if frame.has_image:
            cv2.imshow("bitHuman Avatar", frame.bgr_image)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    cv2.destroyAllWindows()
    await runtime.stop()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
