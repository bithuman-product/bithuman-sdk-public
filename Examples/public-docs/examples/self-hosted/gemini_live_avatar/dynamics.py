"""Dynamics/gesture handler for bitHuman avatar keyword-triggered gestures."""

import time
import logging
from typing import Optional

import requests
from bithuman import AsyncBithuman
from bithuman.api import VideoControl

logger = logging.getLogger(__name__)

# Default keyword -> gesture action mapping
DEFAULT_KEYWORDS: dict[str, str] = {
    "hello": "mini_wave_hello", "hi": "mini_wave_hello", "hey": "mini_wave_hello",
    "goodbye": "mini_wave_hello", "bye": "mini_wave_hello", "wave": "mini_wave_hello",
    "laugh": "laugh_react", "laughing": "laugh_react", "haha": "laugh_react",
    "funny": "laugh_react", "hilarious": "laugh_react", "lol": "laugh_react",
}

def fetch_gestures(agent_id: str, api_secret: str) -> dict[str, str]:
    """Fetch available gestures from bitHuman Dynamics API."""
    try:
        resp = requests.get(
            f"https://api.bithuman.ai/v1/dynamics/{agent_id}",
            headers={"api-secret": api_secret}, timeout=10,
        )
        data = resp.json()
        if resp.ok and data.get("success"):
            return data["data"].get("gestures", {})
    except Exception as e:
        logger.warning(f"Failed to fetch gestures: {e}")
    return {}

def _keywords_from_gestures(gestures: dict[str, str]) -> dict[str, str]:
    """Auto-generate keyword mappings from gesture names."""
    kw = {}
    for key in gestures:
        name = key.lower()
        if "wave" in name or "hello" in name:
            for w in ("hello", "hi", "hey", "goodbye", "bye", "wave"):
                kw[w] = key
        elif "laugh" in name:
            for w in ("laugh", "laughing", "haha", "funny", "hilarious", "lol"):
                kw[w] = key
    return kw


class DynamicsHandler:
    """Triggers avatar gestures based on keyword detection in transcripts."""

    def __init__(self, bithuman_runtime: AsyncBithuman,
                 agent_id: Optional[str] = None, api_secret: Optional[str] = None,
                 cooldown: float = 3.0):
        self.runtime = bithuman_runtime
        self.agent_id = agent_id
        self.api_secret = api_secret
        self.cooldown = cooldown
        self.keyword_map: dict[str, str] = DEFAULT_KEYWORDS.copy()
        self._last_trigger: dict[str, float] = {}

    async def initialize(self):
        """Load gestures from bitHuman API (if credentials provided) and build keyword map."""
        if self.agent_id and self.api_secret:
            gestures = fetch_gestures(self.agent_id, self.api_secret)
            if gestures:
                self.keyword_map.update(_keywords_from_gestures(gestures))
                logger.info(f"Loaded {len(gestures)} gestures from API")

    async def trigger_gesture(self, action: str) -> bool:
        """Trigger a gesture if not on cooldown."""
        now = time.time()
        if now - self._last_trigger.get(action, 0) < self.cooldown:
            return False
        try:
            await self.runtime.push(VideoControl(action=action))
            self._last_trigger[action] = now
            return True
        except Exception as e:
            logger.error(f"Gesture '{action}' failed: {e}")
            return False

    async def check_and_trigger(self, transcript: str) -> Optional[str]:
        """Scan transcript for keywords and trigger the matching gesture."""
        lower = transcript.lower()
        for keyword, action in self.keyword_map.items():
            if keyword in lower:
                if await self.trigger_gesture(action):
                    return action
        return None
