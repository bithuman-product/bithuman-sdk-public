"""bitHuman cloud agent with dynamic gesture triggering via keywords.

Detects keywords in speech transcriptions and triggers avatar gestures
(e.g., saying "hello" triggers a wave, "haha" triggers a laugh).

Usage:
    python gestures.py dev
"""

import asyncio
import json
import os

from dotenv import load_dotenv
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice import AgentSession
from livekit.plugins import bithuman, openai
from loguru import logger

load_dotenv()

# Map keywords in speech to gesture actions
KEYWORD_MAP = {
    "hello": "mini_wave_hello",
    "hi": "mini_wave_hello",
    "haha": "laugh_react",
    "funny": "laugh_react",
    "nod": "yes_nod",
    "agree": "yes_nod",
    "no": "no_shake",
    "disagree": "no_shake",
}


def detect_gesture(text: str) -> str | None:
    """Check if any keyword appears in the text."""
    text_lower = text.lower()
    for keyword, action in KEYWORD_MAP.items():
        if keyword in text_lower:
            return action
    return None


async def trigger_gesture(room, action: str):
    """Send a gesture command to all participants via RPC."""
    payload = json.dumps({"dynamics_payload": {"gesture_name": action}})
    tasks = []
    for participant in room.remote_participants.values():
        tasks.append(
            room.local_participant.perform_rpc(
                destination_identity=participant.identity,
                method="bithuman.dynamics",
                payload=payload,
            )
        )
    if tasks:
        await asyncio.gather(*tasks, return_exceptions=True)
        logger.info(f"Triggered gesture: {action}")


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    avatar = bithuman.AvatarSession(
        model_path=os.getenv("BITHUMAN_MODEL_PATH", "bithuman/essence"),
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
        avatar_id=os.getenv("BITHUMAN_AVATAR_ID"),
    )

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(voice="ash"),
        allow_interruptions=True,
    )

    # Trigger gestures when keywords appear in agent speech
    @session.on("agent_speech_transcribed")
    def on_agent_speech(ev):
        action = detect_gesture(ev.transcript)
        if action:
            asyncio.create_task(trigger_gesture(ctx.room, action))

    # Also trigger gestures from user speech
    @session.on("user_input_transcribed")
    def on_user_speech(ev):
        if ev.is_final:
            action = detect_gesture(ev.transcript)
            if action:
                asyncio.create_task(trigger_gesture(ctx.room, action))

    await avatar.start(session, room=ctx.room)
    await session.start(agent=session.current_agent, room=ctx.room)


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, job_memory_warn_mb=1500))
