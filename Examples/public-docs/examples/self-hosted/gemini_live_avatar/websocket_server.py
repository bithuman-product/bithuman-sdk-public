"""WebSocket server for streaming bitHuman avatar audio/video to remote clients.

Protocol:
  Client -> Server (JSON):  {"type": "audio_input|text_input|control", "data": {...}}
  Server -> Client (binary): video/audio with struct headers
  Server -> Client (JSON):   status messages
"""

import asyncio, base64, json, struct, time
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass
from typing import Any, Optional
import cv2, numpy as np
from loguru import logger

try:
    import websockets
    from websockets.server import WebSocketServerProtocol
except ImportError:
    websockets = None


class MessageType:
    AUDIO_INPUT = "audio_input"
    TEXT_INPUT = "text_input"
    CONTROL = "control"
    VIDEO_FRAME = "video_frame"
    AUDIO_OUTPUT = "audio_output"
    STATUS = "status"

@dataclass
class AudioChunk:
    data: bytes
    sample_rate: int
    channels: int = 1
    timestamp: float = 0.0

@dataclass
class ClientConnection:
    websocket: WebSocketServerProtocol
    client_id: str
    subscribed_video: bool = True
    subscribed_audio: bool = True


class MediaWebSocketServer:
    """WebSocket server: receives audio input, broadcasts video/audio output."""

    def __init__(self, host="0.0.0.0", port=8765, video_quality=80, max_clients=10):
        self.host, self.port, self.video_quality, self.max_clients = host, port, video_quality, max_clients
        self.clients: dict[str, ClientConnection] = {}
        self._counter, self._server, self._running = 0, None, False
        self._on_audio: Optional[Callable] = None
        self._on_text: Optional[Callable] = None
        self._on_control: Optional[Callable] = None

    def set_audio_callback(self, cb): self._on_audio = cb
    def set_text_callback(self, cb): self._on_text = cb
    def set_control_callback(self, cb): self._on_control = cb

    async def start(self):
        if not websockets: raise RuntimeError("websockets not installed")
        self._running = True
        self._server = await websockets.serve(self._handle_client, self.host, self.port,
                                              ping_interval=30, ping_timeout=10)
        logger.info(f"WebSocket server at ws://{self.host}:{self.port}")

    async def stop(self):
        self._running = False
        if self._server: self._server.close(); await self._server.wait_closed()
        for c in list(self.clients.values()): await c.websocket.close()
        self.clients.clear()

    async def broadcast_video_frame(self, frame_bgr: np.ndarray, fps=0.0):
        if not self.clients: return
        _, jpg = cv2.imencode(".jpg", frame_bgr, [cv2.IMWRITE_JPEG_QUALITY, self.video_quality])
        b = jpg.tobytes(); h, w = frame_bgr.shape[:2]
        hdr = struct.pack("!BHHFI", 0x01, w, h, fps, len(b)) + struct.pack("!d", time.time())
        await self._send_all(hdr + b, video=True)

    async def broadcast_audio_chunk(self, audio, sample_rate=16000):
        if not self.clients: return
        if isinstance(audio, np.ndarray):
            audio = ((audio * 32768).astype(np.int16) if audio.dtype == np.float32 else audio).tobytes()
        hdr = struct.pack("!BIBI", 0x02, sample_rate, 1, len(audio)) + struct.pack("!d", time.time())
        await self._send_all(hdr + audio, video=False)

    async def _send_all(self, payload, video):
        for c in list(self.clients.values()):
            if (video and not c.subscribed_video) or (not video and not c.subscribed_audio): continue
            try: await c.websocket.send(payload)
            except Exception: pass

    async def _handle_client(self, ws: WebSocketServerProtocol, path: str):
        if len(self.clients) >= self.max_clients:
            await ws.close(1013, "Max clients"); return
        self._counter += 1; cid = f"client_{self._counter}"
        self.clients[cid] = ClientConnection(websocket=ws, client_id=cid)
        logger.info(f"{cid} connected")
        await ws.send(json.dumps({"type": "status", "data": {"status": "connected", "client_id": cid}}))
        try:
            async for msg in ws: await self._process(cid, msg)
        except websockets.exceptions.ConnectionClosed: pass
        finally: self.clients.pop(cid, None); logger.info(f"{cid} disconnected")

    async def _process(self, cid, message):
        try:
            data = json.loads(message) if isinstance(message, str) else {"type": "audio_input", "raw_data": message}
            mt = data.get("type", "")
            if mt == "audio_input":
                if "raw_data" in data: ab, sr = data["raw_data"], 16000
                else: ab, sr = base64.b64decode(data.get("data", "")), data.get("sample_rate", 16000)
                chunk = AudioChunk(data=ab, sample_rate=sr, timestamp=time.time())
                if self._on_audio: await self._maybe_await(self._on_audio(chunk, cid))
            elif mt == "text_input":
                txt = data.get("data", {}).get("text", "")
                if txt and self._on_text: await self._maybe_await(self._on_text(txt, cid))
            elif mt == "control":
                cmd, params = data.get("data",{}).get("command",""), data.get("data",{}).get("params",{})
                if cmd == "subscribe":
                    c = self.clients.get(cid)
                    if c: c.subscribed_video = params.get("video", True); c.subscribed_audio = params.get("audio", True)
                elif self._on_control: await self._maybe_await(self._on_control(cmd, params, cid))
        except Exception as e: logger.error(f"Message error from {cid}: {e}")

    @staticmethod
    async def _maybe_await(result):
        if asyncio.iscoroutine(result): await result

    @property
    def client_count(self): return len(self.clients)


class WebSocketAudioInput:
    """Async iterator that collects audio from WebSocket clients."""
    def __init__(self, sample_rate=16000):
        self.sample_rate = sample_rate
        self._queue: asyncio.Queue[AudioChunk] = asyncio.Queue(maxsize=100)
        self._running = False
    def start(self): self._running = True
    def stop(self): self._running = False
    async def push_audio(self, chunk, client_id):
        if not self._running: return
        try: self._queue.put_nowait(chunk)
        except asyncio.QueueFull:
            try: self._queue.get_nowait(); self._queue.put_nowait(chunk)
            except asyncio.QueueEmpty: pass
    async def __aiter__(self) -> AsyncIterator[AudioChunk]:
        while self._running:
            try: yield await asyncio.wait_for(self._queue.get(), 0.5)
            except asyncio.TimeoutError: continue


class WebSocketVideoOutput:
    """Rate-limited video broadcaster."""
    def __init__(self, server: MediaWebSocketServer, fps=25.0):
        self.server, self._interval, self._last = server, 1.0/fps, 0.0
    async def push_frame(self, frame_bgr, fps=0.0):
        now = time.time()
        if now - self._last < self._interval * 0.9: return
        await self.server.broadcast_video_frame(frame_bgr, fps); self._last = now


class WebSocketAudioOutput:
    """Audio broadcaster."""
    def __init__(self, server: MediaWebSocketServer, sample_rate=16000):
        self.server, self.sample_rate = server, sample_rate
    async def push_audio(self, audio_data, sample_rate=None):
        await self.server.broadcast_audio_chunk(audio_data, sample_rate or self.sample_rate)
