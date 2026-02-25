import { NextApiRequest, NextApiResponse } from "next";
import { AccessToken, AgentDispatchClient, RoomServiceClient, VideoGrant } from "livekit-server-sdk";

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;

// Server-side HTTP URL for LiveKit API calls (room creation, agent dispatch).
// LIVEKIT_API_URL is preferred (explicit HTTP URL for server-side use).
// Falls back to LIVEKIT_URL, but that may contain ws:// from build args — fix it.
function resolveLivekitApiUrl(): string {
  const explicit = process.env.LIVEKIT_API_URL;
  if (explicit) return explicit;

  const fallback = process.env.LIVEKIT_URL || "http://localhost:17880";
  // Fix ws:// URLs — the RoomServiceClient needs http://
  return fallback.replace(/^ws:\/\//, "http://").replace(/^wss:\/\//, "https://");
}

const livekitApiUrl = resolveLivekitApiUrl();

// Log config once at startup so debugging is immediate
console.log('[token-api] Config:', {
  LIVEKIT_API_URL: process.env.LIVEKIT_API_URL || '(not set)',
  LIVEKIT_URL: process.env.LIVEKIT_URL || '(not set)',
  resolved: livekitApiUrl,
  apiKey: apiKey ? `${apiKey.substring(0, 4)}...` : '(not set)',
});

async function ensureAgentDispatch(roomName: string): Promise<boolean> {
  const roomService = new RoomServiceClient(livekitApiUrl, apiKey!, apiSecret!);
  const agentDispatch = new AgentDispatchClient(livekitApiUrl, apiKey!, apiSecret!);

  // Retry up to 5 times with increasing delay (covers LiveKit startup)
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
        // Non-connection error (room exists, dispatch exists, etc.) — that's OK
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

    res.status(200).json({
      accessToken: token,
      url: process.env.NEXT_PUBLIC_LIVEKIT_URL || ""
    });
  } catch (e) {
    console.error('[token-api] Error:', e);
    res.statusMessage = (e as Error).message;
    res.status(500).end();
  }
}
