/** Offline verification. Password enters on stdin; private records never print. */
import { readFile } from "node:fs/promises";
import { decryptBackup } from "../src/lib/backup";
async function main() {
  const file = process.argv[2];
  if (!file || process.stdin.isTTY) {
    console.error(
      "Usage: password-manager-command | npx tsx scripts/verify-backup.ts FILE.lutera-backup",
    );
    process.exit(1);
  }
  try {
    let password = "";
    for await (const chunk of process.stdin) password += chunk;
    const payload = await decryptBackup(
      await readFile(file),
      password.replace(/\r?\n$/, ""),
    );
    if (payload.format === "lutera-business-records-v2") {
      if (
        !Array.isArray(payload.work_documents) ||
        !Array.isArray(payload.storage_files) ||
        !Array.isArray(payload["private.work_counters"])
      )
        throw new Error("Incomplete business snapshot");
      const { createHash } = await import("node:crypto");
      for (const file of payload.storage_files)
        if (
          createHash("sha256")
            .update(Buffer.from(file.data, "base64"))
            .digest("hex") !== file.sha256
        )
          throw new Error("Private file checksum mismatch");
      console.log(
        JSON.stringify(
          {
            verified: true,
            created_at: payload.created_at,
            documents: payload.work_documents.length,
            payments: payload.work_payments.length,
            private_files: payload.storage_files.length,
            numbering_counters: payload["private.work_counters"].length,
          },
          null,
          2,
        ),
      );
      return;
    }
    if (
      payload.format !== "lutera-records-v1" ||
      !payload.data ||
      !payload.photos
    )
      throw new Error("Unexpected records format");
    console.log(
      JSON.stringify(
        {
          verified: true,
          created_at: payload.created_at,
          documents: payload.data.documents.length,
          staff: payload.data.staff.length,
          photos: Object.keys(payload.photos).length,
          numbering_counters: payload.data.counters.length,
        },
        null,
        2,
      ),
    );
  } catch {
    console.error(
      "Backup verification failed. Check the file and password; no data was extracted.",
    );
    process.exit(1);
  }
}
main();
