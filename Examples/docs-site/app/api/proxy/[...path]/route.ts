import { NextRequest, NextResponse } from "next/server";

const API_BASE = "https://api.bithuman.ai";

async function handler(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const targetPath = "/" + path.join("/");
  const url = new URL(req.url);
  const qs = url.search;
  const targetUrl = `${API_BASE}${targetPath}${qs}`;

  const headers = new Headers();
  const apiSecret = req.headers.get("api-secret");
  if (apiSecret) headers.set("api-secret", apiSecret);
  headers.set(
    "Content-Type",
    req.headers.get("Content-Type") || "application/json",
  );

  const body =
    req.method !== "GET" && req.method !== "HEAD"
      ? await req.text()
      : undefined;

  const response = await fetch(targetUrl, {
    method: req.method,
    headers,
    body,
  });

  const data = await response.text();

  return new NextResponse(data, {
    status: response.status,
    headers: {
      "Content-Type":
        response.headers.get("Content-Type") || "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

export const GET = handler;
export const POST = handler;
export const PUT = handler;
export const DELETE = handler;

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, api-secret",
    },
  });
}
