"""Gemini Live Avatar -- conversational AI avatar powered by Gemini Live API + bitHuman.

Usage:
    python main.py --model avatar.imx --api-secret SECRET --gemini-api-key KEY
"""

import argparse, asyncio, os, sys, threading, time
from typing import Optional
import cv2, numpy as np
from dotenv import load_dotenv
from loguru import logger
from bithuman import AsyncBithuman
from bithuman.audio import float32_to_int16, load_audio
from bithuman.utils import FPSController
from dynamics import DynamicsHandler
from google import genai
from google.genai import types

try:
    import sounddevice as sd
except ImportError:
    sd = None

logger.remove()
logger.add(sys.stdout, level="INFO")
GEMINI_SR_IN, GEMINI_SR_OUT = 16000, 24000

# ---------------------------------------------------------------------------
# Audio I/O
# ---------------------------------------------------------------------------

class AudioPlayer:
    """Buffered speaker output via sounddevice."""
    def __init__(self, sr=16000):
        self.sr, self.buf, self.lock, self.stream = sr, bytearray(), threading.Lock(), None
    def start(self):
        if not sd: return
        self.stream = sd.OutputStream(callback=self._cb, dtype="int16", channels=1,
                                      samplerate=self.sr, blocksize=self.sr // 25)
        self.stream.start()
    def stop(self):
        if self.stream: self.stream.stop(); self.stream.close(); self.stream = None
    def clear(self):
        with self.lock: self.buf.clear()
    def add(self, data):
        if isinstance(data, np.ndarray) and data.dtype == np.float32:
            data = (data * 32768.0).astype(np.int16)
        with self.lock:
            self.buf.extend(data.tobytes() if isinstance(data, np.ndarray) else data)
    def _cb(self, out, frames, _ti, _st):
        with self.lock:
            have = min(len(self.buf), frames * 2)
            out[:have // 2, 0] = np.frombuffer(self.buf[:have], dtype=np.int16)
            out[have // 2:, 0] = 0
            del self.buf[:have]


class AudioRecorder:
    """Microphone capture into an asyncio queue."""
    def __init__(self, sr=16000, device=None):
        self.sr, self.device, self.stream = sr, device, None
        self.queue: asyncio.Queue[bytes] = asyncio.Queue()
    def start(self):
        if not sd: return
        self.stream = sd.InputStream(callback=self._cb, dtype="int16", channels=1,
                                     samplerate=self.sr, blocksize=self.sr // 10, device=self.device)
        self.stream.start()
    def stop(self):
        if self.stream: self.stream.stop(); self.stream.close(); self.stream = None
    def _cb(self, data, _f, _ti, _st):
        try: self.queue.put_nowait(data.copy().tobytes())
        except asyncio.QueueFull: pass

# ---------------------------------------------------------------------------
# Gemini Live session
# ---------------------------------------------------------------------------

class GeminiLiveSession:
    """Bidirectional audio streaming with Gemini Live API."""
    def __init__(self, api_key, model="gemini-2.0-flash-exp", voice="Kore", instructions=""):
        self.api_key, self.model, self.voice, self.instructions = api_key, model, voice, instructions
        self._session = self._ctx = None
        self.status = "disconnected"

    async def connect(self):
        client = genai.Client(api_key=self.api_key)
        cfg = types.LiveConnectConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=self.voice))),
            input_audio_transcription=types.AudioTranscriptionConfig())
        if self.instructions:
            cfg.system_instruction = types.Content(parts=[types.Part(text=self.instructions)])
        self._ctx = client.aio.live.connect(model=self.model, config=cfg)
        self._session = await self._ctx.__aenter__()
        self.status = "connected"
        logger.info("Gemini Live connected")

    async def disconnect(self):
        if self._ctx:
            try: await self._ctx.__aexit__(None, None, None)
            except Exception: pass
            self._ctx = self._session = None
        self.status = "disconnected"

    async def send_audio(self, audio_bytes, sr=16000):
        if not self._session: return
        try:
            await self._session.send(
                input=types.LiveClientRealtimeInput(media_chunks=[
                    types.Blob(mime_type=f"audio/pcm;rate={sr}", data=audio_bytes)]),
                end_of_turn=False)
        except Exception as e:
            if "closed" in str(e).lower(): self.status = "disconnected"

    async def send_text(self, text):
        if not self._session: return
        await self._session.send(
            input=types.LiveClientContent(
                turns=[types.Content(role="user", parts=[types.Part(text=text)])],
                turn_complete=True), end_of_turn=True)

    async def receive_responses(self):
        """Yield (audio_bytes | None, text | None) tuples."""
        if not self._session: return
        self.status = "listening"
        try:
            async for resp in self._session.receive():
                sc = resp.server_content
                if not sc: continue
                if sc.model_turn:
                    self.status = "speaking"
                    for p in sc.model_turn.parts or []:
                        if p.inline_data and isinstance(p.inline_data.data, bytes):
                            yield (p.inline_data.data, None)
                        if p.text: yield (None, p.text)
                if sc.turn_complete:
                    self.status = "listening"; yield (None, "[TURN_COMPLETE]")
                if getattr(sc, "input_transcription", None) and sc.input_transcription.text:
                    yield (None, f"[USER]: {sc.input_transcription.text}")
        except asyncio.CancelledError: pass
        except Exception as e:
            if "closed" in str(e).lower(): self.status = "disconnected"
            else: logger.error(f"Gemini receive error: {e}")

    async def interrupt(self):
        if self._session:
            await self._session.send(
                input=types.LiveClientRealtimeInput(media_chunks=[]), end_of_turn=True)

