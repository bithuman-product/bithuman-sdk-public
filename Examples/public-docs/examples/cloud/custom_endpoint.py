"""Use a self-hosted GPU endpoint with bitHuman (instead of bitHuman Cloud).

Supports three endpoint configurations:
  - bitHuman Cloud:  https://api.bithuman.ai/v4/{project}/expression-avatar/launch
  - Self-hosted:     https://your-domain.com/launch
  - Local dev:       http://localhost:8089/launch

Usage:
    python custom_endpoint.py dev
"""

import os

from dotenv import load_dotenv
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice import AgentSession
from livekit.plugins import bithuman, openai
from PIL import Image

load_dotenv()


def load_avatar_image():
    """Load avatar from AVATAR_IMAGE env var (file path or URL)."""
    source = os.getenv("AVATAR_IMAGE")
    if not source:
        return None  # use avatar_id instead

    if source.startswith(("http://", "https://")):
        return source
    if os.path.exists(source):
        return Image.open(source)
    return None


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    api_url = os.getenv("BITHUMAN_API_URL")  # e.g. https://your-gpu-server.com/launch
    api_token = os.getenv("BITHUMAN_API_TOKEN")  # Bearer token for your endpoint

    if not api_url:
        raise ValueError(
            "Set BITHUMAN_API_URL to your GPU endpoint "
            "(e.g. https://your-domain.com/launch or http://localhost:8089/launch)"
        )

    avatar = bithuman.AvatarSession(
        model_path=os.getenv("BITHUMAN_MODEL_PATH", "bithuman/expression"),
        model="expression",
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        api_url=api_url,
        api_token=api_token,
        avatar_id=os.getenv("BITHUMAN_AVATAR_ID"),
        avatar_image=load_avatar_image(),
        init_timeout=240,
    )

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(voice="ash"),
        allow_interruptions=True,
    )

    await avatar.start(session, room=ctx.room)
    await session.start(agent=session.current_agent, room=ctx.room)


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, job_memory_warn_mb=3000))
