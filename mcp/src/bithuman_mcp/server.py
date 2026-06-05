"""bitHuman MCP server.

A thin, well-documented Model Context Protocol wrapper over the bitHuman cloud
REST API (https://api.bithuman.ai). Every tool maps to one documented endpoint
(see https://docs.bithuman.ai/api/overview and the OpenAPI spec at
https://docs.bithuman.ai/api/openapi.yaml).

Auth: set BITHUMAN_API_SECRET in the environment (get one at
https://www.bithuman.ai/#developer). The server never logs or echoes it.

Transport: stdio by default (works with Claude Desktop / Claude Code / Cursor).
Set BITHUMAN_MCP_TRANSPORT=streamable-http to serve over HTTP instead.
"""

from __future__ import annotations

import base64
import os
import sys
from pathlib import Path
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

API_BASE = os.environ.get("BITHUMAN_API_BASE", "https://api.bithuman.ai").rstrip("/")
API_SECRET = os.environ.get("BITHUMAN_API_SECRET", "")
TIMEOUT = float(os.environ.get("BITHUMAN_MCP_TIMEOUT", "120"))
# Public status feed (https://status.bithuman.ai) — no auth, no credits.
STATUS_URL = os.environ.get("BITHUMAN_STATUS_URL", "https://status.bithuman.ai/status.json")

mcp = FastMCP(
    "bitHuman",
    instructions=(
        "Tools for the bitHuman real-time AI avatar platform. Use them to "
        "synthesize speech, generate and manage avatar agents, drive live "
        "sessions (speak / inject context / gestures), mint website embed "
        "tokens, upload assets, and check credit balance. Avatars are keyed by "
        "a short agent code like 'A91XMB7113'. Agent generation and dynamics "
        "are async — poll the matching status tool until status is 'ready'. "
        "Speech synthesis and agent generation consume credits; check the "
        "balance first with get_credit_balance if cost matters."
    ),
)


def _client() -> httpx.AsyncClient:
    """A configured async HTTP client with the api-secret header attached."""
    if not API_SECRET:
        raise RuntimeError(
            "BITHUMAN_API_SECRET is not set. Get one at "
            "https://www.bithuman.ai/#developer and export it before starting "
            "the MCP server."
        )
    return httpx.AsyncClient(
        base_url=API_BASE,
        headers={"api-secret": API_SECRET},
        timeout=TIMEOUT,
    )


def _json_or_text(resp: httpx.Response) -> Any:
    """Return parsed JSON, or a structured error dict on non-2xx / non-JSON."""
    try:
        body: Any = resp.json()
    except ValueError:
        body = resp.text
    if resp.status_code >= 400:
        return {
            "error": True,
            "status_code": resp.status_code,
            "body": body,
            "hint": "See https://docs.bithuman.ai/api/errors for the error catalog.",
        }
    return body


# ──────────────────────────────────────────────────────────────────────────
# Authentication & account
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def get_platform_status() -> dict:
    """Get the live operational status of the bitHuman platform and its public APIs.

    PUBLIC — no API secret required and no credits consumed (reads the same feed as
    https://status.bithuman.ai). Returns the overall status ("operational" |
    "degraded" | "down"), a human-readable summary, the operational/total service
    count, and a per-service `groups` breakdown — avatar rendering, voice/TTS, agent
    generation, and each public API endpoint — each with its own status + recent
    uptime. Call this to tell a platform-wide incident apart from a problem with your
    own request before retrying or escalating.
    """
    async with httpx.AsyncClient(timeout=15.0) as c:
        return _json_or_text(await c.get(STATUS_URL))


@mcp.tool()
async def validate_api_secret() -> dict:
    """Verify the configured bitHuman API secret is valid and the account active.

    Cheapest possible check — does not consume credits. Returns {"valid": bool}.
    Always call this first if you are unsure the credentials work.
    """
    async with _client() as c:
        return _json_or_text(await c.post("/v1/validate"))


