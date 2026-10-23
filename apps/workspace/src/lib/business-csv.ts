import { z } from "zod";
import { minor } from "./contracts";
import { currency } from "./business";
export function parseCSV(text: string) {
  if (text.length > 200000) throw new Error("CSV exceeds the import limit.");
  const rows: string[][] = [];
  let row: string[] = [],
    cell = "",
    quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else quoted = !quoted;
    } else if (c === "," && !quoted) {
      row.push(cell);
      cell = "";
    } else if ((c === "\n" || c === "\r") && !quoted) {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(cell);
      if (row.some((s) => s.trim())) rows.push(row);
      row = [];
      cell = "";
    } else cell += c;
  }
  if (quoted) throw new Error("CSV has an unclosed quoted field.");
  row.push(cell);
  if (row.some((s) => s.trim())) rows.push(row);
  if (rows.length < 2 || rows.length > 501)
    throw new Error("Include a header and between 1 and 500 data rows.");
  const header = rows.shift()!.map((s) =>
    s
      .replace(/^\ufeff/, "")
      .trim()
      .toLowerCase(),
  );
  if (new Set(header).size !== header.length)
    throw new Error("CSV headers must be unique.");
  return rows.map((r, i) => {
    if (r.length !== header.length)
      throw new Error(`Row ${i + 2} has the wrong number of columns.`);
    return Object.fromEntries(header.map((h, j) => [h, r[j].trim()]));
  });
}
export function bankRows(text: string) {
  return parseCSV(text).map((r, i) => {
    try {
      const raw = r.amount || "";
      const neg = raw.startsWith("-");
      const amount = minor(neg ? raw.slice(1) : raw) * (neg ? -1 : 1);
      if (!amount) throw new Error("Amount cannot be zero.");
      return {
        posted_on: z.iso.date().parse(r.date),
        amount_minor: amount,
        currency: currency.parse(r.currency),
        reference: z.string().trim().min(1).max(200).parse(r.reference),
      };
    } catch (error) {
      throw new Error(
        `Row ${i + 2}: ${error instanceof z.ZodError ? "check date, currency and reference" : (error as Error).message}`,
      );
    }
  });
}
