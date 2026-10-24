import { z } from "zod";
import { randomUUID } from "node:crypto";
import { assertOrigin } from "@/lib/contracts";
import { csv } from "@/lib/business";
import { workspaceOrigin } from "@/lib/origin";
import {
  businessIdentity,
  boundedJSON,
  checked,
  BusinessError,
} from "@/lib/business-server";
import {
  operationEntities,
  operationRequest,
  operationSchemas,
} from "@/lib/operations";
import { after } from "next/server";
import { dispatchBusinessMail } from "@/lib/business-mail";
export const runtime = "nodejs";
const ok = (data: unknown) =>
  Response.json(data, { headers: { "Cache-Control": "private, no-store" } });
function fail(e: unknown) {
  const requestId = randomUUID();
  const labels: Record<string, string> = {
    amount_minor: "Amount",
    evidence_id: "Supporting evidence",
    purchase_line_id: "Purchase line",
    customer_id: "Customer",
    quantity: "Quantity",
    scheduled_on: "Visit date",
  };
  const issue = e instanceof z.ZodError ? e.issues[0] : null;
  const field = issue ? String(issue.path.at(-1) || "Details") : "";
  const message =
    e instanceof BusinessError
      ? e.message
      : issue
        ? (labels[field] || field.replaceAll("_", " ")) + ": " + issue.message
        : "The operation could not be completed. Please retry and quote reference " +
          requestId +
          " if you need help.";
  if (!(e instanceof BusinessError) && !(e instanceof z.ZodError))
    console.error("Business operations request failed", { requestId });
  return Response.json(
    { error: message, request_id: requestId },
    {
      status: e instanceof BusinessError ? e.status : issue ? 400 : 500,
      headers: {
        "Cache-Control": "private, no-store",
        "X-Request-Id": requestId,
      },
    },
  );
}
export async function GET(
  request: Request,
  context: { params: Promise<{ action: string[] }> },
) {
  try {
    const { db } = await businessIdentity();
    const action = (await context.params).action.join("/"),
      u = new URL(request.url);
    if (action === "bank-review")
      return ok(
        checked(
          await db.rpc("work_bank_review", {
            rid: z.uuid().parse(u.searchParams.get("id")),
          }),
        ),
      );
    if (action === "portal-evidence") {
      const id = z.uuid().parse(u.searchParams.get("id"));
      const file = checked(
        await db
          .from("work_portal_evidence")
          .select("*")
          .eq("id", id)
          .eq("status", "complete")
          .single(),
      );
      const bytes = checked(
        await db.storage.from("work-portal-evidence").download(file.path),
      );
      checked(
        await db.rpc("work_log_file_read", {
          kind: "customer-evidence",
          fid: id,
        }),
      );
      return new Response(await bytes.arrayBuffer(), {
        headers: {
          "Content-Type": "application/octet-stream",
          "Content-Disposition": `attachment; filename="Lutera-acceptance-${id}.${file.content_type === "application/pdf" ? "pdf" : "jpg"}"`,
          "Cache-Control": "private, no-store",
          "X-Content-Type-Options": "nosniff",
          "Content-Security-Policy": "sandbox; default-src 'none'",
        },
      });
    }
    if (action === "list" || action === "export") {
      const entity = z
          .enum(operationEntities)
          .parse(u.searchParams.get("entity")),
        page = z.coerce
          .number()
          .int()
          .min(0)
          .max(10000)
          .parse(u.searchParams.get("page") || 0);
      const size = action === "export" ? 5000 : 30;
      let query = db
        .from("work_" + entity)
        .select("*")
        .order("created_at", { ascending: false });
      const search = (u.searchParams.get("query") || "").trim().slice(0, 100),
        fields: Record<string, string> = {
          locations: "name",
          inspections: "notes",
          stock_holds: "reason",
          order_progress: "receiver",
          order_cancellations: "reason",
          maintenance_visits: "notes",
          supplier_bank: "account_name",
          cost_allocations: "basis",
          supplier_payments: "reference",
          bank_lines: "reference",
          messages: "subject",
          cases: "title",
          acceptance_requests: "prompt",
          portal_evidence: "name",
        };
      if (search) {
        if (z.uuid().safeParse(search).success) query = query.eq("id", search);
        else if (fields[entity])
          query = query.ilike(
            fields[entity],
            "%" + search.replace(/[\\%_]/g, "\\$&") + "%",
          );
      }
      if (u.searchParams.get("from"))
        query = query.gte(
          "created_at",
          z.iso.date().parse(u.searchParams.get("from")) + "T00:00:00+01:00",
        );
      if (u.searchParams.get("to"))
        query = query.lt(
          "created_at",
          new Date(
            new Date(
              z.iso.date().parse(u.searchParams.get("to")) + "T00:00:00+01:00",
            ).getTime() + 86400000,
          ).toISOString(),
        );
      const rows = checked(await query.range(page * size, page * size + size));
      if (entity === "supplier_bank")
        for (const row of rows)
          row.account_number = "•••• " + String(row.account_number).slice(-4);
      if (action === "export") {
        if (rows.length > 5000)
          throw new BusinessError(
            "Apply a narrower date range before exporting more than 5,000 records.",
          );
        const columns = rows.length
          ? Object.keys(rows[0]).filter(
              (k) =>
                !["path", "sha256", "snapshot", "account_number"].includes(k),
            )
          : ["id"];
        return new Response(csv(rows, columns), {
          headers: {
            "Content-Type": "text/csv; charset=utf-8",
            "Content-Disposition": `attachment; filename="Lutera-${entity}.csv"`,
            "Cache-Control": "private, no-store",
          },
        });
      }
      return ok({ rows: rows.slice(0, 30), more: rows.length > 30 });
    }
    if (action === "reports")
      return ok(
        checked(
          await db.rpc("work_reports_at", {
            cutoff: z.iso.date().parse(u.searchParams.get("cutoff")),
          }),
        ),
      );
    throw new BusinessError("Not found.", 404);
  } catch (e) {
    return fail(e);
  }
}
export async function POST(
  request: Request,
  context: { params: Promise<{ action: string[] }> },
) {
  try {
    try {
      assertOrigin(request, workspaceOrigin());
    } catch {
      throw new BusinessError("Invalid request origin.", 403);
    }
    const { db } = await businessIdentity();
    if ((await context.params).action.join("/") !== "command")
      throw new BusinessError("Not found.", 404);
    const body = operationRequest.parse(await boundedJSON(request));
    const data = operationSchemas[body.action].parse(body.data);
    const result = checked(
      await db.rpc("work_operations", { c: { ...body, data } }),
    );
    if (
      body.action === "replay-message" ||
      body.action === "resume-message" ||
      body.action === "queue-statement"
    )
      after(() => dispatchBusinessMail().catch(() => {}));
    return ok(result);
  } catch (e) {
    return fail(e);
  }
}
