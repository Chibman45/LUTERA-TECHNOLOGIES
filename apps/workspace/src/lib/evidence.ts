import sharp from "sharp";
import { PDFDocument, PDFName } from "pdf-lib";
export async function normalizeEvidence(bytes: Buffer) {
  if (!bytes.length || bytes.length > 1048576)
    throw new Error("Choose a document or image under 1 MB.");
  if (bytes.subarray(0, 5).toString() === "%PDF-") {
    const input = await PDFDocument.load(bytes, {
      ignoreEncryption: false,
      updateMetadata: false,
    });
    if (input.getPageCount() < 1 || input.getPageCount() > 20)
      throw new Error("Evidence PDFs may contain up to 20 pages.");
    const out = await PDFDocument.create();
    const pages = await out.copyPages(input, input.getPageIndices());
    for (const p of pages) {
      p.node.delete(PDFName.of("Annots"));
      p.node.delete(PDFName.of("AA"));
      p.node.delete(PDFName.of("AF"));
      out.addPage(p);
    }
    out.setTitle("Lutera payment or acceptance evidence");
    const buffer = Buffer.from(await out.save());
    if (buffer.length > 1048576)
      throw new Error("The prepared PDF exceeds 1 MB. Reduce its size.");
    return { bytes: buffer, type: "application/pdf", extension: "pdf" };
  }
  const input = sharp(bytes, { limitInputPixels: 16000000, animated: false });
  const info = await input.metadata();
  if (!["jpeg", "png", "webp"].includes(info.format || ""))
    throw new Error("Use a PDF, JPEG, PNG or WebP file.");
  const buffer = await input
    .rotate()
    .resize({
      width: 1800,
      height: 1800,
      fit: "inside",
      withoutEnlargement: true,
    })
    .jpeg({ quality: 90 })
    .toBuffer();
  if (buffer.length > 1048576)
    throw new Error("The prepared image exceeds 1 MB. Reduce its size.");
  return { bytes: buffer, type: "image/jpeg", extension: "jpg" };
}
