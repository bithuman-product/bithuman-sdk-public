"""bitHuman Avatar Agent -- 100% local on macOS (Apple STT/TTS + Ollama LLM).

See README.md for prerequisite setup (Apple voices, Ollama, bitHuman voice service).
"""

import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    WorkerOptions,
    WorkerType,
    cli,
)
from livekit.agents.voice.room_io import RoomOptions
from livekit.plugins import bithuman, openai, silero

logger = logging.getLogger("bithuman-agent")
logger.setLevel(logging.INFO)

load_dotenv()

IMX_MODEL_ROOT = os.getenv("IMX_MODEL_ROOT", "/imx-models")
APPLE_SPEECH_URL = os.getenv("APPLE_SPEECH_URL", "http://host.docker.internal:8000/v1")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434/v1")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    models = sorted(Path(IMX_MODEL_ROOT).glob("*.imx"))
    if not models:
        raise ValueError(f"No .imx models found in {IMX_MODEL_ROOT}")
    logger.info(f"using model {models[0]}")

    logger.info("starting bitHuman avatar")
    avatar = bithuman.AvatarSession(
        model_path=str(models[0]),
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        api_token=os.getenv("BITHUMAN_API_TOKEN") or None,
    )

    session = AgentSession(
        stt=openai.STT(base_url=APPLE_SPEECH_URL, language="en"),
        llm=openai.LLM.with_ollama(model=OLLAMA_MODEL, base_url=OLLAMA_URL),
        tts=openai.TTS(base_url=APPLE_SPEECH_URL, voice=""),
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
        room_options=RoomOptions(audio_output=False),
    )


if __name__ == "__main__":
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            worker_type=WorkerType.ROOM,
            job_memory_warn_mb=1500,
            num_idle_processes=1,
            initialize_process_timeout=120,
        )
    )
