import { NextRequest, NextResponse } from "next/server";
import { workspaceOrigin } from "./lib/origin";
export function proxy(request: NextRequest) {
  if (
    process.env.VERCEL_ENV === "production" &&
    request.nextUrl.hostname.endsWith(".vercel.app")
  ) {
    const target = new URL(workspaceOrigin());
    if (target.hostname !== request.nextUrl.hostname) {
      target.pathname = request.nextUrl.pathname;
      target.search = request.nextUrl.search;
      return NextResponse.redirect(target, 308);
    }
  }
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");
  const development = process.env.NODE_ENV !== "production";
  const policy = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development ? " 'unsafe-eval'" : ""}`,
    "style-src 'self'",
    "img-src 'self' data: blob:",
    "font-src 'self'",
    `connect-src 'self'${development ? " ws: wss:" : ""}`,
    "frame-ancestors 'none'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
  ].join("; ");
  const headers = new Headers(request.headers);
  headers.set("x-nonce", nonce);
  headers.set("Content-Security-Policy", policy);
  const response = NextResponse.next({ request: { headers } });
  response.headers.set("Content-Security-Policy", policy);
  response.headers.set("Cache-Control", "private, no-store, max-age=0");
  return response;
}
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|brand/|fonts/).*)"],
};
