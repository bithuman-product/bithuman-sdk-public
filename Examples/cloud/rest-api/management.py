"""bitHuman Platform API -- Agent Management

Validate your API secret, list agent details, and update agent prompts.

Usage:
    export BITHUMAN_API_SECRET=your_secret
    python management.py
    python management.py --agent-id A91XMB7113
"""

import argparse
import os
import sys

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


def validate():
    """POST /v1/validate -- verify your API secret is valid."""
    try:
        resp = requests.post(f"{BASE_URL}/v1/validate", headers=get_headers())
        resp.raise_for_status()
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)
    except requests.exceptions.HTTPError:
        if resp.status_code == 401:
            print("Error: Invalid API secret. Check your BITHUMAN_API_SECRET.")
        else:
            print(f"Error: HTTP {resp.status_code} -- {resp.text[:200]}")
        sys.exit(1)

    data = resp.json()
    print(f"API secret valid: {data.get('valid', False)}")
    return data


def get_agent(agent_id: str):
    """GET /v1/agent/{code} -- retrieve agent details."""
    try:
        resp = requests.get(f"{BASE_URL}/v1/agent/{agent_id}", headers=get_headers())
        resp.raise_for_status()
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)
    except requests.exceptions.HTTPError:
        if resp.status_code == 404:
            print(f"Error: Agent {agent_id} not found.")
        elif resp.status_code == 401:
            print("Error: Invalid API secret. Check your BITHUMAN_API_SECRET.")
        else:
            print(f"Error: HTTP {resp.status_code} -- {resp.text[:200]}")
        sys.exit(1)

    data = resp.json()

    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        return data

    agent = data["data"]
    print(f"Agent:   {agent.get('name', 'N/A')} ({agent['agent_id']})")
    print(f"Status:  {agent['status']}")
    print(f"Prompt:  {agent.get('system_prompt', 'N/A')[:100]}")
    print(f"Image:   {agent.get('image_url', 'N/A')}")
    print(f"Model:   {agent.get('model_url', 'N/A')}")
    return data


def update_prompt(agent_id: str, new_prompt: str):
    """POST /v1/agent/{code} -- update agent system prompt."""
    resp = requests.post(
        f"{BASE_URL}/v1/agent/{agent_id}",
        headers=get_headers(),
        json={"system_prompt": new_prompt},
    )
    data = resp.json()
    if data.get("success"):
        print(f"Prompt updated for {agent_id}")
    else:
        print(f"Error: {data.get('message', 'Unknown error')}")
    return data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bitHuman agent management")
    parser.add_argument("--agent-id", default=os.getenv("BITHUMAN_AGENT_ID"),
                        help="Agent code (e.g. A91XMB7113)")
    args = parser.parse_args()

    # 1. Validate credentials
    print("--- Validating API secret ---")
    validate()

    # 2. Get agent info (if agent ID provided)
    if args.agent_id:
        print(f"\n--- Agent info: {args.agent_id} ---")
        get_agent(args.agent_id)

        # 3. Update prompt (uncomment to test)
        # print(f"\n--- Updating prompt ---")
        # update_prompt(args.agent_id, "You are a professional sales assistant.")
    else:
        print("\nTip: Pass --agent-id to view agent details")
