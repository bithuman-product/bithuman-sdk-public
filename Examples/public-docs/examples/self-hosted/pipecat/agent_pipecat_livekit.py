"""
bitHuman Avatar Agent — Pipecat + LiveKit

Real-time AI avatar agent using pure Pipecat pipeline with LiveKit WebRTC transport.
No LiveKit Agents framework required — connects as a regular participant.

Pipeline: User Audio (LiveKit) -> Deepgram STT -> GPT-4o-mini -> OpenAI TTS -> bitHuman Runtime
                                                                                      |
          User Display <- LiveKitTransport <- Video/Audio Frames <- bitHuman Avatar <--+

Usage:
    pip install -r requirements.txt
    export BITHUMAN_MODEL_PATH="path/to/model.imx"
    export BITHUMAN_API_SECRET="your_bithuman_api_secret"
    export LIVEKIT_URL="wss://your-project.livekit.cloud"
    export LIVEKIT_API_KEY="your_livekit_api_key"
    export LIVEKIT_API_SECRET="your_livekit_api_secret"
    export OPENAI_API_KEY="your_openai_api_key"
    export DEEPGRAM_API_KEY="your_deepgram_api_key"
    python agent_pipecat_livekit.py --room-name my-room
"""

import argparse, asyncio, logging, os, time
import cv2, numpy as np
from dotenv import load_dotenv
from livekit import api
from scipy import signal
from pipecat.frames.frames import (
    AudioRawFrame, CancelFrame, EndFrame, Frame, InterruptionFrame,
    OutputAudioRawFrame, OutputImageRawFrame, StartFrame, StartInterruptionFrame,
    TextFrame, TTSAudioRawFrame, TTSStartedFrame, TTSStoppedFrame,
)
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor
from pipecat.services.deepgram import DeepgramSTTService
from pipecat.services.openai import OpenAILLMService, OpenAITTSService
from pipecat.transports.livekit.transport import LiveKitParams, LiveKitTransport
from bithuman import AsyncBithuman

load_dotenv()
logger = logging.getLogger("bithuman-pipecat-livekit")


def _to_int16_bytes(audio_data, sample_rate: int, target_rate: int) -> bytes | None:
    """Convert audio to int16 bytes, resampling if rates differ."""
    if isinstance(audio_data, (bytes, memoryview)):
        arr = np.frombuffer(audio_data, dtype=np.int16)
    elif isinstance(audio_data, np.ndarray):
        arr = audio_data if audio_data.dtype == np.int16 else (
            (np.clip(audio_data, -1.0, 1.0) * 32767).astype(np.int16)
            if audio_data.dtype == np.float32 else audio_data.astype(np.int16))
    else:
        return None
    if sample_rate != target_rate:
        f = arr.astype(np.float32) / 32767.0
        arr = (np.clip(signal.resample(f, int(len(f) * target_rate / sample_rate)),
                        -1.0, 1.0) * 32767).astype(np.int16)
    raw = arr.tobytes()
    return raw if len(raw) >= 2 else None


