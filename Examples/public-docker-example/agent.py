"""bitHuman Avatar Agent -- supports both CPU (essence) and GPU (expression) modes.

Set AVATAR_MODE=gpu and CUSTOM_GPU_URL to use a GPU expression-avatar endpoint.
Otherwise the agent runs in CPU mode using local .imx model files.
"""

import logging
import os
from pathlib import Path

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

AVATAR_MODE = os.getenv("AVATAR_MODE", "cpu").lower()  # "cpu" or "gpu"


def _build_avatar_session() -> bithuman.AvatarSession:
    """Build the bitHuman AvatarSession for the configured mode."""
    if AVATAR_MODE == "gpu":
        custom_url = os.getenv("CUSTOM_GPU_URL")
        if not custom_url:
            raise ValueError("CUSTOM_GPU_URL is required when AVATAR_MODE=gpu")
        logger.info(f"GPU mode -- endpoint: {custom_url}")
        return bithuman.AvatarSession(
            api_secret=os.getenv("BITHUMAN_API_SECRET"),
            api_url=custom_url,
            api_token=os.getenv("CUSTOM_GPU_TOKEN"),
            avatar_image=os.getenv("BITHUMAN_AVATAR_IMAGE"),
        )

    # CPU (essence) mode -- pick first .imx model
    model_root = os.getenv("IMX_MODEL_ROOT", "/persistent-storage/imx-models")
    models = sorted(Path(model_root).glob("*.imx"))
    if not models:
        raise ValueError(f"No .imx models found in {model_root}")
    logger.info(f"CPU mode -- model: {models[0]}")
    return bithuman.AvatarSession(
        model_path=str(models[0]),
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        api_token=os.getenv("BITHUMAN_API_TOKEN"),
    )


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    logger.info("starting bitHuman avatar")
    avatar = _build_avatar_session()

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
            instructions=(
                "You are a helpful assistant. Talk to me! "
                "Respond shortly and concisely."
            )
        ),
        room=ctx.room,
        room_output_options=RoomOutputOptions(audio_enabled=False),
    )


if __name__ == "__main__":
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            worker_type=WorkerType.ROOM,
            job_memory_warn_mb=3000 if AVATAR_MODE == "gpu" else 1500,
            num_idle_processes=1,
            initialize_process_timeout=240 if AVATAR_MODE == "gpu" else 120,
        )
    )
