import { timingSafeEqual } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { boundedJSON } from "@/lib/business-server";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
function authorized(request: Request) {
  const key = process.env.DRIVE_BACKUP_SECRET;
  const token = request.headers.get("authorization") || "";
  const expected = "Bearer " + key;
  return (
    !!key &&
    Buffer.byteLength(token) === Buffer.byteLength(expected) &&
    timingSafeEqual(Buffer.from(token), Buffer.from(expected))
  );
}
function db() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_PUBLISHABLE_KEY!,
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        headers: { "x-lutera-backup-proof": process.env.BUSINESS_JOB_SECRET! },
      },
    },
  );
}
export async function GET(request: Request) {
  if (!authorized(request)) return new Response(null, { status: 401 });
  try {
    const client = db();
    const result = await client.rpc("work_backup_job", {
      proof: process.env.BUSINESS_JOB_SECRET,
      c: { action: "pending" },
    });
    if (result.error) throw new Error("Backup lookup failed");
    const backup = result.data?.[0];
    if (!backup)
      return new Response(null, {
        status: 204,
        headers: { "Cache-Control": "no-store" },
      });
    const signed = await client.storage
      .from("work-backups")
      .createSignedUrl(backup.path, 120);
    if (signed.error) throw new Error("Backup download unavailable");
    return Response.json(
      {
        id: backup.id,
        name: backup.path.split("/").at(-1),
        sha256: backup.sha256,
        url: signed.data.signedUrl,
      },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch {
    return Response.json(
      { error: "Backup copy is unavailable; the primary copy is retained." },
      { status: 503 },
    );
  }
}
export async function POST(request: Request) {
  if (!authorized(request)) return new Response(null, { status: 401 });
  try {
    const input = z
      .object({
        id: z.uuid(),
        sha256: z.string().regex(/^[a-f0-9]{64}$/),
        drive_id: z.string().regex(/^[A-Za-z0-9_-]{10,200}$/),
      })
      .strict()
      .parse(await boundedJSON(request));
    const result = await db().rpc("work_backup_job", {
      proof: process.env.BUSINESS_JOB_SECRET,
      c: { action: "offsite", ...input },
    });
    if (result.error) throw new Error("Copy receipt rejected");
    return Response.json(
      { success: true },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return Response.json(
      { error: "Copy receipt could not be recorded." },
      { status: 400 },
    );
  }
}
