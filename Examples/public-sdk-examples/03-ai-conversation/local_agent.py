"""AI voice agent with a bitHuman avatar — runs locally with OpenAI Realtime.

Speak into your mic, hear the AI respond, and watch the avatar lip-sync in real time.
No LiveKit server needed — everything runs on your machine.

Usage:
    python local_agent.py
"""

import asyncio
import logging
import os
import signal
import sys

import numpy as np
from dotenv import load_dotenv
from livekit.agents import utils
from livekit.agents.voice import Agent, AgentSession
from livekit.agents.voice.avatar import AvatarOptions, QueueAudioOutput
from livekit.plugins import openai
from loguru import logger

from bithuman import AsyncBithuman
from bithuman.utils.agent import LocalAudioIO, LocalAvatarRunner, LocalVideoPlayer

load_dotenv()
logger.remove()
logger.add(sys.stdout, level="INFO")
logging.getLogger("numba").setLevel(logging.WARNING)


class VoiceAgent(Agent):
    def __init__(self):
        super().__init__(
            instructions="You are a friendly AI assistant. Keep responses concise.",
            llm=openai.realtime.RealtimeModel(voice="alloy"),
        )


async def main():
    utils.http_context._new_session_ctx()

    # Create bitHuman runtime
    model = os.getenv("BITHUMAN_AVATAR_MODEL")
    secret = os.getenv("BITHUMAN_API_SECRET")
    if not model or not secret:
        raise ValueError("Set BITHUMAN_AVATAR_MODEL and BITHUMAN_API_SECRET in your .env")

    runtime = await AsyncBithuman.create(model_path=model, api_secret=secret)

    first_frame = runtime.get_first_frame()
    if first_frame is None:
        raise ValueError("Failed to load avatar model — check your model path")

    height, width = first_frame.shape[:2]
    avatar_options = AvatarOptions(
        video_width=width, video_height=height,
        video_fps=25, audio_sample_rate=16000, audio_channels=1,
    )

    # Wire up: Agent audio → bitHuman → video display + speaker
    video_player = LocalVideoPlayer(window_size=(width, height), buffer_size=3)
    audio_buffer = QueueAudioOutput(sample_rate=16000)

    session = AgentSession()
    session.output.audio = audio_buffer

    local_audio = LocalAudioIO(session=session, agent_audio_output=audio_buffer, buffer_size=3)
    await local_audio.start()

    avatar_runner = LocalAvatarRunner(
        bithuman_runtime=runtime,
        audio_input=audio_buffer,
        audio_output=local_audio,
        video_output=video_player,
        options=avatar_options,
    )
    await avatar_runner.start()
    await session.start(agent=VoiceAgent())

    # Wait for Ctrl+C
    stop = asyncio.Event()
    asyncio.get_running_loop().add_signal_handler(signal.SIGINT, stop.set)
    await stop.wait()


if __name__ == "__main__":
    asyncio.run(main())
