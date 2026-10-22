import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";

export const emailActionTypes = [
  "invite",
  "recovery",
  "email",
  "signup",
  "magiclink",
  "email_change",
] as const;
export const emailActionType = z.enum(emailActionTypes);
export const emailActionSchema = z
  .object({
    token_hash: z.string().regex(/^[A-Za-z0-9_-]{32,256}$/),
    type: emailActionType,
    password: z.string().max(128).optional(),
    confirmation: z.string().max(128).optional(),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      value.type === "invite" &&
      (!value.password ||
        value.password.length < 12 ||
        value.password !== value.confirmation)
    ) {
      context.addIssue({
        code: "custom",
        message: "Use matching passwords of at least 12 characters",
        path: ["password"],
      });
    }
    if (value.type !== "invite" && (value.password || value.confirmation)) {
      context.addIssue({
        code: "custom",
        message: "Passwords are not accepted for this action",
      });
    }
  });

export class EmailActionError extends Error {
  constructor(
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}

/** GET never verifies a token. Only an explicit same-origin POST calls this. */
export async function completeEmailAction(
  db: Pick<SupabaseClient, "auth" | "rpc">,
  raw: unknown,
): Promise<{ next: "workspace" | "password" | "email_pending" }> {
  const body = emailActionSchema.parse(raw);
  const verified = await db.auth.verifyOtp({
    token_hash: body.token_hash,
    type: body.type,
  });
  if (verified.error)
    throw new EmailActionError(
      "This link has expired or has already been used. Ask the company owner for a new email.",
    );
  // Secure email changes can require confirmation from both mailboxes.
  if (body.type === "email_change" && !verified.data.session)
    return { next: "email_pending" };
  const user = await db.auth.getUser();
  if (user.error || !user.data.user?.email_confirmed_at) {
    await db.auth.signOut({ scope: "local" });
    throw new EmailActionError(
      "Email confirmation is incomplete. Contact the company owner.",
      403,
    );
  }
  const claim = await db.rpc("work_claim_membership");
  if (claim.error) {
    await db.auth.signOut({ scope: "local" });
    throw new EmailActionError(
      "This account is not approved for the Lutera workspace. Contact the company owner.",
      403,
    );
  }
  if (body.type === "invite") {
    const updated = await db.auth.updateUser({ password: body.password! });
    if (updated.error) {
      await db.auth.signOut({ scope: "local" });
      throw new EmailActionError(
        "Your password could not be saved. Contact the company owner for a new invitation or recovery link.",
      );
    }
  }
  // Recovery preserves the existing MFA requirement. Password changes use the
  // existing AAL2-only endpoint and revoke all account sessions on success.
  return { next: body.type === "recovery" ? "password" : "workspace" };
}
