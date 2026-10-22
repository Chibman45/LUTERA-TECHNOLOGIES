import {
  randomBytes,
  scrypt as derive,
  createCipheriv,
  createDecipheriv,
} from "node:crypto";
const keyFor = (password: string, salt: Buffer) =>
  new Promise<Buffer>((resolve, reject) =>
    derive(
      password,
      salt,
      32,
      { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 },
      (error, key) => (error ? reject(error) : resolve(key)),
    ),
  );
export async function encryptBackup(payload: unknown, password: string) {
  if (password.length < 16 || password.length > 256)
    throw new Error("Use a backup password of 16–256 characters");
  const salt = randomBytes(16),
    iv = randomBytes(12),
    key = await keyFor(password, salt);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const data = Buffer.concat([
    cipher.update(JSON.stringify(payload), "utf8"),
    cipher.final(),
  ]);
  return Buffer.from(
    JSON.stringify({
      format: "lutera-backup-v1",
      kdf: "scrypt-N32768-r8-p1",
      salt: salt.toString("base64"),
      iv: iv.toString("base64"),
      tag: cipher.getAuthTag().toString("base64"),
      data: data.toString("base64"),
    }),
  );
}
export async function decryptBackup(encrypted: Buffer, password: string) {
  const body = JSON.parse(encrypted.toString("utf8"));
  if (body.format !== "lutera-backup-v1" || body.kdf !== "scrypt-N32768-r8-p1")
    throw new Error("Unsupported backup");
  const key = await keyFor(password, Buffer.from(body.salt, "base64"));
  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(body.iv, "base64"),
  );
  decipher.setAuthTag(Buffer.from(body.tag, "base64"));
  return JSON.parse(
    Buffer.concat([
      decipher.update(Buffer.from(body.data, "base64")),
      decipher.final(),
    ]).toString("utf8"),
  );
}
