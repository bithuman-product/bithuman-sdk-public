"""bitHuman Platform API -- File Upload

Upload images, videos, audio, or documents to use with agent generation.

Usage:
    export BITHUMAN_API_SECRET=your_secret
    python upload.py --url https://example.com/face.jpg
    python upload.py --file ./avatar.jpg
"""

import argparse
import base64
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


def upload_from_url(file_url: str, file_type: str = "auto"):
    """Upload a file by URL. bitHuman fetches and stores it."""
    body: dict = {"file_url": file_url}
    if file_type != "auto":
        body["file_type"] = file_type

    try:
        resp = requests.post(f"{BASE_URL}/v1/files/upload", headers=get_headers(), json=body)
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)

    data = resp.json()

    if data.get("success"):
        info = data["data"]
        print(f"Uploaded: {info['file_url']}")
        print(f"  Type: {info.get('mime_type', 'N/A')}, Size: {info.get('file_size', 'N/A')} bytes")
    else:
        print(f"Error: {data.get('message', 'Unknown error')}")

    return data


def upload_from_file(file_path: str, file_type: str = "auto"):
    """Upload a local file as base64."""
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with open(file_path, "rb") as f:
        file_data = base64.b64encode(f.read()).decode("utf-8")

    body: dict = {"file_data": file_data, "file_name": os.path.basename(file_path)}
    if file_type != "auto":
        body["file_type"] = file_type

    try:
        resp = requests.post(f"{BASE_URL}/v1/files/upload", headers=get_headers(), json=body)
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot reach {BASE_URL}. Check your internet connection.")
        sys.exit(1)

    data = resp.json()

    if data.get("success"):
        info = data["data"]
        print(f"Uploaded: {info['file_url']}")
        print(f"  Type: {info.get('mime_type', 'N/A')}, Size: {info.get('file_size', 'N/A')} bytes")
    else:
        print(f"Error: {data.get('message', 'Unknown error')}")

    return data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bitHuman file upload")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--url", help="URL of file to upload")
    group.add_argument("--file", help="Local file path to upload")
    parser.add_argument("--type", default="auto",
                        help="File type hint (image, video, audio, pdf, auto)")
    args = parser.parse_args()

    if args.url:
        upload_from_url(args.url, args.type)
    else:
        upload_from_file(args.file, args.type)
