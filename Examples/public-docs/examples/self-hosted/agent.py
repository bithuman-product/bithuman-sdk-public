"""
Self-hosted bitHuman agent using LiveKit Agents and the native AsyncBithuman runtime.
Streams avatar video/audio via the VideoGenerator interface, with OpenAI Realtime
for conversational AI and Silero VAD for voice activity detection.
"""

import asyncio
import logging
import os
from collections.abc import AsyncGenerator, AsyncIterator

import cv2
import numpy as np
from dotenv import load_dotenv

os.environ.setdefault("LIVEKIT_CONNECT_TIMEOUT", "60")
os.environ.setdefault("LIVEKIT_ROOM_CONNECT_TIMEOUT", "60")

from livekit import rtc
from livekit.agents import (
    Agent, AgentSession, JobContext, RoomOutputOptions,
    WorkerOptions, WorkerType, cli, utils,
)
from livekit.agents.voice.avatar import (
    AudioSegmentEnd, AvatarOptions, AvatarRunner, QueueAudioOutput, VideoGenerator,
)
from livekit.plugins import openai, silero
from bithuman import AsyncBithuman

load_dotenv()
logger = logging.getLogger("bithuman-agent")
logger.setLevel(logging.INFO)


class BithumanVideoGenerator(VideoGenerator):
    """Bridges AsyncBithuman output to LiveKit's VideoGenerator interface."""

    def __init__(self, runtime: AsyncBithuman):
        self._runtime = runtime
        self._first_frame: np.ndarray | None = None

    @property
    def video_resolution(self) -> tuple[int, int]:
        if self._first_frame is not None:
            return self._first_frame.shape[1], self._first_frame.shape[0]
        try:
            return self._runtime.get_frame_size()
        except Exception:
            return (512, 512)

    @property
    def video_fps(self) -> int:
        return getattr(self._runtime.settings, "FPS", 25)

    @property
    def audio_sample_rate(self) -> int:
        return getattr(self._runtime.settings, "INPUT_SAMPLE_RATE", 16000)

    @utils.log_exceptions(logger=logger)
    async def push_audio(self, frame: rtc.AudioFrame | AudioSegmentEnd) -> None:
        if isinstance(frame, AudioSegmentEnd):
            await self._runtime.flush()
            return
        await self._runtime.push_audio(bytes(frame.data), frame.sample_rate, last_chunk=False)

    def clear_buffer(self) -> None:
        self._runtime.interrupt()

    def __aiter__(self) -> AsyncIterator[rtc.VideoFrame | rtc.AudioFrame | AudioSegmentEnd]:
        return self._stream()

    async def _stream(self) -> AsyncGenerator[rtc.VideoFrame | rtc.AudioFrame | AudioSegmentEnd, None]:
        try:
            async for frame in self._runtime.run():
                if frame.bgr_image is not None:
                    if self._first_frame is None:
                        self._first_frame = frame.bgr_image.copy()
                        logger.info("First frame cached, resolution: %s", self.video_resolution)
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
        except asyncio.CancelledError:
            logger.info("Video generator streaming cancelled")
        except Exception:
            logger.exception("Error in video generator stream")

    async def stop(self) -> None:
        try:
            await self._runtime.stop()
        except Exception:
            logger.exception("Error stopping bitHuman runtime")


async def entrypoint(ctx: JobContext):
    """Initialize the bitHuman avatar, wire up LiveKit, and run forever."""
    await ctx.connect()
    await ctx.wait_for_participant()

    model_path = os.environ["BITHUMAN_MODEL_PATH"]
    api_secret = os.environ["BITHUMAN_API_SECRET"]
    api_token = os.getenv("BITHUMAN_API_TOKEN")

    create_kw = dict(model_path=model_path, api_secret=api_secret, insecure=True)
    if api_token:
        create_kw["token"] = api_token
    runtime = await AsyncBithuman.create(**create_kw)
    video_gen = BithumanVideoGenerator(runtime)

    w, h = video_gen.video_resolution
    logger.info("Video: %dx%d@%dfps, audio: %dHz", w, h, video_gen.video_fps, video_gen.audio_sample_rate)

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(
            voice="coral", model="gpt-4o-realtime-preview-2025-06-03", temperature=0.7,
        ),
        vad=silero.VAD.load(
            min_speech_duration=0.1, min_silence_duration=0.5, prefix_padding_duration=0.1,
        ),
    )
    session.output.audio = QueueAudioOutput()

    avatar = AvatarRunner(
        room=ctx.room, video_gen=video_gen, audio_recv=session.output.audio,
        options=AvatarOptions(
            video_width=w, video_height=h, video_fps=video_gen.video_fps,
            audio_sample_rate=video_gen.audio_sample_rate, audio_channels=1,
        ),
    )
    await avatar.start()

    await session.start(
        agent=Agent(instructions=(
            "You are a helpful and engaging AI assistant with a visual avatar. "
            "Respond naturally and conversationally. Keep responses concise but friendly."
        )),
        room=ctx.room,
        room_output_options=RoomOutputOptions(audio_enabled=False),
    )

    logger.info("Self-hosted bitHuman agent is running")
    try:
        await asyncio.Future()
    except asyncio.CancelledError:
        pass
    finally:
        await video_gen.stop()


if __name__ == "__main__":
    cli.run_app(WorkerOptions(
        entrypoint_fnc=entrypoint, worker_type=WorkerType.ROOM,
        job_memory_warn_mb=8000, job_memory_limit_mb=8000,
        num_idle_processes=1, initialize_process_timeout=180,
    ))
