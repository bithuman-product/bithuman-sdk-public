"""Use a custom avatar image (local file or URL) with bitHuman expression model.

Usage:
    python custom_avatar.py dev
"""

import os

from dotenv import load_dotenv
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice import AgentSession
from livekit.plugins import bithuman, openai
from PIL import Image

load_dotenv()


def load_avatar_image():
    """Load avatar from AVATAR_IMAGE env var (file path or URL), or fall back to local file."""
    source = os.getenv("AVATAR_IMAGE", "avatar.jpg")

    if source.startswith(("http://", "https://")):
        return source  # bitHuman accepts URLs directly

    if os.path.exists(source):
        return Image.open(source)

    raise FileNotFoundError(f"Avatar image not found: {source}")


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    avatar = bithuman.AvatarSession(
        model_path=os.getenv("BITHUMAN_MODEL_PATH", "bithuman/expression"),
        model="expression",
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        avatar_image=load_avatar_image(),
        init_timeout=180,
    )

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(voice="ash"),
        allow_interruptions=True,
    )

    await avatar.start(session, room=ctx.room)
    await session.start(agent=session.current_agent, room=ctx.room)


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, job_memory_warn_mb=2000))
