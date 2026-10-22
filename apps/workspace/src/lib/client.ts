"use client";
export class ApiError extends Error {
  constructor(
    message: string,
    public status = 0,
    public retryAfter = 0,
  ) {
    super(message);
  }
}
export async function api<T = unknown>(
  action: string,
  body?: unknown,
): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`/api/${action}`, {
      method: body === undefined ? "GET" : "POST",
      headers: body === undefined ? {} : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      cache: "no-store",
    });
  } catch {
    throw new ApiError(
      "We could not connect. Check your connection and try again.",
    );
  }
  let result;
  try {
    result = await response.json();
  } catch {
    throw new ApiError(
      "The server returned an unexpected response. Please retry.",
      response.status,
    );
  }
  if (!response.ok)
    throw new ApiError(
      result.error || "The request could not be completed.",
      response.status,
      Number(response.headers.get("Retry-After")) || 0,
    );
  return result;
}
export async function saveFile(action: string, body: unknown) {
  let response: Response;
  try {
    response = await fetch(`/api/${action}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    throw new ApiError(
      "We could not connect. Check your connection and try again.",
    );
  }
  if (!response.ok) {
    const value = await response
      .json()
      .catch(() => ({ error: "Export failed. Please retry." }));
    throw new ApiError(value.error || "Export failed.", response.status);
  }
  const blob = await response.blob(),
    url = URL.createObjectURL(blob),
    a = document.createElement("a");
  a.href = url;
  a.download =
    response.headers
      .get("content-disposition")
      ?.match(/filename="([^"]+)"/)?.[1] || "lutera-export";
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
