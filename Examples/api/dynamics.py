"""bitHuman Platform API -- Dynamics (Gestures)

Generate motion dynamics for an agent and query available gestures.

Usage:
    export BITHUMAN_API_SECRET=your_secret
    python dynamics.py --agent-id A91XMB7113
    python dynamics.py --agent-id A91XMB7113 --generate
"""

import argparse
import os
import sys
import time

import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("BITHUMAN_API_URL", "https://api.bithuman.ai")


def get_headers():
    secret = os.getenv("BITHUMAN_API_SECRET")
    if not secret:
        print("Error: BITHUMAN_API_SECRET not set.")
        print("  Get yours at https://www.bithuman.ai/#developer")
        print("  Then: export BITHUMAN_API_SECRET='your_secret'")
        sys.exit(1)
    return {"Content-Type": "application/json", "api-secret": secret}


def get_dynamics(agent_id: str):
    """GET /v1/dynamics/{agent_id} -- get dynamics status and available gestures."""
    try:
        resp = requests.get(f"{BASE_URL}/v1/dynamics/{agent_id}", headers=get_headers())
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)

    data = resp.json()

    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        return data

    info = data["data"]
    print(f"Agent:   {info['agent_id']}")
    print(f"Status:  {info['status']}")
    print(f"Model:   {info.get('url') or 'Not generated'}")

    gestures = info.get("gestures", {})
    if gestures:
        print(f"\nAvailable gestures ({len(gestures)}):")
        for name, url in gestures.items():
            display_url = f"{url[:80]}..." if len(url) > 80 else url
            print(f"  {name}: {display_url}")
    else:
        print("\nNo gestures generated yet. Run with --generate to create them.")

    return data


def generate_dynamics(agent_id: str, duration: int = 3, model: str = "seedance"):
    """POST /v1/dynamics/generate -- start dynamics generation."""
    try:
        resp = requests.post(
            f"{BASE_URL}/v1/dynamics/generate",
            headers=get_headers(),
            json={"agent_id": agent_id, "duration": duration, "model": model},
        )
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)

    data = resp.json()

    if data.get("success"):
        print(f"Dynamics generation started for {agent_id}")
        print(f"  Duration: {duration}s, Model: {model}")
    else:
        print(f"Error: {data.get('message', 'Unknown error')}")

    return data


def poll_dynamics(agent_id: str, interval: int = 10, timeout: int = 300):
    """Poll dynamics status until ready."""
    print(f"Polling dynamics for {agent_id}...")
    start = time.time()

    while time.time() - start < timeout:
        try:
            resp = requests.get(f"{BASE_URL}/v1/dynamics/{agent_id}", headers=get_headers())
        except requests.exceptions.ConnectionError:
            print(f"  Warning: Cannot reach {BASE_URL}, retrying...")
            time.sleep(interval)
            continue

        info = resp.json().get("data", {})
        status = info.get("status", "unknown")
        elapsed = int(time.time() - start)
        print(f"  [{elapsed:3d}s] status={status}")

        if status == "ready" and info.get("gestures"):
            print(f"\nDynamics ready! {len(info['gestures'])} gestures available.")
            return info

        time.sleep(interval)

    print(f"\nTimeout after {timeout}s")
    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bitHuman dynamics management")
    parser.add_argument("--agent-id", required=True, help="Agent code (e.g. A91XMB7113)")
    parser.add_argument("--generate", action="store_true", help="Generate new dynamics")
    parser.add_argument("--duration", type=int, default=5, help="Gesture duration in seconds (default: 5)")
    parser.add_argument("--model", default="seedance", choices=["seedance", "kling"])
    args = parser.parse_args()

    if args.generate:
        generate_dynamics(args.agent_id, args.duration, args.model)
        poll_dynamics(args.agent_id)
    else:
        get_dynamics(args.agent_id)
