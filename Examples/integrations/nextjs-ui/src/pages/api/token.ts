import { NextApiRequest, NextApiResponse } from "next";
import { AccessToken, AgentDispatchClient, RoomServiceClient, VideoGrant } from "livekit-server-sdk";

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;
// LIVEKIT_API_URL = server-side HTTP URL for LiveKit API (room creation, agent dispatch)
// Separate from LIVEKIT_URL which is the client-side WebSocket URL (ws://...)
const livekitUrl = process.env.LIVEKIT_API_URL || process.env.LIVEKIT_URL || "http://localhost:17880";

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

    // Extract basic parameters
    const roomName = (req.query.roomName as string) || "default-room";
    const identity = (req.query.participantName as string) || `user-${Math.random().toString(36).substring(7)}`;

    console.log('[token-api] Generating token for:', { roomName, identity });

    // Ensure the room exists and has an agent dispatched.
    // Retry once if LiveKit isn't ready yet (startup race condition).
    const roomService = new RoomServiceClient(livekitUrl, apiKey, apiSecret);
    const agentDispatch = new AgentDispatchClient(livekitUrl, apiKey, apiSecret);

    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        await roomService.createRoom({ name: roomName });
        await agentDispatch.createDispatch(roomName, "");
        console.log('[token-api] Room created with agent dispatch');
        break;
      } catch (e) {
        const msg = (e as Error).message?.substring(0, 100) || '';
        if (attempt === 0 && msg.includes('fetch failed')) {
          console.log('[token-api] LiveKit not ready, retrying in 2s...');
          await new Promise(r => setTimeout(r, 2000));
        } else {
          // Room may already exist or dispatch already active — that's fine
          console.log('[token-api] Room/dispatch setup:', msg);
          break;
        }
      }
    }

    const grant: VideoGrant = {
      room: roomName,
      roomJoin: true,
      roomCreate: true,
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    // Create AccessToken with proper expiration
    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name: identity,
      ttl: 3600, // Token valid for 1 hour
    });

    at.addGrant(grant);
    const token = await at.toJwt();

    console.log('[token-api] Token generated successfully');

    res.status(200).json({
      accessToken: token,
      url: process.env.NEXT_PUBLIC_LIVEKIT_URL || ""
    });
  } catch (e) {
    console.error('[token-api] Error generating token:', e);
    res.statusMessage = (e as Error).message;
    res.status(500).end();
  }
}
