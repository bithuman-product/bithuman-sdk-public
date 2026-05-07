"""bitHuman Expression avatar agent -- self-hosted GPU rendering.

Connects to a local expression-avatar container for GPU-powered avatar rendering.

Usage:
    python agent.py dev        # local dev with LiveKit playground
    python agent.py start      # production worker
"""

import logging
import os

from dotenv import load_dotenv
from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    RoomOutputOptions,
    WorkerOptions,
    WorkerType,
    cli,
)
from livekit.plugins import bithuman, openai, silero

logger = logging.getLogger("bithuman-agent")
logger.setLevel(logging.INFO)

load_dotenv()


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    gpu_url = os.getenv("CUSTOM_GPU_URL", "http://expression-avatar:8089/launch")
    avatar_image = os.getenv("BITHUMAN_AVATAR_IMAGE", "").strip()

    if not avatar_image:
        raise ValueError("Set BITHUMAN_AVATAR_IMAGE (face photo URL or path) in .env")

    logger.info(f"Self-hosted GPU -- avatar_image: {avatar_image}, endpoint: {gpu_url}")

    kwargs: dict = {
        "api_secret": os.getenv("BITHUMAN_API_SECRET"),
        "api_url": gpu_url,
        "api_token": os.getenv("CUSTOM_GPU_TOKEN") or None,
        "avatar_image": avatar_image,
    }

    avatar = bithuman.AvatarSession(**kwargs)

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(
            voice=os.getenv("OPENAI_VOICE", "coral"),
            model="gpt-4o-mini-realtime-preview",
        ),
        vad=silero.VAD.load(),
    )

    await avatar.start(session, room=ctx.room)

    await session.start(
        agent=Agent(
            instructions=os.getenv("AGENT_PROMPT", "You are a helpful assistant. Respond concisely.")
        ),
        room=ctx.room,
        room_output_options=RoomOutputOptions(audio_enabled=False),
    )


if __name__ == "__main__":
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            worker_type=WorkerType.ROOM,
            job_memory_warn_mb=3000,
            num_idle_processes=1,
            initialize_process_timeout=240,
        )
    )
