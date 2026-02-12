"""Minimal bitHuman cloud agent — avatar + AI voice in ~40 lines.

Usage:
    python quickstart.py dev
"""

import os

from dotenv import load_dotenv
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice import AgentSession
from livekit.plugins import bithuman, openai

load_dotenv()


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    # Initialize the bitHuman avatar (cloud-hosted, no GPU needed)
    avatar = bithuman.AvatarSession(
        model_path=os.getenv("BITHUMAN_MODEL_PATH", "bithuman/essence"),
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        avatar_id=os.getenv("BITHUMAN_AVATAR_ID"),
    )

    # Create AI agent with OpenAI Realtime voice
    session = AgentSession(
        llm=openai.realtime.RealtimeModel(voice="ash"),
        allow_interruptions=True,
    )

    # Connect avatar to the session and room
    await avatar.start(session, room=ctx.room)
    await session.start(
        agent=session.current_agent,
        room=ctx.room,
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, job_memory_warn_mb=1500))
