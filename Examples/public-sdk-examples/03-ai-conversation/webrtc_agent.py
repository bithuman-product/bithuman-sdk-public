"""AI voice agent with a bitHuman avatar — streams to a LiveKit room via WebRTC.

Same conversational AI as local_agent.py, but viewers connect through a LiveKit room
instead of a local window. Supports multiple simultaneous viewers.

Usage:
    python webrtc_agent.py dev
"""

import logging
import os
from collections.abc import AsyncGenerator, AsyncIterator

import cv2
import numpy as np
from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import JobContext, WorkerOptions, cli, utils
from livekit.agents.voice import Agent, AgentSession
from livekit.agents.voice.avatar import (
    AudioSegmentEnd,
    AvatarOptions,
    AvatarRunner,
    QueueAudioOutput,
    VideoGenerator,
)
from livekit.agents.voice.room_io import RoomOutputOptions
from livekit.plugins import openai

from bithuman import AsyncBithuman

load_dotenv()
logger = logging.getLogger("bithuman-webrtc")
logger.setLevel(logging.INFO)
logging.getLogger("numba").setLevel(logging.WARNING)


class BithumanVideoGenerator(VideoGenerator):
    """Bridges bitHuman frames into LiveKit's VideoGenerator interface."""

    def __init__(self, runtime: AsyncBithuman):
        self._runtime = runtime

    @property
    def video_resolution(self) -> tuple[int, int]:
        frame = self._runtime.get_first_frame()
        if frame is None:
            raise ValueError("Failed to load avatar model")
        return frame.shape[1], frame.shape[0]

    @property
    def video_fps(self) -> int:
        return self._runtime.settings.FPS

    @property
    def audio_sample_rate(self) -> int:
        return self._runtime.settings.INPUT_SAMPLE_RATE

    @utils.log_exceptions(logger=logger)
    async def push_audio(self, frame: rtc.AudioFrame | AudioSegmentEnd) -> None:
        if isinstance(frame, AudioSegmentEnd):
            await self._runtime.flush()
        else:
            await self._runtime.push_audio(bytes(frame.data), frame.sample_rate, last_chunk=False)

    def clear_buffer(self) -> None:
        self._runtime.interrupt()

    def __aiter__(self) -> AsyncIterator[rtc.VideoFrame | rtc.AudioFrame | AudioSegmentEnd]:
        return self._stream()

    async def _stream(self) -> AsyncGenerator[rtc.VideoFrame | rtc.AudioFrame | AudioSegmentEnd, None]:
        async for frame in self._runtime.run():
            if frame.bgr_image is not None:
                rgba = cv2.cvtColor(frame.bgr_image, cv2.COLOR_BGR2RGBA)
                yield rtc.VideoFrame(
                    width=rgba.shape[1], height=rgba.shape[0],
                    type=rtc.VideoBufferType.RGBA, data=rgba.tobytes(),
                )

            if frame.audio_chunk is not None:
                yield rtc.AudioFrame(
                    data=frame.audio_chunk.bytes,
                    sample_rate=frame.audio_chunk.sample_rate,
                    num_channels=1,
                    samples_per_channel=len(frame.audio_chunk.array),
                )

            if frame.end_of_speech:
                yield AudioSegmentEnd()

    async def stop(self) -> None:
        await self._runtime.stop()


async def entrypoint(ctx: JobContext):
    await ctx.connect()

    model = os.getenv("BITHUMAN_AVATAR_MODEL")
    secret = os.getenv("BITHUMAN_API_SECRET")
    if not model or not secret:
        raise ValueError("Set BITHUMAN_AVATAR_MODEL and BITHUMAN_API_SECRET")

    runtime = await AsyncBithuman.create(model_path=model, api_secret=secret)
    video_gen = BithumanVideoGenerator(runtime)

    width, height = video_gen.video_resolution
    options = AvatarOptions(
        video_width=width, video_height=height,
        video_fps=video_gen.video_fps,
        audio_sample_rate=video_gen.audio_sample_rate,
        audio_channels=1,
    )

    session = AgentSession()
    session.output.audio = QueueAudioOutput()

    runner = AvatarRunner(
        room=ctx.room, video_gen=video_gen,
        audio_recv=session.output.audio, options=options,
    )
    await runner.start()

    await session.start(
        agent=Agent(
            instructions="You are a friendly AI assistant. Keep responses concise.",
            llm=openai.realtime.RealtimeModel(voice="alloy"),
        ),
        room=ctx.room,
        room_output_options=RoomOutputOptions(
            audio_enabled=False, audio_sample_rate=video_gen.audio_sample_rate,
        ),
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, job_memory_warn_mb=1500))