@mcp.tool()
async def get_credit_balance(user_id: str | None = None, app: str = "imaginex") -> dict:
    """Check the account's current credit balance, plan, and estimated minutes.

    Args:
        user_id: Optional account UUID. Omit to use the API secret's own account.
        app: App identifier for multi-app subscriptions (default "imaginex").

    Returns balance, plan_credits, topup_credits, and a per-mode minutes_estimate.
    Agent generation costs ~250 credits; speech and live minutes are metered.
    """
    params: dict[str, str] = {"app": app}
    if user_id:
        params["user_id"] = user_id
    async with _client() as c:
        return _json_or_text(await c.get("/v2/credit-summaries", params=params))


# ──────────────────────────────────────────────────────────────────────────
# Voice / text-to-speech
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def list_voices() -> dict:
    """List the built-in and custom TTS voices available to this account.

    Built-in voices are M1–M5 (male) and F1–F5 (female). Use an id with
    text_to_speech. Designed voices from the Voice Designer
    (https://www.bithuman.ai/voice) are passed as a voice_code instead.
    """
    async with _client() as c:
        return _json_or_text(await c.get("/v1/voices"))


@mcp.tool()
async def text_to_speech(
    text: str,
    output_path: str,
    voice: str = "M1",
    voice_code: str | None = None,
    language: str = "en",
    speed: float = 1.05,
    total_steps: int = 8,
) -> dict:
    """Synthesize speech from text and save it as a WAV file. Consumes credits.

    Args:
        text: Text to speak (any length; multi-sentence supported).
        output_path: Absolute path to write the resulting .wav file to.
        voice: Built-in voice id (M1–M5, F1–F5). Ignored if voice_code is set.
        voice_code: A designed-voice handle from the Voice Designer (UUID or
            bv1_… code). Takes precedence over `voice`.
        language: ISO-2 language code (31 languages supported).
        speed: Playback rate, 0.7–2.0.
        total_steps: Denoise steps — 5 fast, 8 balanced, 12 highest quality.

    Returns the written file path and byte size. Read the WAV from output_path
    to play or attach it.
    """
    payload: dict[str, Any] = {
        "text": text,
        "voice": voice,
        "language": language,
        "speed": speed,
        "total_steps": total_steps,
        "format": "wav",
    }
    if voice_code:
        payload["voice_code"] = voice_code
    async with _client() as c:
        resp = await c.post("/v1/tts", json=payload)
        if resp.status_code >= 400:
            return _json_or_text(resp)
        out = Path(output_path).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(resp.content)
        return {"path": str(out), "bytes": len(resp.content), "format": "wav"}


# ──────────────────────────────────────────────────────────────────────────
# Agent generation & management
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def generate_agent(
    prompt: str | None = None,
    image: str | None = None,
    video: str | None = None,
    audio: str | None = None,
    aspect_ratio: str = "16:9",
) -> dict:
    """Create a new avatar agent. Async (2–5 min) and costs ~250 credits.

    Args:
        prompt: Personality / system prompt. A random default is used if omitted.
        image: URL to a face image for appearance.
        video: URL to a video for appearance and mannerisms.
        audio: URL to audio for voice cloning.
        aspect_ratio: "16:9", "9:16", or "1:1".

    Returns an agent_id and status "processing". Poll get_agent_status(agent_id)
    until status is "ready", then the agent is usable for embedding / live calls.
    """
    payload: dict[str, Any] = {"aspect_ratio": aspect_ratio}
    for k, v in (("prompt", prompt), ("image", image), ("video", video), ("audio", audio)):
        if v:
            payload[k] = v
    async with _client() as c:
        return _json_or_text(await c.post("/v1/agent/generate", json=payload))


@mcp.tool()
async def get_agent_status(agent_id: str) -> dict:
    """Poll the generation status of an agent created with generate_agent.

    Returns the current status (processing / ready / failed) and progress.
    """
    async with _client() as c:
        return _json_or_text(await c.get(f"/v1/agent/status/{agent_id}"))


@mcp.tool()
async def get_agent(code: str) -> dict:
    """Retrieve full details for an existing agent by its code (e.g. 'A91XMB7113')."""
    async with _client() as c:
        return _json_or_text(await c.get(f"/v1/agent/{code}"))


@mcp.tool()
async def update_agent_prompt(code: str, system_prompt: str) -> dict:
    """Update an existing agent's system prompt / personality.

    The agent must already exist (create one with generate_agent first).
    """
    async with _client() as c:
        return _json_or_text(
            await c.post(f"/v1/agent/{code}", json={"system_prompt": system_prompt})
        )