class BitHumanAvatarProcessor(FrameProcessor):
    """Drives the bitHuman avatar runtime inside a Pipecat pipeline.

    Intercepts TTS audio, feeds it to the runtime, and emits synchronized
    video + audio frames back into the pipeline.
    """

    def __init__(self, model_path: str, api_secret: str, *, video_fps: int = 25,
                 flush_delay: float = 0.5, **kwargs):
        super().__init__(**kwargs)
        self._model_path, self._api_secret = model_path, api_secret
        self._video_fps, self._flush_delay = video_fps, flush_delay
        self._runtime: AsyncBithuman | None = None
        self._render_task: asyncio.Task | None = None
        self._flush_task: asyncio.Task | None = None
        self._running = False
        self._frame_size = (512, 512)
        self._sample_rate = 16000
        self._tts_active = False
        self._in_dur = self._out_dur = 0.0

    async def _initialize_runtime(self):
        if self._runtime:
            return
        logger.info("Initializing bitHuman runtime (may take ~20 s)...")
        self._runtime = await AsyncBithuman.create(
            model_path=self._model_path, api_secret=self._api_secret, insecure=True)
        self._frame_size = self._runtime.get_frame_size()
        if hasattr(self._runtime, "settings"):
            self._sample_rate = getattr(self._runtime.settings, "INPUT_SAMPLE_RATE", 16000)
        await self._runtime.start()
        self._running = True
        self._render_task = asyncio.create_task(self._render_loop())
        await self._runtime.push_audio(  # 100 ms silence to start idle video
            b"\x00" * (self._sample_rate // 10 * 2),
            sample_rate=self._sample_rate, last_chunk=False)
        logger.info("bitHuman runtime ready (frame=%s, sr=%d)", self._frame_size, self._sample_rate)

    async def start(self, frame: StartFrame):
        await self._initialize_runtime()

    async def stop(self, frame: EndFrame):
        self._running = False
        for t in (self._flush_task, self._render_task):
            if t and not t.done():
                t.cancel()
                try: await t
                except asyncio.CancelledError: pass
        if self._runtime:
            await self._runtime.flush()
            await self._runtime.stop()
        await super().stop(frame)

    async def cancel(self, frame: CancelFrame):
        if self._runtime:
            self._runtime.interrupt()
            await self._runtime.flush()
        await super().cancel(frame)

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        if isinstance(frame, TTSAudioRawFrame):
            await self._handle_tts_audio(frame); return
        if isinstance(frame, StartFrame):
            await super().process_frame(frame, direction)
            await self.start(frame)
            await self.push_frame(frame, direction); return
        if isinstance(frame, AudioRawFrame):
            return  # STT handles user audio upstream
        await super().process_frame(frame, direction)
        if isinstance(frame, TTSStartedFrame):
            self._tts_active = True; self._cancel_flush()
            self._in_dur = self._out_dur = 0.0
        elif isinstance(frame, TTSStoppedFrame):
            self._tts_active = False; self._cancel_flush()
            if self._runtime:
                self._flush_task = asyncio.create_task(self._delayed_flush())
        elif isinstance(frame, (StartInterruptionFrame, InterruptionFrame)):
            if self._runtime:
                self._runtime.interrupt(); await self._runtime.flush()
        await self.push_frame(frame, direction)

    async def _handle_tts_audio(self, frame: TTSAudioRawFrame):
        if not self._runtime:
            try: await self._initialize_runtime()
            except Exception: logger.exception("Lazy runtime init failed"); return
        if not self._runtime: return
        audio = _to_int16_bytes(frame.audio, frame.sample_rate, self._sample_rate)
        if not audio: return
        self._in_dur += len(audio) / 2 / self._sample_rate
        self._cancel_flush()
        await self._runtime.push_audio(audio, sample_rate=self._sample_rate, last_chunk=False)

    def _cancel_flush(self):
        if self._flush_task and not self._flush_task.done(): self._flush_task.cancel()

    async def _delayed_flush(self):
        try:
            await self._runtime.push_audio(
                b"\x00" * 320, sample_rate=self._sample_rate, last_chunk=True)
            deadline = time.monotonic() + max(self._flush_delay * 2, 2.0)
            while time.monotonic() < deadline:
                if self._in_dur > 0 and self._out_dur / self._in_dur >= 0.95: break
                await asyncio.sleep(0.05)
            await self._runtime.flush()
        except asyncio.CancelledError: pass
        except Exception: logger.exception("Flush error")

    async def _render_loop(self):
        try:
            async for f in self._runtime.run():
                if not self._running: break
                if f.bgr_image is not None:
                    rgb = cv2.cvtColor(f.bgr_image, cv2.COLOR_BGR2RGB)
                    if not rgb.flags["C_CONTIGUOUS"]: rgb = np.ascontiguousarray(rgb)
                    await self.push_frame(OutputImageRawFrame(
                        image=rgb, size=(rgb.shape[1], rgb.shape[0]), format="RGB"))
                if f.audio_chunk is not None:
                    ab = f.audio_chunk.bytes
                    if not isinstance(ab, bytes):
                        a = f.audio_chunk.array
                        ab = (a if a.dtype == np.int16 else (a * 32767).astype(np.int16)).tobytes()
                    self._out_dur += f.audio_chunk.duration
                    await self.push_frame(OutputAudioRawFrame(
                        audio=ab, sample_rate=f.audio_chunk.sample_rate, num_channels=1))
        except asyncio.CancelledError: pass
        except Exception: logger.exception("Render loop error")

    @property
    def frame_size(self): return self._frame_size
    @property
    def sample_rate(self): return self._sample_rate


# -- Main -----------------------------------------------------------------------

def generate_livekit_token(key: str, secret: str, room: str, identity: str = "bithuman-agent") -> str:
    return (api.AccessToken(api_key=key, api_secret=secret)
            .with_identity(identity).with_name("bitHuman Avatar")
            .with_grants(api.VideoGrants(room_join=True, room=room,
                                         can_publish=True, can_subscribe=True)).to_jwt())

async def main(args: argparse.Namespace):
    model_path = os.getenv("BITHUMAN_MODEL_PATH") or args.model_path
    api_secret = os.getenv("BITHUMAN_API_SECRET") or args.api_secret
    lk_url, lk_key, lk_secret = os.getenv("LIVEKIT_URL"), os.getenv("LIVEKIT_API_KEY"), os.getenv("LIVEKIT_API_SECRET")
    oai_key, dg_key = os.getenv("OPENAI_API_KEY"), os.getenv("DEEPGRAM_API_KEY")
    for n, v in [("BITHUMAN_MODEL_PATH", model_path), ("BITHUMAN_API_SECRET", api_secret),
                 ("LIVEKIT_URL", lk_url), ("LIVEKIT_API_KEY", lk_key), ("LIVEKIT_API_SECRET", lk_secret),
                 ("OPENAI_API_KEY", oai_key), ("DEEPGRAM_API_KEY", dg_key)]:
        if not v: raise ValueError(f"{n} is required")

    room_name = args.room_name or f"bithuman-room-{int(time.time())}"

    # Init bitHuman runtime first to discover actual frame size.
    avatar = BitHumanAvatarProcessor(model_path=model_path, api_secret=api_secret)
    await avatar._initialize_runtime()
    w, h = avatar.frame_size

    transport = LiveKitTransport(
        url=lk_url, token=generate_livekit_token(lk_key, lk_secret, room_name),
        room_name=room_name,
        params=LiveKitParams(audio_in_enabled=True, audio_out_enabled=True,
            video_out_enabled=True, video_out_width=w, video_out_height=h, video_out_fps=25))
    stt = DeepgramSTTService(api_key=dg_key, model="nova-2", language="en")
    llm = OpenAILLMService(api_key=oai_key, model="gpt-4o-mini")
    tts = OpenAITTSService(api_key=oai_key, voice="alloy")
    context = OpenAILLMContext(messages=[{"role": "system",
        "content": "You are a helpful AI assistant with a visual avatar. Respond naturally and concisely."}])
    ctx = llm.create_context_aggregator(context)

    pipeline = Pipeline([transport.input(), stt, ctx.user(), llm, tts,
                         avatar, transport.output(), ctx.assistant()])
    task = PipelineTask(pipeline, params=PipelineParams(allow_interruptions=True, enable_metrics=True))

    @transport.event_handler("on_first_participant_joined")
    async def _(transport, pid):
        await task.queue_frames([TextFrame(text="Hello! I'm your AI assistant. How can I help you?")])

    logger.info("Agent ready — room: %s", room_name)
    await PipelineRunner().run(task)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="bitHuman Avatar Agent (Pipecat + LiveKit)")
    p.add_argument("--room-name", type=str, help="LiveKit room name")
    p.add_argument("--model-path", type=str, help="Path to .imx model file")
    p.add_argument("--api-secret", type=str, help="bitHuman API secret")
    p.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = p.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)
    asyncio.run(main(args))
