import { z } from "zod";
import { randomUUID } from "node:crypto";
import { after } from "next/server";
import { job, jobDatabase, dispatchBusinessMail } from "@/lib/business-mail";
import { boundedJSON, BusinessError } from "@/lib/business-server";
import { enforceAuthLimit, AuthLimitError } from "@/lib/rate-limit";
export const runtime = "nodejs";
export const maxDuration = 60;
const site = "https://luteratech.com";
const schema = z.object({
  name: z.string().trim().min(1).max(160),
  email: z.email().max(254),
  phone: z.string().trim().max(40),
  subject: z.string().trim().min(1).max(200),
  message: z.string().trim().min(10).max(12000),
  source: z.enum(["website-contact", "website-quote", "website-enquiry"]),
  services: z.array(z.string().max(100)).max(30),
  request_key: z.uuid(),
});
export async function POST(request: Request) {
  let native = false;
  try {
    if (request.headers.get("origin") !== site)
      throw new BusinessError("Request origin is not allowed.", 403);
    let raw: Record<string, unknown>;
    if (request.headers.get("content-type")?.startsWith("application/json"))
      raw = await boundedJSON(request);
    else {
      native = true;
      const declared = Number(request.headers.get("content-length") || 0);
      if (declared > 35000) throw new BusinessError("Request too large.", 413);
      const reader = request.body?.getReader();
      const parts: Uint8Array[] = [];
      let size = 0;
      if (reader)
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          size += value.length;
          if (size > 35000) {
            await reader.cancel();
            throw new BusinessError("Request too large.", 413);
          }
          parts.push(value);
        }
      raw = Object.fromEntries(
        new URLSearchParams(Buffer.concat(parts).toString("utf8")),
      );
    }
    if (raw._honey)
      throw new BusinessError(
        "The enquiry could not be accepted. Please contact us directly.",
      );
    if (
      !["on", "true", true].includes(
        raw.privacy_acknowledged as string | boolean,
      )
    )
      throw new BusinessError(
        "Read and acknowledge the privacy notice before sending.",
      );
    const isQuote = Boolean(raw.requirements || raw.contact_name),
      name = String(raw.name || raw.contact_name || ""),
      organization = String(raw.organization || raw.organization_name || "");
    const body = schema.parse({
      name,
      email: raw.email,
      phone: String(raw.phone_or_whatsapp || ""),
      subject: isQuote
        ? "Quote request: " +
          String(raw.service_category || "Technology project")
        : "Website contact enquiry",
      message: [
        organization && "Organization: " + organization,
        raw.project_type && "Business need: " + String(raw.project_type),
        String(raw.message || raw.requirements || ""),
        raw.additional_notes &&
          "Additional notes: " + String(raw.additional_notes),
        raw.equipment_list && "Equipment: " + String(raw.equipment_list),
        raw.delivery_city_or_region &&
          "Location: " + String(raw.delivery_city_or_region),
        raw.needed_by && "Preferred date: " + String(raw.needed_by),
        raw.budget_range && "Budget guidance: " + String(raw.budget_range),
        raw.quantity && "Quantity: " + String(raw.quantity),
      ]
        .filter(Boolean)
        .join("\n\n"),
      source: isQuote ? "website-quote" : "website-contact",
      services: raw.service_category ? [String(raw.service_category)] : [],
      request_key: raw.request_key || randomUUID(),
    });
    await enforceAuthLimit(
      jobDatabase(),
      request,
      "public/enquiry",
      body.email,
    );
    const result = await job({ action: "ingest", ...body });
    after(() =>
      dispatchBusinessMail()
        .then(() => {})
        .catch(() => {}),
    );
    if (native) return Response.redirect(site + "/thank-you/", 303);
    return Response.json(
      { success: true, reference: result.reference },
      {
        headers: {
          "Access-Control-Allow-Origin": site,
          "Cache-Control": "no-store",
        },
      },
    );
  } catch (error) {
    const status =
      error instanceof AuthLimitError
        ? error.status
        : error instanceof BusinessError
          ? error.status
          : 400;
    const message =
      error instanceof z.ZodError
        ? "Check your contact details and enquiry length."
        : error instanceof BusinessError || error instanceof AuthLimitError
          ? error.message
          : "Your request could not be saved. Please retry or contact us directly.";
    return Response.json(
      { error: message },
      {
        status,
        headers: {
          "Access-Control-Allow-Origin": site,
          "Cache-Control": "no-store",
          ...(error instanceof AuthLimitError && error.retryAfter
            ? { "Retry-After": String(error.retryAfter) }
            : {}),
        },
      },
    );
  }
}
export async function OPTIONS(request: Request) {
  if (request.headers.get("origin") !== site)
    return new Response(null, { status: 403 });
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": site,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "600",
    },
  });
}
