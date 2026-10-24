import { z } from "zod";
export const areas = [
  "sales",
  "finance",
  "procurement",
  "inventory",
  "projects",
  "support",
  "reports",
] as const;
export type Area = (typeof areas)[number];
export type Row = { id: string; version?: number; [key: string]: unknown };
export type Access = Record<
  Area,
  { read: boolean; write: boolean; approve: boolean }
>;
export const entities = [
  "customers",
  "contacts",
  "enquiries",
  "opportunities",
  "suppliers",
  "items",
  "quotes",
  "commercial",
  "payments",
  "allocations",
  "refunds",
  "cases",
  "tasks",
  "notes",
  "stock",
  "reservations",
  "assets",
  "expenses",
  "supplier_payments",
  "decisions",
  "messages",
  "bank_lines",
  "files",
  "grants",
  "documents",
  "commercial_lines",
  "offers",
  "portal_members",
  "portal_shares",
  "portal_events",
  "portal_case_shares",
] as const;
export type Entity = (typeof entities)[number];
export const currency = z.enum(["NGN", "USD", "GBP", "EUR"]);
const text = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .refine(
      (s) => !/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(s),
      "Remove unsupported control characters",
    );
const required = (max: number) => text(max).min(1);
const link = z.union([z.literal(""), z.uuid()]).default("");
const date = z.union([z.literal(""), z.iso.date()]).default("");
const email = z.union([z.literal(""), z.email().max(254)]).default("");
const amount = z.number().int().min(0).max(1e12);
const assigned = { assigned_to: link };
const party = {
  name: required(160),
  email,
  phone: text(40).default(""),
  address: text(600).default(""),
};
export const schemas = {
  customers: z
    .object({
      ...party,
      ...assigned,
      delivery_address: text(600).default(""),
      legal_name: text(200).default(""),
      tags: text(500).default(""),
      sector: text(100).default(""),
      tax_id: text(80).default(""),
      archived: z.boolean().default(false),
    })
    .strict(),
  contacts: z
    .object({
      customer_id: z.uuid(),
      name: required(160),
      email,
      phone: text(40).default(""),
      job_title: text(120).default(""),
    })
    .strict(),
  enquiries: z
    .object({
      name: required(160),
      email,
      phone: text(40).default(""),
      subject: required(200),
      message: text(6000).default(""),
      customer_id: link,
      ...assigned,
      follow_up: date,
      priority: z.enum(["low", "normal", "high", "urgent"]).default("normal"),
      next_action: text(500).default(""),
      evidence_id: link,
      services: z.array(text(100)).max(30).default([]),
      status: z
        .enum([
          "new",
          "acknowledged",
          "qualified",
          "quoting",
          "won",
          "lost",
          "closed",
        ])
        .default("new"),
      loss_reason: text(500).default(""),
    })
    .strict(),
  opportunities: z
    .object({
      customer_id: z.uuid(),
      enquiry_id: link,
      title: required(200),
      stage: z
        .enum(["qualified", "quoting", "negotiation", "won", "lost"])
        .default("qualified"),
      value_minor: amount,
      currency,
      expected_close: date,
      ...assigned,
      notes: text(4000).default(""),
    })
    .strict(),
  suppliers: z
    .object({
      ...party,
      categories: text(400).default(""),
      terms: text(3000).default(""),
      archived: z.boolean().default(false),
    })
    .strict(),
  items: z
    .object({
      sku: required(60),
      name: required(200),
      description: text(2000).default(""),
      kind: z.enum(["stock", "to_order", "service"]),
      unit: required(30),
      unit_minor: amount.max(1e11),
      currency,
      serialized: z.boolean().default(false),
      archived: z.boolean().default(false),
    })
    .strict(),
  cases: z
    .object({
      kind: z.enum(["project", "ticket", "maintenance"]),
      customer_id: z.uuid(),
      order_id: link,
      title: required(200),
      description: text(6000).default(""),
      category: text(100).default(""),
      status: z
        .enum(["open", "active", "waiting", "completed", "closed"])
        .default("open"),
      priority: z.enum(["low", "normal", "high", "urgent"]).default("normal"),
      ...assigned,
      starts_on: date,
      due_on: date,
      response_due_at: z
        .union([z.literal(""), z.iso.datetime({ offset: true })])
        .default(""),
      responded_at: z
        .union([z.literal(""), z.iso.datetime({ offset: true })])
        .default(""),
      acceptance_id: link,
      accepted_by: text(160).default(""),
    })
    .strict(),
  tasks: z
    .object({
      case_id: z.uuid(),
      title: required(200),
      description: text(3000).default(""),
      ...assigned,
      due_on: date,
      status: z.enum(["todo", "doing", "blocked", "done"]).default("todo"),
      billable: z.boolean().default(false),
      depends_on: link,
      customer_visible: z.boolean().default(false),
    })
    .strict(),
} as const;
export type Master = keyof typeof schemas;
export const commercialKinds = [
  "order",
  "invoice",
  "credit",
  "purchase",
  "rfq",
  "delivery",
] as const;
export type CommercialKind = (typeof commercialKinds)[number];
export const commercialArea = (kind: string): Area =>
  kind === "invoice" || kind === "credit"
    ? "finance"
    : kind === "purchase" || kind === "rfq"
      ? "procurement"
      : kind === "delivery"
        ? "inventory"
        : "sales";
