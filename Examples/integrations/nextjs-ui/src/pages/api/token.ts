import { NextApiRequest, NextApiResponse } from "next";
import { AccessToken, VideoGrant } from "livekit-server-sdk";

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;

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
    // Enable agent auto-dispatch so the livekit-agents worker gets assigned
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (at as unknown as Record<string, unknown>).roomConfig = { agents: [{ agentName: "" }] };
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