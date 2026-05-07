"""bitHuman Expression on macOS — minimal SDK demo.

Loads a packed `.imx` Expression model, feeds it a WAV file, and writes
a lip-synced 25 FPS MP4 with the original audio muxed in.

No LLM, no STT/TTS, no LiveKit — just the SDK. Runs entirely on-device
on Apple Silicon (M3+) via the bundled Swift runtime.

Usage:
    export BITHUMAN_API_SECRET=...
    python quickstart.py \\
        --model expression.imx \\
        --audio speech.wav \\
        --output out.mp4

Optional: override the avatar face at load time with a portrait image.
    python quickstart.py --model expression.imx --audio speech.wav \\
        --identity alice.jpg --output alice.mp4
"""

import argparse
import asyncio
import os
import shutil
import subprocess
import sys
import wave

import cv2
import numpy as np

from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio


def _require_ffmpeg() -> None:
    """Fail fast with a friendly message when ffmpeg is missing.

    The default macOS install doesn't ship ffmpeg, and the subprocess
    failure that opencv/our mux step emits otherwise is cryptic.
    """
    if shutil.which("ffmpeg") is None:
        print(
            "\nffmpeg is not on your PATH.\n"
            "\n"
            "This demo muxes the rendered frames with the pushed audio into an\n"
            "mp4 and uses ffmpeg for that step. Install it once:\n"
            "\n"
            "    brew install ffmpeg        # macOS (Homebrew)\n"
            "    sudo apt install ffmpeg    # Debian / Ubuntu\n"
            "\n"
            "Then re-run this command.\n",
            file=sys.stderr,
        )
        sys.exit(2)


async def generate_video(
    model_path: str,
    audio_path: str,
    output_path: str,
    identity: str | None,
    api_secret: str,
) -> None:
    runtime = await AsyncBithuman.create(
        model_path=model_path,
        api_secret=api_secret,
        identity=identity,  # None → bundle's baked-in face
    )
    w, h = runtime.get_frame_size()
    print(f"[ready] {w}x{h}, identity={'override' if identity else 'default'}")

    pcm, sr = load_audio(audio_path)
    await runtime.push_audio(pcm.astype(np.float32), sr)
    await runtime.flush()
    print(f"[pushed] {len(pcm)/sr:.2f}s of audio @ {sr} Hz")

    frames: list[np.ndarray] = []
    audio_out: list[np.ndarray] = []
    async for frame in runtime.run():
        if frame.has_image:
            frames.append(np.ascontiguousarray(frame.bgr_image))
        if frame.audio_chunk is not None:
            audio_out.append(frame.audio_chunk.array.copy())
        if frame.end_of_speech:
            break
    await runtime.shutdown()

    if not frames:
        raise RuntimeError("pipeline produced no frames")

    # Write silent mp4 (video only), then mux with the daemon-returned
    # 24 kHz audio — that's the audio the lips are actually synced to.
    video_only = output_path + ".video.mp4"
    wav_only = output_path + ".wav"

    vw = cv2.VideoWriter(video_only, cv2.VideoWriter_fourcc(*"mp4v"), 25.0, (w, h))
    for f in frames:
        vw.write(f)
    vw.release()

    audio_samples = np.concatenate(audio_out) if audio_out else np.zeros(0, dtype=np.int16)
    if audio_samples.dtype != np.int16:
        audio_samples = float32_to_int16(audio_samples.astype(np.float32))
    with wave.open(wav_only, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(24_000)
        wf.writeframes(audio_samples.tobytes())

    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-i", video_only, "-i", wav_only,
         "-c:v", "copy", "-c:a", "aac",
         "-map", "0:v:0", "-map", "1:a:0",
         output_path],
        check=True,
    )
    os.remove(video_only)
    os.remove(wav_only)

    print(
        f"[done] {output_path} — {len(frames)} frames "
        f"({len(frames)/25.0:.2f}s video, {len(audio_samples)/24_000:.2f}s audio)"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="bitHuman Expression demo (macOS arm64 M3+).")
    parser.add_argument("--model", required=True, help="Path to packed .imx model file")
    parser.add_argument("--audio", required=True, help="Path to input WAV / MP3 / FLAC")
    parser.add_argument("--output", default="out.mp4", help="Output mp4 path")
    parser.add_argument("--identity", default=None,
                        help="Optional portrait .jpg/.png or pre-encoded .npy reference face")
    parser.add_argument("--api-secret", default=os.environ.get("BITHUMAN_API_SECRET"),
                        help="Defaults to $BITHUMAN_API_SECRET")
    args = parser.parse_args()

    if not args.api_secret:
        raise SystemExit("set BITHUMAN_API_SECRET or pass --api-secret")

    _require_ffmpeg()

    asyncio.run(generate_video(
        model_path=args.model,
        audio_path=args.audio,
        output_path=args.output,
        identity=args.identity,
        api_secret=args.api_secret,
    ))


if __name__ == "__main__":
    main()
