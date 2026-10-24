/** Isolated, real Storage API byte round trip. Never connects to cloud Supabase. */
import { execFileSync } from "node:child_process";
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash, createHmac, randomBytes, randomUUID } from "node:crypto";
import assert from "node:assert/strict";
import sharp from "sharp";
import { encryptBackup, decryptBackup } from "../src/lib/backup";
import { recoverySQL } from "../scripts/restore-business";
const tag = "lutera-recovery-" + randomBytes(4).toString("hex"),
  network = tag,
  dir = mkdtempSync(path.join(tmpdir(), tag)),
  containers: string[] = [];
const run = (args: string[], input?: string) =>
  execFileSync("docker", args, {
    input,
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
    maxBuffer: 32 * 1024 * 1024,
  });
const secret = randomBytes(32).toString("hex"),
  password = randomBytes(24).toString("hex");
const jwt = (role: string) => {
  const h = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString(
      "base64url",
    ),
    p = Buffer.from(
      JSON.stringify({
        role,
        iss: "supabase",
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600,
      }),
    ).toString("base64url");
  return (
    h +
    "." +
    p +
    "." +
    createHmac("sha256", secret)
      .update(h + "." + p)
      .digest("base64url")
  );
};
const service = jwt("service_role"),
  anon = jwt("anon");
const sql = (db: string, query: string) =>
  run(
    [
      "exec",
      "-i",
      db,
      "psql",
      "-U",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
      "-At",
    ],
    query,
  );
