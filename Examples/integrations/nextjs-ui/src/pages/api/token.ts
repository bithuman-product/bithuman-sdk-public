import { NextApiRequest, NextApiResponse } from "next";
import { AccessToken, AgentDispatchClient, RoomServiceClient, VideoGrant } from "livekit-server-sdk";

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;

// Resolve the server-side HTTP URL for LiveKit API calls.
// Priority: LIVEKIT_API_URL > auto-detect Docker > convert LIVEKIT_URL > default
function resolveLivekitApiUrl(): string {
  // 1. Explicit API URL (always wins)
  if (process.env.LIVEKIT_API_URL) return process.env.LIVEKIT_API_URL;

  // 2. Convert LIVEKIT_URL from ws:// to http:// and fix localhost for Docker
  const raw = process.env.LIVEKIT_URL || "";
  if (raw) {
    const httpUrl = raw.replace(/^ws:\/\//, "http://").replace(/^wss:\/\//, "https://");
    // Inside Docker compose, localhost won't reach other containers.
    // The LiveKit service is named "livekit" in docker-compose.yml.
    if (httpUrl.includes("localhost")) {
      return httpUrl.replace("localhost", "livekit");
    }
    return httpUrl;
  }

  // 3. Default: try Docker service name first
  return "http://livekit:17880";
}

const livekitApiUrl = resolveLivekitApiUrl();

console.log('[token-api] Config:', {
  LIVEKIT_API_URL: process.env.LIVEKIT_API_URL || '(not set)',
  LIVEKIT_URL: process.env.LIVEKIT_URL || '(not set)',
  resolved: livekitApiUrl,
  apiKey: apiKey ? `${apiKey.substring(0, 4)}...` : '(not set)',
});

async function ensureAgentDispatch(roomName: string): Promise<boolean> {
  const roomService = new RoomServiceClient(livekitApiUrl, apiKey!, apiSecret!);
  const agentDispatch = new AgentDispatchClient(livekitApiUrl, apiKey!, apiSecret!);

  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      await roomService.createRoom({ name: roomName });
      await agentDispatch.createDispatch(roomName, "");
      console.log(`[token-api] Agent dispatched to room "${roomName}" (attempt ${attempt})`);
      return true;
    } catch (e) {
      const msg = (e as Error).message || '';
      const isConnError = msg.includes('fetch failed') || msg.includes('ECONNREFUSED') || msg.includes('ENOTFOUND');
      if (isConnError && attempt < 5) {
        const delay = attempt * 2;
        console.log(`[token-api] Cannot reach LiveKit at ${livekitApiUrl} (attempt ${attempt}/5), retrying in ${delay}s...`);
        await new Promise(r => setTimeout(r, delay * 1000));
      } else if (isConnError) {
        console.error(`[token-api] FAILED: Cannot reach LiveKit at ${livekitApiUrl} after 5 attempts. Check LIVEKIT_API_URL and network.`);
        return false;
      } else {
        console.log(`[token-api] Room/dispatch note: ${msg.substring(0, 120)}`);
        return true;
      }
    }
  }
  return false;
}

export default async function handleToken(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    if (!apiKey || !apiSecret) {
      res.statusMessage = "Environment variables aren't set up correctly";
      res.status(500).end();
      return;
    }

    const roomName = (req.query.roomName as string) || "default-room";
    const identity = (req.query.participantName as string) || `user-${Math.random().toString(36).substring(7)}`;

    console.log('[token-api] Token request:', { roomName, identity });

    const dispatched = await ensureAgentDispatch(roomName);
    if (!dispatched) {
      console.error('[token-api] WARNING: Agent dispatch failed — avatar may not appear');
    }

    const grant: VideoGrant = {
      room: roomName,
      roomJoin: true,
      roomCreate: true,
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name: identity,
      ttl: 3600,
    });

    at.addGrant(grant);
    const token = await at.toJwt();

    console.log('[token-api] Token issued:', { roomName, identity, dispatched });

    // Auto-detect LiveKit URL from the browser's request host when not configured.
    // This makes the stack work on localhost AND remote VPS with zero config.
    const clientUrl = process.env.NEXT_PUBLIC_LIVEKIT_URL
      || `ws://${(req.headers.host || 'localhost').split(':')[0]}:17880`;

    res.status(200).json({
      accessToken: token,
      url: clientUrl,
    });
  } catch (e) {
    console.error('[token-api] Error:', e);
    res.statusMessage = (e as Error).message;
    res.status(500).end();
  }
}
