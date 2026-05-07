"""bitHuman Expression avatar agent -- cloud-hosted GPU (no local GPU needed).

Provide a face image and the cloud renders a GPU-powered talking avatar.

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

    avatar_image = os.getenv("BITHUMAN_AVATAR_IMAGE", "").strip()
    avatar_id = os.getenv("BITHUMAN_AGENT_ID", "").strip()

    if not avatar_image and not avatar_id:
        raise ValueError(
            "Set BITHUMAN_AVATAR_IMAGE (face photo URL/path) or BITHUMAN_AGENT_ID in .env"
        )

    kwargs: dict = {
        "api_secret": os.getenv("BITHUMAN_API_SECRET"),
        "model": "expression",
    }

    if avatar_image:
        kwargs["avatar_image"] = avatar_image
        logger.info(f"Cloud Expression mode -- avatar_image: {avatar_image}")
    else:
        kwargs["avatar_id"] = avatar_id
        logger.info(f"Cloud Expression mode -- avatar_id: {avatar_id}")

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
