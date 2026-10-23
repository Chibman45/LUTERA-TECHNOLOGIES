import { test } from "node:test";
import assert from "node:assert/strict";
import { PDFDocument, PDFName, PDFString } from "pdf-lib";
import sharp from "sharp";
import { bankRows, parseCSV } from "../src/lib/business-csv";
import { csv, paymentSchema, commercialSchema } from "../src/lib/business";
import { normalizeEvidence } from "../src/lib/evidence";
test("bank CSV handles quoted references, negative amounts and invalid rows without creating payments", () => {
  const rows = bankRows(
    'date,amount,currency,reference\r\n2026-10-23,1200.50,NGN,"Bank, transfer"\r\n2026-10-23,-20.10,NGN,Refund',
  );
  assert.equal(rows[0].amount_minor, 120050);
  assert.equal(rows[0].reference, "Bank, transfer");
  assert.equal(rows[1].amount_minor, -2010);
  assert.throws(
    () => bankRows("date,amount,currency,reference\n2026-02-30,1,NGN,Bad"),
    /Row 2/,
  );
  assert.throws(() => parseCSV("name,name\na,b"), /unique/);
  assert.throws(() => parseCSV('name,reference\na,"unfinished'), /unclosed/);
  const output = csv(
    [{ name: '=HYPERLINK("https://example.invalid")' }],
    ["name"],
  );
  assert.match(output, /"'=HYPERLINK/);
});
test("manual payments require evidence and explicit staff confirmation", () => {
  const p = {
    customer_id: "28b3fcdf-e2f7-4d82-9000-36c6b34f96d7",
    amount_minor: 100,
    currency: "NGN",
    paid_on: "2026-10-23",
    method: "Cash",
    reference: "",
    description: "Payment",
    confirmed: true,
  };
  assert.equal(paymentSchema.safeParse(p).success, false);
  assert.equal(
    paymentSchema.safeParse({
      ...p,
      evidence_id: "f1c8be4b-ce69-40df-8861-4cce85efa345",
    }).success,
    true,
  );
  assert.equal(
    paymentSchema.safeParse({
      ...p,
      confirmed: false,
      evidence_id: "f1c8be4b-ce69-40df-8861-4cce85efa345",
    }).success,
    false,
  );
});
test("PDF evidence is reconstructed without active catalog actions or annotations", async () => {
  const source = await PDFDocument.create();
  const page = source.addPage();
  source.catalog.set(
    PDFName.of("OpenAction"),
    source.context.obj({
      S: "JavaScript",
      JS: PDFString.of('app.alert("unsafe")'),
    }),
  );
  page.node.set(
    PDFName.of("Annots"),
    source.context.obj([
      {
        Subtype: "Link",
        A: { S: "URI", URI: PDFString.of("https://example.invalid") },
      },
    ]),
  );
  const normalized = await normalizeEvidence(Buffer.from(await source.save()));
  const pdf = await PDFDocument.load(normalized.bytes);
  assert.equal(normalized.type, "application/pdf");
  assert.equal(pdf.getPageCount(), 1);
  assert.equal(pdf.catalog.has(PDFName.of("OpenAction")), false);
  assert.equal(pdf.getPage(0).node.has(PDFName.of("Annots")), false);
  await assert.rejects(() =>
    normalizeEvidence(Buffer.from("not an image or PDF")),
  );
});
test("evidence photos normalize to bounded JPEG and reject oversized input", async () => {
  const image = await sharp({
    create: { width: 2200, height: 1200, channels: 3, background: "#3456ff" },
  })
    .png()
    .toBuffer();
  const result = await normalizeEvidence(image);
  const info = await sharp(result.bytes).metadata();
  assert.equal(info.format, "jpeg");
  assert.ok(info.width! <= 1800);
  assert.equal(info.exif, undefined);
  await assert.rejects(
    () => normalizeEvidence(Buffer.alloc(1048577)),
    /under 1 MB/,
  );
});
