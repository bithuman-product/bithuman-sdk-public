"""Web-based bitHuman avatar with Gradio + FastRTC.

Opens a browser UI where you can talk to an AI agent through a bitHuman avatar.
Supports multiple avatar models and text input.

Usage:
    python app.py
"""

import asyncio
import logging
import os
from collections.abc import AsyncIterator
from pathlib import Path

import gradio as gr
import numpy as np
from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import utils
from livekit.agents.voice import Agent, AgentSession
from livekit.agents.voice.avatar import AudioSegmentEnd, QueueAudioOutput
from livekit.plugins import openai
from numpy.typing import NDArray

from bithuman import AsyncBithuman
from bithuman.utils import FPSController
from fastrtc import AsyncAudioVideoStreamHandler, AudioEmitType, Stream, VideoEmitType, wait_for_item

load_dotenv()
logger = logging.getLogger("bithuman-web")
logging.basicConfig(level=logging.INFO)

MODEL_ROOT = os.getenv("BITHUMAN_MODEL_ROOT")
if not MODEL_ROOT:
    raise ValueError("Set BITHUMAN_MODEL_ROOT to the directory containing .imx files")


class BitHumanHandler(AsyncAudioVideoStreamHandler):
    """Bridges FastRTC audio/video streams with a bitHuman avatar."""

    AVATARS = {
        name: str((Path(MODEL_ROOT) / f"{name}.imx").resolve())
        for name in ("einstein", "dog", "companion")
        if (Path(MODEL_ROOT) / f"{name}.imx").exists()
    }

    def __init__(self):
        super().__init__(
            input_sample_rate=24_000, output_sample_rate=16_000,
            output_frame_size=320, fps=100,
        )
        self.input_audio_queue: asyncio.Queue[rtc.AudioFrame] = asyncio.Queue()
        self.agent_audio_queue = QueueAudioOutput()
        self.agent_audio_queue._sample_rate = 16_000
        self.video_queue: asyncio.Queue[NDArray[np.uint8]] = asyncio.Queue()
        self.audio_queue: asyncio.Queue[tuple[int, NDArray[np.int16]]] = asyncio.Queue()
        self.runtime: AsyncBithuman | None = None
        self.runtime_ready = asyncio.Event()
        self.fps_controller = FPSController(target_fps=25)
        self.pushed_duration: float = 0

    @utils.log_exceptions(logger=logger)
    async def start_up(self):
        await self.wait_for_args()
        _, api_secret, avatar_name = self.latest_args[1:]

        utils.http_context._new_session_ctx()
        session = AgentSession()
        session.input.audio = self._make_audio_input()
        session.output.audio = self.agent_audio_queue
        await session.start(agent=Agent(
            instructions="You are a friendly assistant.",
            llm=openai.realtime.RealtimeModel(voice="alloy"),
        ))

        self.agent_audio_queue.on("clear_buffer", self._on_interrupt)

        self.runtime = await AsyncBithuman.create(
            api_secret=api_secret, model_path=self.AVATARS[avatar_name],
        )
        await self.runtime.start()
        self.runtime_ready.set()

        await asyncio.gather(self._generate_frames(), self._forward_agent_audio())

    def _make_audio_input(self) -> AsyncIterator[rtc.AudioFrame]:
        async def gen():
            while True:
                yield await self.input_audio_queue.get()
        return gen()

    async def _generate_frames(self):
        async for frame in self.runtime.run():
            if frame.audio_chunk:
                await self.audio_queue.put((frame.audio_chunk.sample_rate, frame.audio_chunk.data))
                self.pushed_duration += frame.audio_chunk.duration

            if frame.has_image:
                sleep = self.fps_controller.wait_next_frame(sleep=False)
                if sleep > 0:
                    await asyncio.sleep(sleep)
                await self.video_queue.put(frame.bgr_image)
                self.fps_controller.update()

            if frame.end_of_speech and self.pushed_duration > 0:
                self.agent_audio_queue.notify_playback_finished(self.pushed_duration, interrupted=False)
                self.pushed_duration = 0

    async def _forward_agent_audio(self):
        async for frame in self.agent_audio_queue:
            if isinstance(frame, AudioSegmentEnd):
                await self.runtime.flush()
            else:
                await self.runtime.push_audio(bytes(frame.data), frame.sample_rate, last_chunk=False)

    def _on_interrupt(self):
        self.runtime.interrupt()
        if self.pushed_duration > 0:
            self.agent_audio_queue.notify_playback_finished(self.pushed_duration, interrupted=True)
            self.pushed_duration = 0

    # FastRTC hooks
    async def video_emit(self) -> VideoEmitType:
        frame = await wait_for_item(self.video_queue)
        return frame if frame is not None else np.zeros((768, 1280, 3), dtype=np.uint8)

    async def video_receive(self, frame: NDArray[np.uint8]):
        pass

    async def emit(self) -> AudioEmitType:
        return await wait_for_item(self.audio_queue)

    async def receive(self, frame: tuple[int, NDArray[np.int16]]):
        await self.runtime_ready.wait()
        sr, array = frame
        if array.ndim == 2:
            array = array[0]
        if array.dtype == np.float32:
            array = (array * np.iinfo(np.int16).max).astype(np.int16)
        await self.input_audio_queue.put(
            rtc.AudioFrame(data=array.tobytes(), sample_rate=sr, num_channels=1, samples_per_channel=len(array))
        )

    async def shutdown(self):
        if self.runtime:
            await self.runtime.flush()
            await self.runtime.stop()

    def copy(self) -> "BitHumanHandler":
        return BitHumanHandler()


stream = Stream(
    handler=BitHumanHandler(),
    mode="send-receive",
    modality="audio-video",
    additional_inputs=[
        gr.Textbox(label="Message", info="Type what you want the avatar to say"),
        gr.Textbox(label="API Key", type="password", value=os.getenv("BITHUMAN_API_SECRET")),
        gr.Dropdown(choices=list(BitHumanHandler.AVATARS.keys()), value="companion", label="Avatar"),
    ],
    ui_args={"title": "bitHuman Avatar"},
)

if __name__ == "__main__":
    stream.ui.launch()
