import { timingSafeEqual } from "node:crypto";
import { job, dispatchBusinessMail } from "@/lib/business-mail";
import { runBusinessBackup } from "@/lib/business-backup";
export const runtime = "nodejs";
export const maxDuration = 300;
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET || "",
    provided = request.headers.get("authorization") || "";
  const expected = "Bearer " + secret;
  if (
    !secret ||
    Buffer.byteLength(provided) !== Buffer.byteLength(expected) ||
    !timingSafeEqual(Buffer.from(provided), Buffer.from(expected))
  )
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  try {
    await job({ action: "prepare" });
    const messages = await dispatchBusinessMail();
    const backup = await runBusinessBackup();
    return Response.json(
      { messages, backup },
      {
        headers: { "Cache-Control": "no-store" },
      },
    );
  } catch {
    return Response.json(
      { error: "Job processing failed. Inspect integration health." },
      { status: 503 },
    );
  }
}
