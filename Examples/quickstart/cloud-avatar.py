"""Cloud avatar agent -- connect a bitHuman avatar to LiveKit with OpenAI voice.

Setup:
    export BITHUMAN_API_SECRET=your_secret
    export BITHUMAN_AGENT_ID=your_agent_code     # from www.bithuman.ai
    export LIVEKIT_URL=wss://your-livekit-server
    export LIVEKIT_API_KEY=...
    export LIVEKIT_API_SECRET=...
    export OPENAI_API_KEY=...

    pip install -r requirements.txt
    python cloud-avatar.py dev
"""

import os

from livekit.agents import Agent, AgentSession, JobContext, RoomOutputOptions, WorkerOptions, WorkerType, cli
from livekit.plugins import bithuman, openai, silero


async def entrypoint(ctx: JobContext):
    await ctx.connect()
    await ctx.wait_for_participant()

    # Create a cloud-hosted avatar session -- no local model needed
    avatar = bithuman.AvatarSession(
        avatar_id=os.environ["BITHUMAN_AGENT_ID"],
        api_secret=os.getenv("BITHUMAN_API_SECRET"),
    )

    session = AgentSession(
        llm=openai.realtime.RealtimeModel(voice="coral", model="gpt-4o-mini-realtime-preview"),
        vad=silero.VAD.load(),
    )

    await avatar.start(session, room=ctx.room)
    await session.start(
        agent=Agent(instructions="You are a helpful assistant. Keep answers short."),
        room=ctx.room,
        room_output_options=RoomOutputOptions(audio_enabled=False),
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, worker_type=WorkerType.ROOM))
