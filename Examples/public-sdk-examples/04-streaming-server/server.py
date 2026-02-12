"""WebSocket server that streams a bitHuman avatar to a LiveKit room.

Clients send audio via WebSocket; the server animates the avatar and publishes
video + audio tracks to LiveKit for viewers to watch.

Usage:
    python server.py --room my-room --avatar-model avatar.imx
"""

import argparse
import asyncio
import json
import os
import signal
import sys

import cv2
import numpy as np
import websockets
from dotenv import load_dotenv
from livekit import api, rtc
from loguru import logger

from bithuman import AsyncBithuman
from bithuman.utils import FPSController

load_dotenv()
logger.remove()
logger.add(sys.stdout, level="INFO")

VIDEO_FPS = 25
AUDIO_SAMPLE_RATE = 16000


class AvatarStreamingServer:
    """Accepts audio via WebSocket, renders a bitHuman avatar, streams to LiveKit."""

    def __init__(self, runtime: AsyncBithuman, livekit_url: str,
                 lk_api_key: str, lk_api_secret: str, room: str, ws_port: int = 8765):
        self.runtime = runtime
        self.livekit_url = livekit_url
        self.lk_api_key = lk_api_key
        self.lk_api_secret = lk_api_secret
        self.room_name = room
        self.ws_port = ws_port

        self._room = rtc.Room()
        self._av_sync = None
        self._audio_queue: asyncio.Queue[bytes] = asyncio.Queue()
        self._running = False

    async def start(self):
        self._running = True
        await self.runtime.start()
        width, height = self.runtime.get_frame_size()

        # Connect to LiveKit
        token = (
            api.AccessToken(api_key=self.lk_api_key, api_secret=self.lk_api_secret)
            .with_identity("bithuman-avatar")
            .with_name("bitHuman Avatar")
            .with_grants(api.VideoGrants(room_join=True, room=self.room_name))
            .with_kind("agent")
            .to_jwt()
        )
        await self._room.connect(self.livekit_url, token)
        logger.info(f"Connected to LiveKit room: {self.room_name}")

        # Publish video + audio tracks
        video_source = rtc.VideoSource(width=width, height=height)
        audio_source = rtc.AudioSource(sample_rate=AUDIO_SAMPLE_RATE, num_channels=1)

        video_track = rtc.LocalVideoTrack.create_video_track("video", video_source)
        audio_track = rtc.LocalAudioTrack.create_audio_track("audio", audio_source)

        await self._room.local_participant.publish_track(
            video_track, rtc.TrackPublishOptions(
                source=rtc.TrackSource.SOURCE_CAMERA,
                video_encoding=rtc.VideoEncoding(max_framerate=VIDEO_FPS, max_bitrate=5_000_000),
            ))
        await self._room.local_participant.publish_track(
            audio_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE))

        self._av_sync = rtc.AVSynchronizer(
            audio_source=audio_source, video_source=video_source,
            video_fps=VIDEO_FPS, video_queue_size_ms=100,
        )

        # Start WebSocket server + audio processing
        ws_server = await websockets.serve(self._handle_ws, "0.0.0.0", self.ws_port)
        logger.info(f"WebSocket server on port {self.ws_port}")

        audio_task = asyncio.create_task(self._process_audio())
        try:
            await self._run_avatar()
        finally:
            audio_task.cancel()
            ws_server.close()
            if self._av_sync:
                await self._av_sync.aclose()
            await self._room.disconnect()
            await self.runtime.stop()

    async def _handle_ws(self, ws):
        """Handle a single WebSocket client."""
        logger.info("Client connected")
        try:
            async for msg in ws:
                if isinstance(msg, bytes):
                    await self._audio_queue.put(msg)
                elif isinstance(msg, str):
                    data = json.loads(msg)
                    if data.get("type") == "interrupt":
                        self.runtime.interrupt()
                    elif data.get("type") == "end":
                        await self.runtime.flush()
        except websockets.exceptions.ConnectionClosed:
            pass
        logger.info("Client disconnected")

    async def _process_audio(self):
        """Forward queued audio bytes to the bitHuman runtime."""
        while self._running:
            audio = await self._audio_queue.get()
            await self.runtime.push_audio(audio, AUDIO_SAMPLE_RATE, last_chunk=False)

    async def _run_avatar(self):
        """Main loop: consume bitHuman frames and push to LiveKit."""
        fps = FPSController(target_fps=VIDEO_FPS)

        async for frame in self.runtime.run():
            sleep_time = fps.wait_next_frame(sleep=False)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

            if frame.has_image:
                rgba = cv2.cvtColor(frame.bgr_image, cv2.COLOR_BGR2RGBA)
                await self._av_sync.push(rtc.VideoFrame(
                    width=rgba.shape[1], height=rgba.shape[0],
                    type=rtc.VideoBufferType.RGBA, data=rgba.tobytes(),
                ))

            if frame.audio_chunk:
                await self._av_sync.push(rtc.AudioFrame(
                    data=frame.audio_chunk.array.tobytes(),
                    sample_rate=AUDIO_SAMPLE_RATE, num_channels=1,
                    samples_per_channel=len(frame.audio_chunk.array),
                ))

            fps.update()


async def main():
    parser = argparse.ArgumentParser(description="bitHuman avatar streaming server")
    parser.add_argument("--avatar-model", default=os.getenv("BITHUMAN_AVATAR_MODEL"), required=True)
    parser.add_argument("--api-secret", default=os.getenv("BITHUMAN_API_SECRET"))
    parser.add_argument("--livekit-url", default=os.getenv("LIVEKIT_URL"), required=True)
    parser.add_argument("--livekit-api-key", default=os.getenv("LIVEKIT_API_KEY"), required=True)
    parser.add_argument("--livekit-api-secret", default=os.getenv("LIVEKIT_API_SECRET"), required=True)
    parser.add_argument("--room", required=True)
    parser.add_argument("--ws-port", type=int, default=8765)
    args = parser.parse_args()

    runtime = await AsyncBithuman.create(model_path=args.avatar_model, api_secret=args.api_secret)
    server = AvatarStreamingServer(
        runtime, args.livekit_url, args.livekit_api_key,
        args.livekit_api_secret, args.room, args.ws_port,
    )

    loop = asyncio.get_running_loop()
    stop = asyncio.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)

    server_task = asyncio.create_task(server.start())
    await stop.wait()
    server_task.cancel()


if __name__ == "__main__":
    asyncio.run(main())
