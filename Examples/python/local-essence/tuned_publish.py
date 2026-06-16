"""Tuned LiveKit video publish for the self-hosted bitHuman avatar.

Importing this module monkey-patches livekit-plugins-bithuman's
``AvatarRunner._publish_track`` so the avatar video track is published as a
single H264 layer (simulcast OFF) with an explicit bitrate/framerate.

Why this is needed
------------------
By default the plugin publishes with no explicit encoding, and LiveKit maps a
small (~512x512) avatar track to its "H480" preset: VP8, ~300 kbps, a 20 fps
CAP, and simulcast ON (a second encoder per session). The avatar engine renders
at 25 fps, so the default:

  * decimates to ~20 fps with judder ("laggy"), and
  * under CPU/encoder pressure drives WebRTC into encoder-overuse adaptation:
    ~1-second FROZEN frames (which render as a BLACK screen) + a 512->360
    downscale.

This is the most common cause of a self-hosted avatar that shows a black screen
/ no video, then appears but is laggy. H264 + single-layer cuts encode CPU by
~55-82% vs the VP8/simulcast default.

Usage: ``import tuned_publish`` at the top of your agent, BEFORE you call
``avatar.start(...)``. Tune via env: AVATAR_VIDEO_MAX_BITRATE (default 2000000),
AVATAR_VIDEO_MAX_FPS (default 25), AVATAR_VIDEO_SIMULCAST (default off).
"""

import logging
import os

from livekit import rtc
from livekit.agents.voice.avatar import AvatarRunner

logger = logging.getLogger("bithuman-agent")


async def _tuned_publish_track(self) -> None:
    async with self._lock:
        await self._room_connected_fut

        # audio — unchanged
        audio_track = rtc.LocalAudioTrack.create_audio_track("avatar_audio", self._audio_source)
        self._audio_publication = await self._room.local_participant.publish_track(
            audio_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE)
        )
        await self._audio_publication.wait_for_subscription()

        # video — single H264 layer, no simulcast, explicit encoding
        simulcast = os.getenv("AVATAR_VIDEO_SIMULCAST", "0").strip().lower() in ("1", "true", "yes", "on")
        max_fps = float(os.getenv("AVATAR_VIDEO_MAX_FPS", "25") or 25)
        max_bitrate = int(os.getenv("AVATAR_VIDEO_MAX_BITRATE", "2000000") or 2000000)
        logger.info("avatar video publish: H264 cap=%.0ffps bitrate=%d simulcast=%s",
                    max_fps, max_bitrate, simulcast)
        video_track = rtc.LocalVideoTrack.create_video_track("avatar_video", self._video_source)
        self._video_publication = await self._room.local_participant.publish_track(
            video_track,
            rtc.TrackPublishOptions(
                source=rtc.TrackSource.SOURCE_CAMERA,
                video_codec=rtc.VideoCodec.H264,
                simulcast=simulcast,
                video_encoding=rtc.VideoEncoding(max_bitrate=max_bitrate, max_framerate=max_fps),
            ),
        )


AvatarRunner._publish_track = _tuned_publish_track
