import { PDFDocument, rgb } from "pdf-lib";
import fontkit from "@pdf-lib/fontkit";
import { readFile } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import type { Settings } from "./contracts";
export type StatementSnapshot = {
  customer: { name: string; address?: string; email?: string };
  currency: string;
  opening_minor: number;
  events: {
    posted_on: string;
    kind: string;
    reference: string;
    debit_minor: number;
    credit_minor: number;
  }[];
  company: Settings;
  from: string;
  to: string;
};
const amount = (n: number) =>
  new Intl.NumberFormat("en-NG", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n / 100);
export async function statementPDF(statement: StatementSnapshot) {
  const pdf = await PDFDocument.create();
  pdf.registerFontkit(fontkit);
  const font = await pdf.embedFont(
    await readFile(path.join(process.cwd(), "public/fonts/Sora-400.ttf")),
  );
  const bold = await pdf.embedFont(
    await readFile(path.join(process.cwd(), "public/fonts/Sora-600.ttf")),
  );
  const logo = await pdf.embedPng(
    await sharp(
      await readFile(
        path.join(process.cwd(), "public/brand/lutera-horizontal-light.svg"),
      ),
    )
      .resize(420)
      .png()
      .toBuffer(),
  );
  let page = pdf.addPage([595.28, 841.89]),
    y = 0,
    balance = Number(statement.opening_minor);
  const safe = (s: string) =>
    Array.from(s)
      .map((c) => {
        try {
          font.encodeText(c);
          return c;
        } catch {
          return "?";
        }
      })
      .join("");
  const draw = (text: string, x: number, size = 9, strong = false) =>
    page.drawText(safe(text), {
      x,
      y,
      size,
      font: strong ? bold : font,
      color: rgb(0.08, 0.1, 0.22),
    });
  const header = () => {
    y = 790;
    page.drawImage(logo, { x: 40, y: 785, width: 126, height: 36 });
    y = 755;
    draw("Customer statement", 40, 20, true);
    y -= 28;
    draw(statement.company.company.name, 40, 10, true);
    y -= 17;
    draw(statement.customer.name, 40, 10, true);
    y -= 17;
    draw(
      `${statement.from || "Beginning"} to ${statement.to || "Current"} | ${statement.currency}`,
      40,
    );
    y -= 30;
    draw("Date / reference", 40, 9, true);
    draw("Debit", 308, 9, true);
    draw("Credit", 397, 9, true);
    draw("Balance", 479, 9, true);
    y -= 20;
  };
  const next = () => {
    if (y < 70) {
      page = pdf.addPage([595.28, 841.89]);
      header();
    }
  };
  header();
  draw("Opening balance", 40);
  draw(amount(balance), 479);
  y -= 25;
  for (const event of statement.events) {
    balance += Number(event.debit_minor) - Number(event.credit_minor);
    next();
    draw(`${event.posted_on}  ${event.kind}`, 40);
    draw(amount(Number(event.debit_minor)), 308);
    draw(amount(Number(event.credit_minor)), 397);
    draw(amount(balance), 479);
    y -= 15;
    const reference = String(event.reference);
    for (let start = 0; start < reference.length; start += 65) {
      next();
      draw(reference.slice(start, start + 65), 40, 8);
      y -= 13;
    }
    y -= 10;
  }
  next();
  y -= 8;
  draw("Closing balance", 40, 11, true);
  draw(statement.currency + " " + amount(balance), 425, 10, true);
  for (const [i, p] of pdf.getPages().entries())
    p.drawText(
      `${statement.company.company.name} | Page ${i + 1} of ${pdf.getPageCount()}`,
      { x: 40, y: 30, font, size: 8, color: rgb(0.35, 0.38, 0.46) },
    );
  pdf.setTitle("Lutera customer statement");
  return Buffer.from(await pdf.save());
}
