import { test } from "node:test";
import assert from "node:assert/strict";
import { PDFDocument } from "pdf-lib";
import { statementPDF, type StatementSnapshot } from "../src/lib/statement";
import { operationSchemas } from "../src/lib/operations";
import { schemas } from "../src/lib/business";
test("customer statements paginate all entries without becoming invoices", async () => {
  const s: StatementSnapshot = {
    customer: { name: "Synthetic customer" },
    currency: "NGN",
    opening_minor: 1200,
    from: "2026-01-01",
    to: "2026-10-23",
    company: {
      company: {
        name: "Lutera Technology Ltd",
        address: "Abuja",
        email: "fixture@example.invalid",
        phone: "+2340000000000",
        website: "https://luteratech.com",
      },
      currency: "NGN",
      bank_name: "",
      account_name: "",
      account_number: "",
      tax_id: "",
      document_notes: "",
    },
    events: Array.from({ length: 90 }, (_, i) => ({
      posted_on: "2026-10-23",
      kind: i % 2 ? "payment" : "invoice",
      reference: "Synthetic accounting event " + i,
      debit_minor: i % 2 ? 0 : 15000,
      credit_minor: i % 2 ? 10000 : 0,
    })),
  };
  const bytes = await statementPDF(s),
    pdf = await PDFDocument.load(bytes);
  assert.equal(pdf.getTitle(), "Lutera customer statement");
  assert.ok(pdf.getPageCount() >= 4);
  assert.ok(bytes.length > 5000);
});
test("financial corrections and acceptance requests require typed evidence and valid source identities", () => {
  assert.equal(
    operationSchemas["reverse-supplier-payment"].safeParse({
      reason: "Correction with evidence",
    }).success,
    false,
  );
  assert.equal(
    operationSchemas["cancel-quantity"].safeParse({
      line_id: crypto.randomUUID(),
      quantity: -1,
      reason: "Wrong quantity",
      evidence_id: crypto.randomUUID(),
    }).success,
    false,
  );
  assert.equal(
    operationSchemas.visit.safeParse({
      case_id: crypto.randomUUID(),
      scheduled_on: "2026-02-30",
      status: "scheduled",
    }).success,
    false,
  );
  assert.equal(
    operationSchemas["queue-statement"].safeParse({
      customer_id: crypto.randomUUID(),
      from: "",
      to: "",
      currency: "NGN",
      recipient: "not an email",
    }).success,
    false,
  );
  const c = schemas.customers.parse({
    name: "Trading name",
    legal_name: "Registered name",
    tags: "public sector, cloud",
  });
  assert.equal(c.legal_name, "Registered name");
  assert.equal(
    schemas.enquiries.safeParse({
      name: "Contact",
      subject: "Project",
      priority: "super-high",
    }).success,
    false,
  );
});
import { createServer } from "node:net";
import { scanEvidence } from "../src/lib/evidence-scan";
test("configured attachment scanner blocks rejected files and does not silently bypass a failed scan", async () => {
  const run = async (reply: string) => {
    const server = createServer((socket) =>
      socket.once("data", () => socket.write(reply)),
    );
    await new Promise<void>((resolve) =>
      server.listen(0, "127.0.0.1", resolve),
    );
    const address = server.address();
    assert.ok(address && typeof address === "object");
    try {
      return await scanEvidence(Buffer.from("synthetic upload"), {
        host: "127.0.0.1",
        port: String(address.port),
        tls: "false",
      });
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  };
  assert.deepEqual(await run("stream: OK\0"), { configured: true });
  await assert.rejects(run("stream: Test-Signature FOUND\0"), /did not pass/);
  assert.deepEqual(
    await scanEvidence(Buffer.from("fixture"), {
      host: undefined,
      port: undefined,
      tls: undefined,
    }),
    { configured: false },
  );
});