const wait = async (test: () => Promise<boolean>, label: string) => {
  for (let i = 0; i < 60; i++) {
    if (await test()) return;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(label + " did not become ready");
};
async function storage(
  base: string,
  bucket: string,
  file: string,
  method = "GET",
  body?: Buffer,
  worker = false,
) {
  assert.match(base, /^http:\/\/127\.0\.0\.1:\d+$/);
  return fetch(base + "/object/" + bucket + "/" + file, {
    method,
    headers: {
      Authorization: "Bearer " + (worker ? anon : service),
      ...(worker ? { "x-lutera-backup-proof": "b".repeat(64) } : {}),
      ...(body ? { "Content-Type": "image/jpeg", "x-upsert": "true" } : {}),
    },
    body: body ? new Uint8Array(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
}
async function stack(part: string) {
  const db = tag + "-" + part + "-db",
    api = tag + "-" + part + "-storage";
  containers.push(db, api);
  const pgEnv = path.join(dir, part + "-pg.env");
  writeFileSync(pgEnv, "POSTGRES_PASSWORD=" + password + "\n", { mode: 0o600 });
  run([
    "run",
    "-d",
    "--name",
    db,
    "--network",
    network,
    "--tmpfs",
    "/var/lib/postgresql/data:rw,size=256m",
    "--env-file",
    pgEnv,
    "postgres:17-alpine",
  ]);
  await wait(async () => {
    try {
      return run(["exec", db, "pg_isready", "-U", "postgres"]).includes(
        "accepting",
      );
    } catch {
      return false;
    }
  }, "Isolated database");
  const auth = readFileSync("tests/database-auth-stub.sql", "utf8").split(
    "create schema storage;",
  )[0];
  sql(
    db,
    auth +
      "\ncreate function public.rls_auto_enable() returns event_trigger language plpgsql as $$begin return;end$$; create role service_role nologin bypassrls;grant anon,authenticated,service_role to postgres;\n",
  );
  const env = path.join(dir, part + "-storage.env");
  writeFileSync(
    env,
    [
      "ANON_KEY=" + anon,
      "SERVICE_KEY=" + service,
      "PGRST_JWT_SECRET=" + secret,
      "AUTH_JWT_SECRET=" + secret,
      "JWT_SECRET=" + secret,
      "DATABASE_URL=postgres://postgres:" +
        password +
        "@" +
        db +
        ":5432/postgres",
      "POSTGREST_URL=http://127.0.0.1:3000",
      "STORAGE_BACKEND=file",
      "FILE_STORAGE_BACKEND_PATH=/var/lib/storage",
      "FILE_SIZE_LIMIT=1048576",
      "TENANT_ID=stub",
      "REGION=local",
      "GLOBAL_S3_BUCKET=stub",
      "ENABLE_IMAGE_TRANSFORMATION=false",
    ].join("\n"),
    { mode: 0o600 },
  );
  run([
    "run",
    "-d",
    "--name",
    api,
    "--network",
    network,
    "--tmpfs",
    "/var/lib/storage:rw,mode=1777,size=64m",
    "-p",
    "127.0.0.1::5000",
    "--env-file",
    env,
    "public.ecr.aws/supabase/storage-api:v1.82.1",
  ]);
  const port = run(["port", api, "5000/tcp"]).trim().split(":").at(-1),
    base = "http://127.0.0.1:" + port;
  await wait(async () => {
    try {
      return (
        await fetch(base + "/status", { signal: AbortSignal.timeout(1000) })
      ).ok;
    } catch {
      return false;
    }
  }, "Isolated Storage API");
  sql(
    db,
    "grant usage on schema storage to anon,authenticated,service_role;grant all on all tables in schema storage to service_role;grant select,insert,update,delete on storage.objects to anon,authenticated;",
  );
  const migrationFiles = execFileSync(
    "bash",
    ["-lc", "printf '%s\\n' supabase/migrations/*.sql"],
    { encoding: "utf8" },
  )
    .trim()
    .split("\n");
  for (const file of migrationFiles) sql(db, readFileSync(file, "utf8"));
  return { db, base };
}
async function main() {
  run(["network", "create", network]);
  const source = await stack("source"),
    target = await stack("target"),
    uid = randomUUID(),
    fid = randomUUID(),
    factor = randomUUID(),
    session = randomUUID();
  const image = await sharp({
      create: { width: 40, height: 40, channels: 3, background: "#3456ff" },
    })
      .jpeg()
      .toBuffer(),
    hash = createHash("sha256").update(image).digest("hex"),
    name = uid + "/" + fid + ".jpg";
  const identities = `insert into auth.users(id,email,email_confirmed_at) values('${uid}','recovery-fixture@example.invalid',now());`;
  sql(
    source.db,
    identities +
      `insert into auth.mfa_factors(id,user_id,factor_type,status,secret,created_at,updated_at) values('${factor}','${uid}','totp','verified','FIXTURE',now(),now());insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('${session}','${uid}','${factor}','aal2',now(),now());select set_config('request.jwt.claims','{"sub":"${uid}","aal":"aal2","session_id":"${session}"}',false);insert into public.work_members(email,user_id,role) values('recovery-fixture@example.invalid','${uid}','owner');insert into private.work_job_config(id,proof_hash) values(1,encode(sha256(convert_to(repeat('b',64),'UTF8')),'hex')) on conflict(id) do update set proof_hash=excluded.proof_hash;insert into public.work_files(id,owner_id,area,name,path,content_type,size,sha256) values('${fid}','${uid}','finance','Recovery fixture','${name}','image/jpeg',${image.length},'${hash}');`,
  );
  for (const bucket of ["work-evidence", "work-staff", "work-avatars"]) {
    const response = await storage(source.base, bucket, name, "POST", image);
    assert.ok(response.ok, "Source file upload failed: " + response.status);
  }
  const output = sql(
      source.db,
      "select private.work_backup_job(repeat('b',64),'{\"action\":\"begin\"}')",
    ),
    record = JSON.parse(output.trim().split("\n").at(-1)!);
  const files = [];
  for (const f of record.files) {
    const response = await storage(
      source.base,
      f.bucket,
      f.path,
      "GET",
      undefined,
      true,
    );
    assert.ok(response.ok, "Worker file read failed: " + response.status);
    const data = Buffer.from(await response.arrayBuffer());
    files.push({
      ...f,
      data: data.toString("base64"),
      sha256: createHash("sha256").update(data).digest("hex"),
    });
  }
  assert.equal(files.length, 3);
  const encrypted = await encryptBackup(
      { ...record.snapshot, storage_files: files },
      password,
    ),
    snapshot = await decryptBackup(encrypted, password);
  sql(
    target.db,
    identities +
      "select set_config('lutera.isolated_restore','confirmed',false);\n" +
      recoverySQL(snapshot),
  );
  for (const f of snapshot.storage_files) {
    const bytes = Buffer.from(f.data, "base64"),
      uploaded = await storage(target.base, f.bucket, f.path, "POST", bytes);
    assert.ok(uploaded.ok, "Restore upload failed: " + uploaded.status);
    const restored = await storage(target.base, f.bucket, f.path);
    assert.ok(restored.ok);
    assert.equal(
      createHash("sha256")
        .update(Buffer.from(await restored.arrayBuffer()))
        .digest("hex"),
      f.sha256,
    );
    const denied = await fetch(
      target.base + "/object/authenticated/" + f.bucket + "/" + f.path,
      { headers: { Authorization: "Bearer " + anon } },
    );
    assert.ok(
      [400, 401, 403, 404].includes(denied.status),
      "Anonymous restored-file read was not denied",
    );
  }
  assert.equal(
    sql(
      target.db,
      "select count(*) from public.work_members where active",
    ).trim(),
    "0",
  );
  console.log(
    "PASS: real private Storage API byte recovery across two isolated databases; encrypted snapshot, three buckets, SHA-256 round trip, disabled restored access and anonymous download denial.",
  );
}
main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : "Storage recovery failed");
    process.exitCode = 1;
  })
  .finally(() => {
    for (const name of containers.reverse())
      try {
        run(["rm", "-f", "-v", name]);
      } catch {}
    try {
      run(["network", "rm", network]);
    } catch {}
    rmSync(dir, { recursive: true, force: true });
  });
