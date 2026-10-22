import test from "node:test";
import assert from "node:assert/strict";
import type { SupabaseClient } from "@supabase/supabase-js";
import { completeEmailAction, emailActionSchema } from "../src/lib/auth-email";
const token_hash = "a".repeat(64);
function client(
  options: {
    expired?: boolean;
    approved?: boolean;
    confirmed?: boolean;
    session?: boolean;
    updateError?: boolean;
  } = {},
) {
  const calls: string[] = [];
  const value = {
    auth: {
      verifyOtp: async () => {
        calls.push("verify");
        return {
          error: options.expired ? { message: "INTERNAL DETAIL" } : null,
          data: { session: options.session === false ? null : {}, user: {} },
        };
      },
      getUser: async () => {
        calls.push("user");
        return {
          error: null,
          data: {
            user: {
              email_confirmed_at:
                options.confirmed === false ? null : "2026-10-22",
            },
          },
        };
      },
      signOut: async () => {
        calls.push("signout");
        return { error: null };
      },
      updateUser: async (input: { password: string }) => {
        assert.equal(input.password, "A-private-Fixture-12!");
        calls.push("password");
        return { error: options.updateError ? {} : null };
      },
    },
    rpc: async (name: string) => {
      assert.equal(name, "work_claim_membership");
      calls.push("claim");
      return {
        error:
          options.approved === false ? { message: "INTERNAL DETAIL" } : null,
      };
    },
  } as unknown as Pick<SupabaseClient, "auth" | "rpc">;
  return { value, calls };
}
test("email actions validate purpose, bounded token and invite passwords before verifying", async () => {
  const db = client();
  for (const input of [
    { token_hash, type: "other" },
    { token_hash: "short", type: "email" },
    { token_hash, type: "invite", password: "short", confirmation: "short" },
    {
      token_hash,
      type: "invite",
      password: "long-enough-password",
      confirmation: "different",
    },
    { token_hash, type: "email", next: "https://evil.example" },
    { token_hash, type: "recovery", password: "not-permitted" },
  ]) {
    assert.equal(emailActionSchema.safeParse(input).success, false);
    await assert.rejects(completeEmailAction(db.value, input));
  }
  assert.deepEqual(db.calls, []);
});
test("expired links expose no provider details and never claim access", async () => {
  const db = client({ expired: true });
  await assert.rejects(
    completeEmailAction(db.value, { token_hash, type: "email" }),
    /expired/,
  );
  assert.deepEqual(db.calls, ["verify"]);
});
test("invitation saves a password only after current verified user and approved membership", async () => {
  const db = client();
  assert.deepEqual(
    await completeEmailAction(db.value, {
      token_hash,
      type: "invite",
      password: "A-private-Fixture-12!",
      confirmation: "A-private-Fixture-12!",
    }),
    { next: "workspace" },
  );
  assert.deepEqual(db.calls, ["verify", "user", "claim", "password"]);
  const denied = client({ approved: false });
  await assert.rejects(
    completeEmailAction(denied.value, {
      token_hash,
      type: "invite",
      password: "A-private-Fixture-12!",
      confirmation: "A-private-Fixture-12!",
    }),
    /not approved/,
  );
  assert.deepEqual(denied.calls, ["verify", "user", "claim", "signout"]);
});
test("unconfirmed users and failed password saves clear the local session", async () => {
  const unconfirmed = client({ confirmed: false });
  await assert.rejects(
    completeEmailAction(unconfirmed.value, { token_hash, type: "email" }),
    /incomplete/,
  );
  assert.deepEqual(unconfirmed.calls, ["verify", "user", "signout"]);
  const failed = client({ updateError: true });
  await assert.rejects(
    completeEmailAction(failed.value, {
      token_hash,
      type: "invite",
      password: "A-private-Fixture-12!",
      confirmation: "A-private-Fixture-12!",
    }),
    /could not be saved/,
  );
  assert.equal(failed.calls.at(-1), "signout");
});
test("recovery leads to the MFA-protected password screen without changing a password", async () => {
  const db = client();
  assert.deepEqual(
    await completeEmailAction(db.value, { token_hash, type: "recovery" }),
    { next: "password" },
  );
  assert.deepEqual(db.calls, ["verify", "user", "claim"]);
});
test("first half of a secure email change does not grant a session", async () => {
  const db = client({ session: false });
  assert.deepEqual(
    await completeEmailAction(db.value, { token_hash, type: "email_change" }),
    { next: "email_pending" },
  );
  assert.deepEqual(db.calls, ["verify"]);
});