# ---------------------------------------------------------------------------
# Pipeline coroutines
# ---------------------------------------------------------------------------

async def push_audio_file(runtime, path, delay=0.0):
    """Stream an audio file into the bitHuman runtime."""
    await asyncio.sleep(delay)
    audio_np, sr = load_audio(path)
    audio_np = float32_to_int16(audio_np)
    for i in range(0, len(audio_np), sr // 100):
        await runtime.push_audio(audio_np[i:i + sr // 100].tobytes(), sr, last_chunk=False)
        await asyncio.sleep(0.008)
    await runtime.flush()

async def mic_to_gemini(recorder, gemini, alive):
    while alive():
        try:
            chunk = await asyncio.wait_for(recorder.queue.get(), 0.5)
            await gemini.send_audio(chunk, GEMINI_SR_IN)
        except (asyncio.TimeoutError, asyncio.CancelledError): continue

async def gemini_to_bithuman(gemini, runtime, dynamics, alive):
    ratio = GEMINI_SR_IN / GEMINI_SR_OUT
    while alive():
        try:
            async for audio, text in gemini.receive_responses():
                if not alive(): break
                if audio:
                    pcm = np.frombuffer(audio, dtype=np.int16)
                    pcm = np.interp(np.linspace(0, len(pcm)-1, int(len(pcm)*ratio)),
                                    np.arange(len(pcm)), pcm).astype(np.int16)
                    await runtime.push_audio(pcm.tobytes(), GEMINI_SR_IN, last_chunk=False)
                if text == "[TURN_COMPLETE]": await runtime.flush()
                elif text and text.startswith("[USER]:"): await dynamics.check_and_trigger(text[7:])
            await asyncio.sleep(0.1)
        except asyncio.CancelledError: break
        except Exception as e:
            if "closed" in str(e).lower(): break
            logger.error(f"Gemini stream error: {e}"); await asyncio.sleep(1)

async def render_loop(runtime, args, gemini, dynamics, player, alive):
    """Avatar render + OpenCV display.  Keys: 1=replay, 2=interrupt, q=quit."""
    fps_ctl = FPSController(target_fps=25)
    w, h = runtime.get_frame_size()
    cv2.namedWindow("bitHuman", cv2.WINDOW_NORMAL); cv2.resizeWindow("bitHuman", w, h)
    t0 = time.time()
    atask = asyncio.create_task(push_audio_file(runtime, args.audio_file, 1.0)) if args.audio_file else None
    await runtime.start()
    async for frame in runtime.run():
        if not alive[0]: break
        sl = fps_ctl.wait_next_frame(sleep=False)
        if sl > 0: await asyncio.sleep(sl)
        if frame.audio_chunk and player: player.add(frame.audio_chunk.array)
        if frame.has_image:
            img = frame.bgr_image.copy()
            for y, txt, c in [(30, f"FPS: {fps_ctl.average_fps:.1f}", (0,255,0)),
                               (60, f"Time: {time.time()-t0:.1f}s", (0,255,0)),
                               (90, f"Gemini: {gemini.status}", (0,255,255))]:
                cv2.putText(img, txt, (10,y), cv2.FONT_HERSHEY_SIMPLEX, 0.7, c, 2)
            cv2.putText(img, "[1] Replay [2] Interrupt [q] Quit",
                        (10, img.shape[0]-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200,200,200), 1)
            cv2.imshow("bitHuman", img)
            key = cv2.waitKey(1) & 0xFF
            if key == ord("1") and args.audio_file:
                if atask and not atask.done(): atask.cancel()
                atask = asyncio.create_task(push_audio_file(runtime, args.audio_file))
            elif key == ord("2"):
                runtime.interrupt()
                if player: player.clear()
                if gemini: await gemini.interrupt()
            elif key == ord("q"): alive[0] = False; break
        fps_ctl.update()
    cv2.destroyAllWindows()
    if atask and not atask.done(): atask.cancel()

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def main():
    load_dotenv()
    p = argparse.ArgumentParser(description="Gemini Live Avatar (bitHuman)")
    p.add_argument("--model", default=os.environ.get("BITHUMAN_MODEL_PATH"))
    p.add_argument("--api-secret", default=os.environ.get("BITHUMAN_API_SECRET"))
    p.add_argument("--agent-id", default=os.environ.get("BITHUMAN_AGENT_ID"))
    p.add_argument("--gemini-api-key", default=os.environ.get("GOOGLE_API_KEY"))
    p.add_argument("--gemini-model", default="gemini-2.0-flash-exp")
    p.add_argument("--gemini-voice", default="Kore", choices=["Puck","Charon","Kore","Fenrir","Aoede"])
    p.add_argument("--instructions", default="")
    p.add_argument("--audio-file", default=os.environ.get("BITHUMAN_AUDIO_PATH"))
    p.add_argument("--audio-device", type=int, default=None)
    a = p.parse_args()
    for flag, val in [("--model",a.model),("--api-secret",a.api_secret),("--gemini-api-key",a.gemini_api_key)]:
        if not val: logger.error(f"{flag} is required"); sys.exit(1)

    runtime = await AsyncBithuman.create(model_path=a.model, api_secret=a.api_secret, insecure=True)
    player = AudioPlayer(); player.start()
    recorder = None
    if not a.audio_file:
        recorder = AudioRecorder(sr=GEMINI_SR_IN, device=a.audio_device); recorder.start()
    gemini = GeminiLiveSession(
        api_key=a.gemini_api_key, model=a.gemini_model, voice=a.gemini_voice,
        instructions=a.instructions or "You are a helpful AI assistant with a visual avatar. Be concise.")
    await gemini.connect()
    dynamics = DynamicsHandler(runtime, agent_id=a.agent_id, api_secret=a.api_secret)
    await dynamics.initialize()

    alive = [True]
    tasks = [asyncio.create_task(render_loop(runtime, a, gemini, dynamics, player, alive)),
             asyncio.create_task(gemini_to_bithuman(gemini, runtime, dynamics, lambda: alive[0]))]
    if recorder:
        tasks.append(asyncio.create_task(mic_to_gemini(recorder, gemini, lambda: alive[0])))
    try: await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        alive[0] = False
        for t in tasks: t.cancel()
        if recorder: recorder.stop()
        player.stop(); await gemini.disconnect(); await runtime.stop()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: logger.info("Interrupted")