# ──────────────────────────────────────────────────────────────────────────
# Live-session control
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def agent_speak(code: str, message: str, room_id: str | None = None) -> dict:
    """Make a live agent speak the given text aloud in its active sessions.

    The agent must already be in at least one active LiveKit room (e.g. a user
    has an open embed/session). Returns how many rooms received the message.

    Args:
        code: Agent code.
        message: Text for the avatar to speak.
        room_id: Optional — target one room; defaults to all active rooms.
    """
    payload: dict[str, Any] = {"message": message}
    if room_id:
        payload["room_id"] = room_id
    async with _client() as c:
        return _json_or_text(await c.post(f"/v1/agent/{code}/speak", json=payload))


@mcp.tool()
async def add_agent_context(code: str, context: str, room_id: str | None = None) -> dict:
    """Silently inject background knowledge into a live agent's context.

    The avatar won't say this aloud but will use it in future responses
    (e.g. "The customer just purchased a premium plan.").
    """
    payload: dict[str, Any] = {"context": context, "type": "add_context"}
    if room_id:
        payload["room_id"] = room_id
    async with _client() as c:
        return _json_or_text(await c.post(f"/v1/agent/{code}/add-context", json=payload))


# ──────────────────────────────────────────────────────────────────────────
# Dynamics (gesture animations)
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def get_dynamics(agent_id: str) -> dict:
    """List the gesture animations (wave, nod, laugh, idle…) available for an agent.

    Returns a status and a map of gesture name → video URL.
    """
    async with _client() as c:
        return _json_or_text(await c.get(f"/v1/dynamics/{agent_id}"))


@mcp.tool()
async def generate_dynamics(
    agent_id: str, image_url: str | None = None, duration: int = 5, model: str = "seedance"
) -> dict:
    """Generate gesture animations for an agent. Async — poll get_dynamics to track.

    Args:
        agent_id: Agent code.
        image_url: Source image; defaults to the agent's primary image if omitted.
        duration: Gesture length in seconds.
        model: "seedance" (default), "quality", "speed", or "auto".
    """
    payload: dict[str, Any] = {"agent_id": agent_id, "duration": duration, "model": model}
    if image_url:
        payload["image_url"] = image_url
    async with _client() as c:
        return _json_or_text(await c.post("/v1/dynamics/generate", json=payload))


# ──────────────────────────────────────────────────────────────────────────
# Embedding & files
# ──────────────────────────────────────────────────────────────────────────

@mcp.tool()
async def create_embed_token(agent_id: str, fingerprint: str) -> dict:
    """Mint a short-lived (1 h) JWT to embed an agent on a website via iframe.

    Call this from a backend — never expose the API secret to a browser. The
    returned data.token goes in the embed widget's `data-token` attribute.

    Args:
        agent_id: Agent code to embed.
        fingerprint: Stable per-device hex string for session tracking / rate
            limiting (e.g. a hashed device id).
    """
    async with _client() as c:
        return _json_or_text(
            await c.post(
                "/v1/embed-tokens/request",
                json={"agent_id": agent_id, "fingerprint": fingerprint},
            )
        )


@mcp.tool()
async def upload_file(
    file_url: str | None = None,
    file_path: str | None = None,
    file_type: str = "auto",
) -> dict:
    """Upload an image/video/audio/document and get back a public CDN URL.

    Provide exactly one of file_url (download by URL) or file_path (a local file,
    uploaded as base64). The returned data.file_url can be passed to
    generate_agent's image/video/audio arguments.

    Args:
        file_url: Public URL to fetch the file from.
        file_path: Absolute path to a local file to upload.
        file_type: "auto" (default), "image", "video", "audio", or "document".
    """
    if bool(file_url) == bool(file_path):
        return {"error": True, "message": "Provide exactly one of file_url or file_path."}
    if file_url:
        payload: dict[str, Any] = {"file_url": file_url, "file_type": file_type}
    else:
        p = Path(file_path).expanduser()  # type: ignore[arg-type]
        if not p.is_file():
            return {"error": True, "message": f"No such file: {p}"}
        payload = {
            "file_data": base64.b64encode(p.read_bytes()).decode("ascii"),
            "file_name": p.name,
            "file_type": file_type,
        }
    async with _client() as c:
        return _json_or_text(await c.post("/v1/files/upload", json=payload))


