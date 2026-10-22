"use client";
import { useEffect, useState } from "react";
import { ApiError } from "./client";
export function useCooldown() {
  const [until, setUntil] = useState(0),
    [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (until <= Date.now()) return;
    const timer = setInterval(() => {const value=Date.now();setNow(value);if(value>=until)clearInterval(timer);}, 1000);
    return () => clearInterval(timer);
  }, [until]);
  const seconds = Math.max(0, Math.ceil((until - now) / 1000));
  return {
    seconds,
    handle: (error: unknown) => {
      if (error instanceof ApiError && error.status === 429) {
        setNow(Date.now());
        setUntil(Date.now() + Math.max(1, error.retryAfter || 60) * 1000);
      }
    },
  };
}
