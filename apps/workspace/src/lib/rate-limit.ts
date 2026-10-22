import { createHmac } from "node:crypto";
import { isIP } from "node:net";
import type { SupabaseClient } from "@supabase/supabase-js";
export class AuthLimitError extends Error {
  constructor(
    message: string,
    public status: number,
    public retryAfter = 0,
  ) {
    super(message);
  }
}
type Bucket = { key: string; limit: number; seconds: number };
export function authBuckets(
  request: Request,
  action: string,
  subject: string,
  secret: string,
  onVercel: boolean,
): Bucket[] {
  // Vercel overwrites this header at its edge. Never trust client-provided
  // Forwarded, CF-Connecting-IP or X-Real-IP as a fallback in production.
  const raw = onVercel
    ? request.headers.get("x-vercel-forwarded-for") ||
      request.headers.get("x-forwarded-for") ||
      ""
    : "127.0.0.1";
  const ip = raw.trim();
  if (onVercel && !isIP(ip))
    throw new AuthLimitError(
      "Sign-in protection could not identify this request. Please retry.",
      503,
    );
  const hash = (scope: string, value: string) =>
    createHmac("sha256", secret)
      .update(scope + "\0" + value)
      .digest("hex");
  const signin = action === "auth/signin";
  const mfa = action.startsWith("mfa/");
  const seconds = mfa ? 300 : 900;
  return [
    { key: hash("auth-ip", ip), limit: 60, seconds: 900 },
    { key: hash(action + ":ip", ip), limit: signin ? 30 : 20, seconds },
    {
      key: hash(action + ":subject", subject.trim().toLowerCase()),
      limit: signin || mfa ? 10 : 5,
      seconds,
    },
  ];
}
export async function enforceAuthLimit(
  db: Pick<SupabaseClient, "rpc">,
  request: Request,
  action: string,
  subject: string,
) {
  const secret = process.env.AUTH_RATE_SECRET || "";
  if (!/^[0-9a-f]{64}$/.test(secret))
    throw new AuthLimitError(
      "Sign-in protection is temporarily unavailable. Please retry shortly.",
      503,
    );
  const buckets = authBuckets(
    request,
    action,
    subject,
    secret,
    process.env.VERCEL === "1",
  );
  const { data, error } = await db.rpc("work_take_auth_rate", {
    proof: secret,
    buckets,
  });
  if (
    error ||
    !data ||
    typeof data.allowed !== "boolean" ||
    !Number.isInteger(data.retry_after)
  )
    throw new AuthLimitError(
      "Sign-in protection is temporarily unavailable. Please retry shortly.",
      503,
    );
  if (!data.allowed) {
    const retry = Math.min(3600, Math.max(1, data.retry_after));
    throw new AuthLimitError(
      `Too many attempts. Please try again in ${Math.ceil(retry / 60)} minute${retry > 60 ? "s" : ""}.`,
      429,
      retry,
    );
  }
}
