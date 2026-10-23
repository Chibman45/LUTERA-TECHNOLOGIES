import "server-only";
import { database } from "./supabase";
export class BusinessError extends Error {
  constructor(
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}
export function checked<T>(r: {
  data: T;
  error: { message: string; code?: string } | null;
}): NonNullable<T> {
  if (r.error) {
    const m = r.error.message;
    throw new BusinessError(
      m.startsWith("BUSINESS: ")
        ? m.slice(10)
        : r.error.code === "23505"
          ? "This reference already exists. Refresh before retrying."
          : r.error.code === "23503"
            ? "A linked record was not found or is still in use."
            : "The request could not be completed. Check the entered details and your access.",
      r.error.code === "42501"
        ? 403
        : /changed|already used for different/.test(m)
          ? 409
          : 400,
    );
  }
  return r.data as NonNullable<T>;
}
export async function businessIdentity() {
  const db = await database();
  const { data, error } = await db.auth.getUser();
  if (error || !data.user) throw new BusinessError("Sign in to continue.", 401);
  checked(await db.rpc("work_claim_membership"));
  if (!checked(await db.rpc("work_has_access", { area: "session" })))
    throw new BusinessError("Complete MFA or sign in again.", 403);
  return { db, user: data.user };
}
export async function boundedJSON(request: Request) {
  const reader = request.body?.getReader();
  if (!reader) throw new BusinessError("Request body required.");
  const chunks: Uint8Array[] = [];
  let n = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    n += value.byteLength;
    if (n > 1800000) {
      await reader.cancel();
      throw new BusinessError("Upload an image under 1 MB.", 413);
    }
    chunks.push(value);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new BusinessError("Invalid JSON.");
  }
}