export const lineSchema = z
  .object({
    item_id: link,
    source_line_id: link,
    task_id: link,
    description: required(400),
    quantity: z.number().int().min(1).max(1e6),
    unit_minor: amount.max(1e11),
  })
  .strict();
export const commercialSchema = z
  .object({
    kind: z.enum(commercialKinds),
    customer_id: link,
    supplier_id: link,
    source_id: link,
    quote_id: link,
    title: required(200),
    document_date: z.iso.date(),
    due_date: date,
    currency,
    discount_minor: amount,
    tax_bps: z.number().int().min(0).max(10000),
    notes: text(4000),
    lines: z.array(lineSchema).min(1).max(40),
  })
  .strict();
export const paymentSchema = z
  .object({
    customer_id: z.uuid(),
    amount_minor: amount.min(1),
    currency,
    paid_on: z.iso.date(),
    method: required(100),
    reference: text(160).default(""),
    description: required(400),
    evidence_id: z.uuid(),
    confirmed: z.literal(true),
  })
  .strict();
export const expenseSchema = z
  .object({
    project_id: link,
    purchase_id: link,
    cost_center: text(100).default(""),
    supplier_id: link,
    order_id: link,
    title: required(200),
    category: text(100),
    amount_minor: amount.min(1),
    currency,
    incurred_on: z.iso.date(),
    due_on: date,
    evidence_id: z.uuid(),
    fx_rate_micros: z.number().int().min(1).max(1e12).optional(),
    fx_date: date,
    fx_reference: text(200).default(""),
  })
  .strict();
export const listSchema = z
  .object({
    entity: z.enum(entities),
    query: text(100).default(""),
    page: z.number().int().min(0).max(100000).default(0),
    parent: link,
    owner: link,
    service: text(100).default(""),
    from: date,
    to: date,
    kind: text(30).default(""),
    status: text(30).default(""),
  })
  .strict();
export function csv(rows: Record<string, unknown>[], columns: string[]) {
  const cell = (v: unknown) => {
    if (typeof v === "number" && Number.isFinite(v)) return String(v);
    const s =
      typeof v === "object" && v !== null ? JSON.stringify(v) : String(v ?? "");
    return (
      '"' +
      (/^[\s]*[=+\-@\t\r]/.test(s) ? "'" : "") +
      s.replaceAll('"', '""') +
      '"'
    );
  };
  return (
    "\ufeff" +
    [
      columns.map(cell).join(","),
      ...rows.map((r) => columns.map((k) => cell(r[k])).join(",")),
    ].join("\r\n")
  );
}
export const businessDate = () =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Lagos",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
