import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { workspaceOrigin } from "./origin";
export async function database() {
  const jar = await cookies();
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key || !workspaceOrigin() || !process.env.WORKSPACE_ENTRY)
    throw new Error("Workspace configuration is incomplete");
  return createServerClient(url, key, {
    cookieOptions: {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 12 * 60 * 60,
    },
    cookies: {
      getAll: () => jar.getAll(),
      setAll: (values) => {
        for (const { name, value, options } of values)
          jar.set(name, value, {
            ...options,
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "lax",
            maxAge: value ? 12 * 60 * 60 : 0,
          });
      },
    },
  });
}
