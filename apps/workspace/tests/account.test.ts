import test from "node:test";
import assert from "node:assert/strict";
import sharp from "sharp";
import { newPasswordSchema, passwordIssues } from "../src/lib/password";
import { profileSchema, emailChangeSchema } from "../src/lib/account-contracts";
import { normalizeAvatar } from "../src/lib/avatar";
import {
  authBuckets,
  AuthLimitError,
  enforceAuthLimit,
} from "../src/lib/rate-limit";
import type { SupabaseClient } from "@supabase/supabase-js";
test("new passwords share explicit requirements and preserve exact password bytes", () => {
  for (const v of [
    "short",
    "lowercasepassword12!",
    "UPPERCASEPASSWORD12!",
    "PasswordWithoutNumbers!",
    "PasswordWithoutSymbol12",
  ])
    assert.equal(newPasswordSchema.safeParse(v).success, false);
  const valid = "Long-Private-Passphrase-12!";
  assert.equal(newPasswordSchema.parse(valid), valid);
  assert.deepEqual(passwordIssues(valid), []);
  assert.equal(
    newPasswordSchema.safeParse("Áccented-Password-22!").success,
    true,
  );
  assert.equal(
    newPasswordSchema.safeParse("A1!" + "a".repeat(126)).success,
    false,
  );
});
test("profile and email inputs reject role changes, invalid phones, oversized images and mismatched emails", () => {
  assert.equal(
    profileSchema.safeParse({
      version: 0,
      full_name: " Test User ",
      phone: "+234 902 6276 130",
    }).success,
    true,
  );
  for (const v of [
    { version: 0, full_name: "", phone: "" },
    { version: 0, full_name: "Test", phone: "call me" },
    { version: 0, full_name: "Test", phone: "", role: "owner" },
    {
      version: 0,
      full_name: "Test",
      phone: "",
      photo: "a",
      remove_photo: true,
    },
  ])
    assert.equal(profileSchema.safeParse(v).success, false);
  assert.equal(
    emailChangeSchema.safeParse({
      email: "new@example.invalid",
      confirmation: "other@example.invalid",
    }).success,
    false,
  );
  assert.equal(
    emailChangeSchema.parse({
      email: "New@example.invalid",
      confirmation: "new@example.invalid",
    }).email,
    "new@example.invalid",
  );
});
test("avatar decoding accepts bounded image formats and normalizes metadata-free JPEG", async () => {
  const input = await sharp({
    create: { width: 80, height: 120, channels: 3, background: "#3456ff" },
  })
    .png()
    .toBuffer();
  const output = await normalizeAvatar(input.toString("base64"));
  const metadata = await sharp(output).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.ok(metadata.width! <= 512 && metadata.height! <= 512);
  assert.equal(metadata.exif, undefined);
  await assert.rejects(normalizeAvatar("!!!!"), /valid/);
  await assert.rejects(
    normalizeAvatar(
      Buffer.from(
        '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>',
      ).toString("base64"),
    ),
    /valid/,
  );
});
test("login limits trust Vercel edge IP, hash identifiers and combine IP/account quotas", () => {
  const secret = "1".repeat(64);
  const request = new Request("https://workspace.example/api/auth/signin", {
    headers: {
      "x-vercel-forwarded-for": "203.0.113.1",
      "x-forwarded-for": "198.51.100.8",
      "cf-connecting-ip": "198.51.100.9",
    },
  });
  const buckets = authBuckets(
    request,
    "auth/signin",
    "User@Example.invalid",
    secret,
    true,
  );
  assert.equal(buckets.length, 3);
  assert.ok(buckets.every((b) => /^[0-9a-f]{64}$/.test(b.key)));
  assert.equal(buckets[2].limit, 10);
  const second = authBuckets(
    new Request(request, {
      headers: {
        "x-vercel-forwarded-for": "203.0.113.1",
        "x-forwarded-for": "1.1.1.1",
      },
    }),
    "auth/signin",
    " user@example.invalid ",
    secret,
    true,
  );
  assert.deepEqual(second, buckets);
  assert.throws(
    () =>
      authBuckets(
        new Request("https://workspace.example"),
        "auth/signin",
        "x",
        secret,
        true,
      ),
    AuthLimitError,
  );
  assert.throws(
    () =>
      authBuckets(
        new Request("https://workspace.example", {
          headers: { "x-vercel-forwarded-for": "fake, 1.1.1.1" },
        }),
        "auth/signin",
        "x",
        secret,
        true,
      ),
    AuthLimitError,
  );
});
test("distributed limit denials preserve Retry-After and backend errors fail closed", async () => {
  const before = process.env.AUTH_RATE_SECRET;
  process.env.AUTH_RATE_SECRET = "1".repeat(64);
  const make = (data: unknown, error: unknown = null) =>
    ({ rpc: async () => ({ data, error }) }) as unknown as Pick<
      SupabaseClient,
      "rpc"
    >;
  try {
    await enforceAuthLimit(
      make({ allowed: true, retry_after: 0 }),
      new Request("http://localhost"),
      "auth/signin",
      "fixture@example.invalid",
    );
    await assert.rejects(
      enforceAuthLimit(
        make({ allowed: false, retry_after: 37 }),
        new Request("http://localhost"),
        "auth/signin",
        "fixture@example.invalid",
      ),
      (e: unknown) =>
        e instanceof AuthLimitError && e.status === 429 && e.retryAfter === 37,
    );
    await assert.rejects(
      enforceAuthLimit(
        make(null, { message: "INTERNAL" }),
        new Request("http://localhost"),
        "auth/signin",
        "fixture@example.invalid",
      ),
      (e: unknown) =>
        e instanceof AuthLimitError &&
        e.status === 503 &&
        !e.message.includes("INTERNAL"),
    );
  } finally {
    if (before === undefined) delete process.env.AUTH_RATE_SECRET;
    else process.env.AUTH_RATE_SECRET = before;
  }
});
