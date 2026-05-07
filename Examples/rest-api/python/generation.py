from __future__ import annotations

"""bitHuman Platform API -- Agent Generation

Generate an AI avatar agent and optionally download its .imx model file.

Prerequisites:
    1. Get your API secret at https://www.bithuman.ai (Developer section)
    2. pip install -r requirements.txt

Examples:
    # Generate a new agent (~4 min)
    python generation.py --prompt "You are a fitness coach"

    # Generate with a custom face image
    python generation.py --prompt "A news anchor" --image https://example.com/face.jpg

    # Generate and download .imx model for self-hosted use
    python generation.py --prompt "A friendly tutor" --download

    # Download .imx model for an agent you already have
    python generation.py --download --agent-id A91XMB7113
"""

import argparse
import os
import sys
import time

import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("BITHUMAN_API_URL", "https://api.bithuman.ai")

# Spinner frames for status polling
SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]


def get_headers():
    secret = os.getenv("BITHUMAN_API_SECRET")
    if not secret:
        print("Error: BITHUMAN_API_SECRET not set.")
        print("  Get yours at https://www.bithuman.ai/#developer")
        print("  Then: export BITHUMAN_API_SECRET='your_secret'")
        sys.exit(1)
    return {"Content-Type": "application/json", "api-secret": secret}


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

    print(f"Starting agent generation...")
    print(f"  Prompt: {prompt[:80]}{'...' if len(prompt) > 80 else ''}")
    if image:
        print(f"  Image:  {image}")
    if video:
        print(f"  Video:  {video}")
    if audio:
        print(f"  Audio:  {audio}")
    print()

    try:
        resp = requests.post(f"{BASE_URL}/v1/agent/generate", headers=get_headers(), json=body)
        resp.raise_for_status()
    except requests.exceptions.ConnectionError:
        print("Error: Cannot reach api.bithuman.ai. Check your internet connection.")
        sys.exit(1)
    except requests.exceptions.HTTPError:
        if resp.status_code == 401:
            print("Error: Invalid API secret. Check your BITHUMAN_API_SECRET.")
        elif resp.status_code == 402:
            print("Error: Insufficient credits. Top up at https://www.bithuman.ai")
        else:
            print(f"Error: HTTP {resp.status_code} -- {resp.text[:200]}")
        sys.exit(1)

    data = resp.json()

    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        sys.exit(1)

    agent_id = data["agent_id"]
    print(f"Agent ID: {agent_id}")
    print(f"Generation takes ~4 minutes. Waiting...\n")
    return agent_id


