"""CLI client to stream audio files to the bitHuman avatar server.

Usage:
    python client.py stream /path/to/audio.wav
    python client.py interrupt
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

import numpy as np
import websockets
from loguru import logger

try:
    import resampy
    import soundfile as sf
except ImportError:
    logger.error("Install deps: pip install soundfile resampy")
    sys.exit(1)

logger.remove()
logger.add(sys.stdout, level="INFO")

TARGET_SR = 16000
CHUNK_MS = 100


async def stream_audio(ws_url: str, audio_file: str):
    """Load an audio file, resample to 16kHz mono int16, and stream via WebSocket."""
    audio, sr = sf.read(audio_file)

    # Convert to mono
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)

    # Resample to 16kHz
    if sr != TARGET_SR:
        logger.info(f"Resampling {sr}Hz → {TARGET_SR}Hz")
        audio = resampy.resample(audio, sr_orig=sr, sr_new=TARGET_SR)

    # Convert float → int16
    if audio.dtype in (np.float32, np.float64):
        audio = np.clip(audio * 32767, -32768, 32767).astype(np.int16)

    chunk_samples = TARGET_SR * CHUNK_MS // 1000

    async with websockets.connect(ws_url) as ws:
        logger.info(f"Streaming {len(audio) / TARGET_SR:.1f}s of audio")

        for i in range(0, len(audio), chunk_samples):
            await ws.send(audio[i : i + chunk_samples].tobytes())

        await ws.send(json.dumps({"type": "end"}))
        logger.info("Done")


async def send_interrupt(ws_url: str):
    async with websockets.connect(ws_url) as ws:
        await ws.send(json.dumps({"type": "interrupt"}))
        logger.info("Interrupt sent")


def main():
    parser = argparse.ArgumentParser(description="bitHuman streaming client")
    parser.add_argument("--ws-url", default="ws://localhost:8765")
    sub = parser.add_subparsers(dest="command", required=True)

    p_stream = sub.add_parser("stream", help="Stream an audio file")
    p_stream.add_argument("audio_file", help="Path to audio file (wav/mp3/flac)")

    sub.add_parser("interrupt", help="Interrupt current playback")

    args = parser.parse_args()

    if args.command == "stream":
        if not Path(args.audio_file).exists():
            logger.error(f"File not found: {args.audio_file}")
            return
        asyncio.run(stream_audio(args.ws_url, args.audio_file))
    elif args.command == "interrupt":
        asyncio.run(send_interrupt(args.ws_url))


if __name__ == "__main__":
    main()
