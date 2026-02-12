"""
Self-hosted bitHuman agent with dynamic gesture triggering.
Extends the basic agent with keyword-based gesture activation from both voice
transcription and text input, using VideoControl to drive avatar dynamics.
Gestures can be auto-discovered from the bitHuman Dynamics API.
"""

import asyncio
import logging
import os
import time

import requests
from dotenv import load_dotenv
from livekit.agents import (
    Agent, AgentSession, JobContext, JobProcess, RoomInputOptions,
    RoomOutputOptions, UserInputTranscribedEvent, WorkerOptions, WorkerType, cli,
)
from livekit.agents.voice.room_io import TextInputEvent
from livekit.plugins import bithuman, openai, silero
from bithuman import AsyncBithuman
from bithuman.api import VideoControl

load_dotenv()
logger = logging.getLogger("bithuman-dynamics-agent")
logger.setLevel(logging.INFO)

# Default keyword -> gesture action mapping (overridden by Dynamics API when available)
DEFAULT_KEYWORD_ACTION_MAP: dict[str, str] = {
    "laugh": "laugh_react", "laughing": "laugh_react", "haha": "laugh_react", "funny": "laugh_react",
    "hello": "mini_wave_hello", "hi": "mini_wave_hello", "hey": "mini_wave_hello",
    "goodbye": "mini_wave_hello", "bye": "mini_wave_hello",
}

# Pattern names to keywords -- used to auto-build mappings from Dynamics API gestures
_GESTURE_PATTERNS: dict[str, list[str]] = {
    "wave": ["hello", "hi", "hey", "goodbye", "bye"],
    "hello": ["hello", "hi", "hey", "goodbye", "bye"],
    "laugh": ["laugh", "laughing", "haha", "funny"],
    "nod": ["yes", "nod", "agree"],
    "kiss": ["kiss", "love"],
    "heart": ["kiss", "love"],
}


def get_available_gestures(agent_id: str, api_secret: str) -> dict[str, str]:
    """Fetch available gestures from the bitHuman Dynamics API. Returns {} on failure."""
    try:
        resp = requests.get(
            f"https://api.bithuman.ai/v1/dynamics/{agent_id}",
            headers={"api-secret": api_secret}, timeout=10,
        )
        data = resp.json()
        if resp.ok and data.get("success"):
            gestures = data["data"].get("gestures", {})
            logger.info("Retrieved %d gestures from Dynamics API", len(gestures))
            return gestures
    except Exception as e:
        logger.warning("Failed to fetch gestures: %s", e)
    return {}


def build_keyword_map(gestures: dict[str, str]) -> dict[str, str]:
    """Derive keyword -> action mappings from gesture names."""
    kw_map: dict[str, str] = {}
    for gesture_key in gestures:
        for pattern, keywords in _GESTURE_PATTERNS.items():
            if pattern in gesture_key.lower():
                kw_map.update({kw: gesture_key for kw in keywords})
    return kw_map


def create_input_handler(
    avatar: bithuman.AvatarSession,
    keyword_map: dict[str, str],
    cooldowns: dict[str, float],
    cooldown_seconds: float = 3.0,
):
    """
    Return handlers for voice and text input that detect keywords and trigger
    the corresponding gesture via VideoControl, with per-action cooldown.
    """

    async def _try_gesture(text: str, session: AgentSession | None = None, reply: bool = False) -> None:
        text_lower = text.strip().lower()
        if not text_lower:
            return
        for keyword, action in keyword_map.items():
            if keyword in text_lower:
                now = time.time()
                if now - cooldowns.get(action, 0) >= cooldown_seconds:
                    try:
                        await avatar.runtime.push(VideoControl(action=action))
                        cooldowns[action] = now
                        logger.info("Triggered gesture: %s (keyword: %s)", action, keyword)
                    except Exception as e:
                        logger.error("Failed to trigger gesture %s: %s", action, e)
                break
        if reply and session:
            session.interrupt()
            session.generate_reply(user_input=text.strip())

    async def on_voice(event: UserInputTranscribedEvent) -> None:
        if event.is_final:
            await _try_gesture(event.transcript)

    async def on_text(session: AgentSession, event: TextInputEvent) -> None:
        await _try_gesture(event.text, session=session, reply=True)

    on_voice.on_text = on_text  # type: ignore[attr-defined]
    return on_voice


def prewarm(proc: JobProcess):
    """Pre-load VAD and optionally the bitHuman runtime for faster cold starts."""
    proc.userdata["vad"] = silero.VAD.load(
        min_speech_duration=0.1, min_silence_duration=0.5, prefix_padding_duration=0.1,
    )
    model_path = os.getenv("BITHUMAN_MODEL_PATH")
    if model_path and "bithuman_runtime" not in proc.userdata:
        logger.info("Prewarming runtime: %s", model_path)
        proc.userdata["bithuman_runtime"] = AsyncBithuman(
            model_path=model_path, api_secret=os.getenv("BITHUMAN_API_SECRET"), load_model=True,
        )


async def entrypoint(ctx: JobContext):
    """Wire up the bitHuman avatar, gesture dynamics, and conversational AI."""
    await ctx.connect()
    await ctx.wait_for_participant()

    model_path = os.environ["BITHUMAN_MODEL_PATH"]
    api_secret = os.environ["BITHUMAN_API_SECRET"]
    agent_id = os.getenv("BITHUMAN_AGENT_ID")

    avatar_kw: dict = {"api_secret": api_secret, "model_path": model_path}
    runtime = ctx.proc.userdata.get("bithuman_runtime")
    if runtime:
        avatar_kw["runtime"] = runtime
    avatar = bithuman.AvatarSession(**avatar_kw)

    vad = ctx.proc.userdata.get("vad") or silero.VAD.load(
        min_speech_duration=0.1, min_silence_duration=0.5, prefix_padding_duration=0.1,
    )
    session = AgentSession(
        llm=openai.realtime.RealtimeModel(
            voice="coral", model="gpt-4o-realtime-preview-2025-06-03", temperature=0.7,
        ),
        vad=vad,
    )
    await avatar.start(session, room=ctx.room)

    # Resolve keyword -> gesture mapping (prefer API, fall back to defaults)
    keyword_map = DEFAULT_KEYWORD_ACTION_MAP.copy()
    if agent_id:
        gestures = get_available_gestures(agent_id, api_secret)
        if gestures:
            keyword_map = build_keyword_map(gestures)
            logger.info("Loaded %d gestures: %s", len(gestures), list(gestures.keys()))

    handler = create_input_handler(avatar, keyword_map, cooldowns={})

    @session.on("user_input_transcribed")
    def on_transcribed(event: UserInputTranscribedEvent):
        asyncio.create_task(handler(event))

    await session.start(
        agent=Agent(instructions=(
            "You are a helpful and engaging AI assistant with a visual avatar. "
            "Respond naturally and conversationally. Keep responses concise but friendly. "
            "You can express emotions through gestures, so feel free to be expressive."
        )),
        room=ctx.room,
        room_input_options=RoomInputOptions(text_enabled=True, text_input_cb=handler.on_text),
        room_output_options=RoomOutputOptions(audio_enabled=False),
    )
    logger.info("bitHuman dynamics agent is running")


if __name__ == "__main__":
    cli.run_app(WorkerOptions(
        entrypoint_fnc=entrypoint, worker_type=WorkerType.ROOM,
        job_memory_warn_mb=8000, job_memory_limit_mb=8000,
        num_idle_processes=1, initialize_process_timeout=180,
        prewarm_fnc=prewarm,
    ))
