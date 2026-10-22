type OriginConfiguration = {
  WORKSPACE_ORIGIN?: string;
  VERCEL_ENV?: string;
  VERCEL_PROJECT_PRODUCTION_URL?: string;
};

export function workspaceOrigin(
  configuration: OriginConfiguration = {
    WORKSPACE_ORIGIN: process.env.WORKSPACE_ORIGIN,
    VERCEL_ENV: process.env.VERCEL_ENV,
    VERCEL_PROJECT_PRODUCTION_URL: process.env.VERCEL_PROJECT_PRODUCTION_URL,
  },
) {
  const value =
    configuration.WORKSPACE_ORIGIN ||
    (configuration.VERCEL_ENV === "production" &&
    configuration.VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${configuration.VERCEL_PROJECT_PRODUCTION_URL}`
      : "");
  if (!value) throw new Error("Workspace origin is not configured");
  const url = new URL(value);
  const local = ["127.0.0.1", "localhost", "[::1]"].includes(url.hostname);
  if (
    (url.protocol !== "https:" && !(url.protocol === "http:" && local)) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    value !== url.origin
  ) {
    throw new Error("Use an exact HTTPS workspace origin without a path");
  }
  return url.origin;
}