def poll_status(agent_id: str, interval: int = 5, timeout: int = 600):
    """GET /v1/agent/status/{agent_id} -- poll until ready or failed."""
    start = time.time()
    tick = 0

    while time.time() - start < timeout:
        try:
            resp = requests.get(
                f"{BASE_URL}/v1/agent/status/{agent_id}",
                headers=get_headers(),
            )
            data = resp.json().get("data", {})
            if not data:
                print(f"\n  Warning: No data in status response, retrying...")
                time.sleep(interval)
                continue
        except Exception as e:
            print(f"\n  Warning: Status check failed ({e}), retrying...")
            time.sleep(interval)
            continue

        status = data["status"]
        progress = data.get("progress")
        progress_msg = data.get("progress_msg", "")
        elapsed = int(time.time() - start)
        mins, secs = divmod(elapsed, 60)
        spinner = SPINNER[tick % len(SPINNER)]
        tick += 1

        if progress is not None:
            pct = int(progress * 100)
            bar = "=" * (pct // 5) + " " * (20 - pct // 5)
            print(f"\r  {spinner} [{mins}:{secs:02d}] [{bar}] {pct}% {progress_msg}      ", end="", flush=True)
        else:
            print(f"\r  {spinner} [{mins}:{secs:02d}] {status}        ", end="", flush=True)

        if status == "ready":
            print(f"\r  Done! Agent ready in {mins}m {secs}s.            ")
            print()
            print(f"  Agent ID:  {agent_id}")
            if data.get("model_url"):
                print(f"  Model:     {data['model_url']}")
            if data.get("image_url"):
                print(f"  Image:     {data['image_url']}")
            if data.get("video_url"):
                print(f"  Video:     {data['video_url']}")
            return data

        if status == "failed":
            print(f"\r  Generation failed after {mins}m {secs}s.         ")
            error = data.get("error_message", "Unknown error")
            print(f"  Error: {error}")
            return data

        time.sleep(interval)

    elapsed = int(time.time() - start)
    print(f"\r  Timed out after {elapsed}s. The agent may still be generating.")
    print(f"  Check later:  python generation.py --download --agent-id {agent_id}")
    return None


def get_agent(agent_id: str):
    """GET /v1/agent/{agent_id} -- retrieve agent details."""
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
            print("Error: Invalid API secret.")
        else:
            print(f"Error: HTTP {resp.status_code}")
        sys.exit(1)

    data = resp.json()
    if not data.get("success"):
        print(f"Error: {data.get('message', 'Unknown error')}")
        sys.exit(1)
    return data["data"]


def download_model(model_url: str, output_path: str):
    """Download .imx model file from the given URL."""
    # Create parent directories if needed
    parent = os.path.dirname(output_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    print(f"Downloading .imx model...")
    print(f"  Saving to: {output_path}")

    try:
        resp = requests.get(model_url, stream=True)
        resp.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(f"  Error downloading model: {e}")
        sys.exit(1)

    total = int(resp.headers.get("content-length", 0))
    downloaded = 0

    with open(output_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=65536):
            f.write(chunk)
            downloaded += len(chunk)
            if total:
                pct = downloaded * 100 // total
                mb = downloaded / 1024 / 1024
                total_mb = total / 1024 / 1024
                bar = "=" * (pct // 5) + " " * (20 - pct // 5)
                print(f"\r  [{bar}] {mb:.0f}/{total_mb:.0f} MB ({pct}%)", end="", flush=True)
            else:
                mb = downloaded / 1024 / 1024
                print(f"\r  {mb:.1f} MB downloaded", end="", flush=True)

    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"\r  Downloaded: {output_path} ({size_mb:.0f} MB)                     ")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a bitHuman AI avatar agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  %(prog)s --prompt "A fitness coach"
  %(prog)s --prompt "A news anchor" --image https://example.com/face.jpg
  %(prog)s --prompt "A tutor" --download
  %(prog)s --download --agent-id A91XMB7113
  %(prog)s --download --agent-id A91XMB7113 --output models/avatar.imx""",
    )
    parser.add_argument("--prompt", default="You are a friendly AI assistant.",
                        help="system prompt / personality for the agent")
    parser.add_argument("--image", help="face image URL to use for the agent")
    parser.add_argument("--video", help="video URL for agent appearance")
    parser.add_argument("--audio", help="audio URL for agent voice")
    parser.add_argument("--aspect-ratio", default="16:9", choices=["16:9", "9:16", "1:1"],
                        help="video aspect ratio (default: 16:9)")
    parser.add_argument("--timeout", type=int, default=600,
                        help="max seconds to wait for generation (default: 600)")
    parser.add_argument("--download", action="store_true",
                        help="download the .imx model file when ready")
    parser.add_argument("--output", metavar="PATH",
                        help="save .imx to this path (default: ./{agent_id}.imx)")
    parser.add_argument("--agent-id",
                        help="skip generation, download model for an existing agent")
    args = parser.parse_args()

    if args.agent_id and args.download:
        # Download model for an existing agent
        print(f"Fetching agent {args.agent_id}...")
        agent_data = get_agent(args.agent_id)
        model_url = agent_data.get("model_url")
        if not model_url:
            print(f"Error: Agent {args.agent_id} has no .imx model (status: {agent_data.get('status', 'unknown')}).")
            print("  The agent may still be generating, or it may be an Expression-only agent.")
            sys.exit(1)
        print(f"  Name:   {agent_data.get('name', 'N/A')}")
        print(f"  Status: {agent_data.get('status', 'N/A')}")
        print()
        output = args.output or f"{args.agent_id}.imx"
        download_model(model_url, output)

    elif args.agent_id and not args.download:
        # Just show agent info
        agent_data = get_agent(args.agent_id)
        print(f"Agent: {agent_data.get('name', 'N/A')} ({args.agent_id})")
        print(f"Status: {agent_data.get('status', 'N/A')}")
        if agent_data.get("model_url"):
            print(f"Model: {agent_data['model_url']}")
            print(f"\nTo download: python generation.py --download --agent-id {args.agent_id}")
        else:
            print("No .imx model available for this agent.")

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
                print()
                output = args.output or f"{agent_id}.imx"
                download_model(model_url, output)
                print(f"\nNext steps:")
                print(f"  cd ../essence-selfhosted")
                print(f"  python quickstart.py --model ../{output} --audio-file speech.wav")
            else:
                print("\nNote: Agent is ready but has no .imx model URL.")

        elif result and result.get("status") == "ready" and not args.download:
            print(f"\nTo download the .imx model:")
            print(f"  python generation.py --download --agent-id {agent_id}")
