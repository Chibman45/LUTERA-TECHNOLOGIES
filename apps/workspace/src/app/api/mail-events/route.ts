import { createHmac, timingSafeEqual } from "node:crypto";
import { job } from "@/lib/business-mail";
export const runtime = "nodejs";
export async function POST(request: Request) {
  const secret = process.env.BUSINESS_MAIL_WEBHOOK_SECRET || "",
    id = request.headers.get("svix-id") || "",
    timestamp = request.headers.get("svix-timestamp") || "",
    signature = request.headers.get("svix-signature") || "";
  if (
    !secret ||
    !id ||
    !/^[0-9]{10,12}$/.test(timestamp) ||
    Math.abs(Date.now() / 1000 - Number(timestamp)) > 300 ||
    Number(request.headers.get("content-length") || 0) > 20000
  )
    return new Response(null, { status: 401 });
  const reader = request.body?.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  if (reader)
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 20000) {
        await reader.cancel();
        return new Response(null, { status: 413 });
      }
      chunks.push(value);
    }
  const raw = Buffer.concat(chunks).toString("utf8");
  const expected = createHmac(
    "sha256",
    Buffer.from(secret.replace(/^whsec_/, ""), "base64"),
  )
    .update(id + "." + timestamp + "." + raw)
    .digest();
  const valid = signature.split(" ").some((s) => {
    const value = s.startsWith("v1,")
      ? Buffer.from(s.slice(3), "base64")
      : Buffer.alloc(0);
    return value.length === expected.length && timingSafeEqual(value, expected);
  });
  if (!valid) return new Response(null, { status: 401 });
  try {
    const event = JSON.parse(raw);
    if (
      ![
        "email.delivered",
        "email.bounced",
        "email.complained",
        "email.failed",
      ].includes(event.type)
    )
      return new Response(null, { status: 204 });
    await job({
      action: "event",
      event_id: id,
      type: event.type,
      provider_id: String(event.data?.email_id || ""),
    });
    return new Response(null, { status: 204 });
  } catch {
    return new Response(null, { status: 503 });
  }
}
