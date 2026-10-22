"use client";
import { useEffect, useRef } from "react";
export function useUnsavedChanges(dirty: boolean) {
  const current = useRef(dirty);
  current.current = dirty;
  useEffect(() => {
    const navigation = (event: Event) => {
      if (current.current) event.preventDefault();
    };
    const unload = (event: BeforeUnloadEvent) => {
      if (current.current) event.preventDefault();
    };
    window.addEventListener("lutera-before-navigation", navigation);
    window.addEventListener("beforeunload", unload);
    return () => {
      window.removeEventListener("lutera-before-navigation", navigation);
      window.removeEventListener("beforeunload", unload);
    };
  }, []);
  return () => {
    current.current = false;
  };
}
export function mayLeave() {
  return (
    window.dispatchEvent(
      new Event("lutera-before-navigation", { cancelable: true }),
    ) || window.confirm("Discard unsaved changes?")
  );
}
