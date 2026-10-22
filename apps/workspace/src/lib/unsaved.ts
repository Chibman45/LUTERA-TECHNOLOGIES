"use client";
import { useEffect } from "react";
export function useUnsavedChanges(dirty: boolean) {
  useEffect(() => {
    if (!dirty) return;
    const navigation = (event: Event) => event.preventDefault();
    const unload = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("lutera-before-navigation", navigation);
    window.addEventListener("beforeunload", unload);
    return () => {
      window.removeEventListener("lutera-before-navigation", navigation);
      window.removeEventListener("beforeunload", unload);
    };
  }, [dirty]);
}
export function mayLeave() {
  return (
    window.dispatchEvent(
      new Event("lutera-before-navigation", { cancelable: true }),
    ) || window.confirm("Discard unsaved changes?")
  );
}
