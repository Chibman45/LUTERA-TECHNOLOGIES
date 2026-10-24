import { z } from "zod";
const text = (n: number) => z.string().trim().max(n);
const uuid = z.uuid(),
  optionalID = z.union([uuid, z.literal("")]).default("");
const date = z.iso.date(),
  optionalDate = z.union([date, z.literal("")]).default("");
const reason = text(500).min(5),
  evidence = uuid,
  quantity = z.number().int().min(1).max(1000000);
export const operationSchemas = {
  "approval-rule": z
    .object({
      kind: z.enum(["purchase", "discount", "credit", "refund"]),
      currency: z.enum(["NGN", "USD", "GBP", "EUR"]),
      threshold_minor: z.union([
        z.literal(""),
        z.number().int().min(0).max(1e12),
      ]),
      approver_id: optionalID,
      notes: text(1000).default(""),
    })
    .strict(),
  shipment: z
    .object({
      purchase_line_id: uuid,
      quantity,
      status: z.enum([
        "planned",
        "shipped",
        "arrived",
        "delayed",
        "returned",
        "cancelled",
      ]),
      carrier: text(160).default(""),
      tracking_reference: text(200).default(""),
      shipped_on: optionalDate,
      expected_on: optionalDate,
      notes: text(2000).default(""),
      evidence_id: optionalID,
    })
    .strict(),
  "pause-clock": z.object({ reason, evidence_id: evidence }).strict(),
  "resume-clock": z.object({ reason, evidence_id: evidence }).strict(),
  "acceptance-request": z
    .object({ customer_id: uuid, share_id: uuid, prompt: text(2000).min(5) })
    .strict(),
  "withdraw-acceptance": z.object({ reason }).strict(),
  "queue-statement": z
    .object({
      customer_id: uuid,
      from: optionalDate,
      to: optionalDate,
      currency: z.enum(["NGN", "USD", "GBP", "EUR"]),
      recipient: z.email().max(254),
    })
    .strict(),
  location: z
    .object({ name: text(120).min(1), archived: z.boolean().default(false) })
    .strict(),
  inspection: z
    .object({
      purchase_id: uuid,
      line_id: optionalID,
      stage: z.enum(["pre-shipment", "receiving", "discrepancy"]),
      result: z.enum(["pending", "accepted", "rejected"]),
      quantity,
      notes: text(3000).min(5),
      evidence_id: evidence,
    })
    .strict(),
  "stock-hold": z
    .object({ movement_id: uuid, quantity, reason, evidence_id: optionalID })
    .strict(),
  "release-hold": z.object({ reason }).strict(),
  "order-progress": z
    .object({
      order_id: uuid,
      status: z.enum(["approved", "in_progress", "fulfilled", "closed"]),
      delivery_address: text(600).default(""),
      receiver: text(160).default(""),
      evidence_id: optionalID,
      reason,
    })
    .strict(),
  "cancel-quantity": z
    .object({ line_id: uuid, quantity, reason, evidence_id: evidence })
    .strict(),
  visit: z
    .object({
      case_id: uuid,
      asset_id: optionalID,
      assigned_to: optionalID,
      scheduled_on: date,
      status: z.enum(["scheduled", "completed", "cancelled"]),
      completed_on: optionalDate,
      notes: text(3000).default(""),
      evidence_id: optionalID,
    })
    .strict(),
  "supplier-bank": z
    .object({
      supplier_id: uuid,
      bank_name: text(160).min(1),
      account_name: text(200).min(1),
      account_number: text(80).min(4),
      currency: z.enum(["NGN", "USD", "GBP", "EUR"]),
      evidence_id: evidence,
      reason,
    })
    .strict(),
  "approve-bank": z
    .object({ reason, owner_exception: z.boolean().default(false) })
    .strict(),
  "cost-allocation": z
    .object({
      expense_id: uuid,
      purchase_line_id: uuid,
      amount_minor: z.number().int().min(1).max(1e12),
      basis: text(500).min(5),
    })
    .strict(),
  "reverse-supplier-payment": z
    .object({ reason, evidence_id: evidence })
    .strict(),
  "match-outgoing": z
    .object({ supplier_payment_id: optionalID, refund_id: optionalID })
    .strict(),
  "unmatch-bank": z.object({ reason }).strict(),
  "pause-message": z.object({ reason }).strict(),
  "resume-message": z.object({ reason }).strict(),
  "replay-message": z.object({ reason }).strict(),
  "cancel-message": z.object({ reason }).strict(),
  "operating-policy": z
    .object({
      financial_retention_days: z.union([
        z.literal(""),
        z.number().int().min(1).max(36500),
      ]),
      communication_retention_days: z.union([
        z.literal(""),
        z.number().int().min(1).max(36500),
      ]),
      staff_retention_days: z.union([
        z.literal(""),
        z.number().int().min(1).max(36500),
      ]),
      backup_retention_days: z.union([
        z.literal(""),
        z.number().int().min(1).max(36500),
      ]),
      recovery_point_hours: z.union([
        z.literal(""),
        z.number().int().min(1).max(168),
      ]),
      recovery_time_hours: z.union([
        z.literal(""),
        z.number().int().min(1).max(168),
      ]),
      notes: text(3000).default(""),
    })
    .strict(),
};
export const operationEntities = [
  "acceptance_requests",
  "portal_evidence",
  "cases",
  "shipments",
  "approval_rules",
  "locations",
  "inspections",
  "stock_holds",
  "order_progress",
  "order_cancellations",
  "maintenance_visits",
  "supplier_bank",
  "cost_allocations",
  "operating_policy",
  "supplier_payments",
  "bank_lines",
  "messages",
] as const;
export const operationRequest = z
  .object({
    action: z.enum(
      Object.keys(operationSchemas) as [
        keyof typeof operationSchemas,
        ...(keyof typeof operationSchemas)[],
      ],
    ),
    id: optionalID,
    version: z.number().int().min(0).default(0),
    request_key: uuid,
    data: z.record(z.string(), z.unknown()),
  })
  .strict();