@mcp.tool()
async def list_agents(limit: int = 20, offset: int = 0, status: str | None = None) -> dict:
    """List the avatar agents owned by this account, newest first (paginated).

    Args:
        limit: Page size (1–100).
        offset: Number of agents to skip.
        status: Optional generation-state filter (e.g. ready, processing, failed).

    Returns {data: [...], pagination: {limit, offset, total, has_more}}.
    """
    params: dict[str, Any] = {"limit": limit, "offset": offset}
    if status:
        params["status"] = status
    async with _client() as c:
        return _json_or_text(await c.get("/v1/agents", params=params))


@mcp.tool()
async def delete_agent(code: str) -> dict:
    """Permanently delete an agent you own (by code). Usage history is retained."""
    async with _client() as c:
        return _json_or_text(await c.delete(f"/v1/agent/{code}"))


@mcp.tool()
async def get_usage(
    limit: int = 50,
    offset: int = 0,
    start: str | None = None,
    end: str | None = None,
    agent_code: str | None = None,
) -> dict:
    """Return this account's usage/metering history, newest first (paginated).

    Args:
        limit: Page size (1–200).
        offset: Rows to skip.
        start: ISO-8601 timestamp — only events at/after this time.
        end: ISO-8601 timestamp — only events at/before this time.
        agent_code: Only events for this agent.

    Each row has activity_type, pricing_code, agent_code, credits_change
    (signed; usage is positive credits consumed), and created_at.
    """
    params: dict[str, Any] = {"limit": limit, "offset": offset}
    for k, v in (("start", start), ("end", end), ("agent_code", agent_code)):
        if v:
            params[k] = v
    async with _client() as c:
        return _json_or_text(await c.get("/v1/usage", params=params))


@mcp.tool()
async def create_webhook(
    url: str, events: list[str] | None = None, description: str | None = None
) -> dict:
    """Register a webhook to receive signed event notifications.

    Args:
        url: HTTPS endpoint to deliver events to.
        events: Event types to subscribe to (agent.ready, agent.failed). Omit
            for all.
        description: Optional label.

    The response includes a one-time `secret` (store it — it signs the
    X-BitHuman-Signature header and is never returned again).
    """
    payload: dict[str, Any] = {"url": url, "events": events or []}
    if description:
        payload["description"] = description
    async with _client() as c:
        return _json_or_text(await c.post("/v1/webhooks", json=payload))


@mcp.tool()
async def list_webhooks() -> dict:
    """List this account's registered webhooks (signing secrets redacted)."""
    async with _client() as c:
        return _json_or_text(await c.get("/v1/webhooks"))


@mcp.tool()
async def delete_webhook(webhook_id: str) -> dict:
    """Delete a webhook by id."""
    async with _client() as c:
        return _json_or_text(await c.delete(f"/v1/webhooks/{webhook_id}"))


@mcp.tool()
async def test_webhook(webhook_id: str) -> dict:
    """Send a one-off `ping` event to a webhook to confirm it's reachable.

    Returns {delivered, status_code, attempts}.
    """
    async with _client() as c:
        return _json_or_text(await c.post(f"/v1/webhooks/{webhook_id}/test"))


def main() -> None:
    """Entry point. Serves over stdio (default) or streamable-http."""
    # Deprecation notice → stderr only (never stdout, which carries the
    # stdio JSON-RPC stream). This package is superseded by the built-in
    # `bithuman mcp` server in the bitHuman CLI.
    print(
        "bithuman-mcp is deprecated — the MCP server is now built into the "
        "bitHuman CLI. Install it (`brew install bithuman` or the universal "
        "installer) and run `bithuman mcp`. Same tools, one tool to install.",
        file=sys.stderr,
    )
    transport = os.environ.get("BITHUMAN_MCP_TRANSPORT", "stdio")
    mcp.run(transport=transport)  # type: ignore[arg-type]


if __name__ == "__main__":
    main()
