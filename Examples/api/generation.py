"""bitHuman Platform API -- Agent Generation

Create a new AI avatar agent from a text prompt, then poll until it's ready.
Optionally download the .imx model file for self-hosted deployment.

Usage:
    export BITHUMAN_API_SECRET=your_secret
    python generation.py
    python generation.py --prompt "You are a fitness coach" --image https://example.com/face.jpg
    python generation.py --prompt "A friendly tutor" --download    # generate + download .imx
    python generation.py --download --agent-id A91XMB7113          # download existing agent
"""

import argparse
import os
import sys
import time

import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = "https://api.bithuman.ai"


def get_headers():
    api_secret = os.environ.get("BITHUMAN_API_SECRET")
    if not api_secret:
        print("Error: Set BITHUMAN_API_SECRET environment variable")
        sys.exit(1)
    return {"Content-Type": "application/json", "api-secret": api_secret}


def generate_agent(
    prompt: str = "You are a friendly AI assistant.",
    image: str | None = None,
    video: str | None = None,
    audio: str | None = None,
    aspect_ratio: str = "16:9",
):
    """POST /v1/agent/generate -- start agent generation."""
    body = {"prompt": prompt, "aspect_ratio": aspect_ratio}
    if image:
        body["image"] = image
    if video:
        body["video"] = video
    if audio:
        body["audio"] = audio

    resp = requests.post(f"{BASE_URL}/v1/agent/generate", headers=get_headers(), json=body)
    data = resp.json()

    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        sys.exit(1)

    print(f"Generation started: agent_id={data['agent_id']}")
    return data["agent_id"]


def poll_status(agent_id: str, interval: int = 5, timeout: int = 600):
    """GET /v1/agent/status/{agent_id} -- poll until ready or failed."""
    print(f"Polling status for {agent_id} (timeout: {timeout}s)...")
    start = time.time()

    while time.time() - start < timeout:
        resp = requests.get(
            f"{BASE_URL}/v1/agent/status/{agent_id}",
            headers=get_headers(),
        )
        data = resp.json()["data"]
        status = data["status"]
        elapsed = int(time.time() - start)
        print(f"  [{elapsed:3d}s] {agent_id} status={status}")

        if status == "ready":
            print(f"\nAgent ready!")
            print(f"  Model URL: {data.get('model_url', 'N/A')}")
            print(f"  Image URL: {data.get('image_url', 'N/A')}")
            print(f"  Video URL: {data.get('video_url', 'N/A')}")
            return data
        elif status == "failed":
            print(f"\nGeneration failed: {data.get('error_message', 'Unknown error')}")
            return data

        time.sleep(interval)

    print(f"\nTimeout after {timeout}s -- agent may still be generating.")
    print(f"Check manually: python management.py --agent-id {agent_id}")
    return None


def get_agent(agent_id: str):
    """GET /v1/agent/{agent_id} -- retrieve agent details."""
    resp = requests.get(f"{BASE_URL}/v1/agent/{agent_id}", headers=get_headers())
    data = resp.json()
    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        sys.exit(1)
    return data["data"]


def download_model(model_url: str, output_path: str):
    """Download .imx model file from the given URL."""
    print(f"Downloading model to {output_path} ...")
    resp = requests.get(model_url, stream=True)
    resp.raise_for_status()

    total = int(resp.headers.get("content-length", 0))
    downloaded = 0

    with open(output_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=8192):
            f.write(chunk)
            downloaded += len(chunk)
            if total:
                pct = downloaded * 100 // total
                mb = downloaded / 1024 / 1024
                print(f"\r  {mb:.1f} MB ({pct}%)", end="", flush=True)

    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"\n  Saved: {output_path} ({size_mb:.1f} MB)")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bitHuman agent generation")
    parser.add_argument("--prompt", default="You are a friendly AI assistant.",
                        help="System prompt for the agent")
    parser.add_argument("--image", help="Image URL for agent appearance")
    parser.add_argument("--video", help="Video URL for agent appearance")
    parser.add_argument("--audio", help="Audio URL for agent voice")
    parser.add_argument("--aspect-ratio", default="16:9", choices=["16:9", "9:16", "1:1"])
    parser.add_argument("--timeout", type=int, default=600, help="Polling timeout in seconds")
    parser.add_argument("--download", action="store_true",
                        help="Download the .imx model file after generation")
    parser.add_argument("--output", help="Output path for .imx file (default: ./{agent_id}.imx)")
    parser.add_argument("--agent-id", help="Download model for an existing agent (skip generation)")
    args = parser.parse_args()

    if args.agent_id and args.download:
        # Download model for an existing agent
        agent_data = get_agent(args.agent_id)
        model_url = agent_data.get("model_url")
        if not model_url:
            print(f"Error: Agent {args.agent_id} has no model URL (status: {agent_data.get('status')})")
            sys.exit(1)
        output = args.output or f"{args.agent_id}.imx"
        download_model(model_url, output)
    else:
        # Generate new agent
        agent_id = generate_agent(
            prompt=args.prompt,
            image=args.image,
            video=args.video,
            audio=args.audio,
            aspect_ratio=args.aspect_ratio,
        )
        result = poll_status(agent_id, timeout=args.timeout)

        if args.download and result and result.get("status") == "ready":
            model_url = result.get("model_url")
            if model_url:
                output = args.output or f"{agent_id}.imx"
                download_model(model_url, output)
            else:
                print("Warning: Agent is ready but no model URL found.")
