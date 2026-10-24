"use client";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { mayLeave } from "@/lib/unsaved";
export default function WorkspaceShell({
  tabs,
  active,
  onSelect,
  email,
  role,
  busy,
  onSignout,
  children,
}: {
  tabs: string[][];
  active: string;
  onSelect: (area: string) => void;
  email: string;
  role: string;
  busy: boolean;
  onSignout: () => void;
  children: ReactNode;
}) {
  const [desktopOpen, setDesktopOpen] = useState(true),
    [mobileOpen, setMobileOpen] = useState(false),
    [mobile, setMobile] = useState(false),
    [search, setSearch] = useState("");
  const toggle = useRef<HTMLButtonElement>(null),
    navigation = useRef<HTMLElement>(null);
  useEffect(() => {
    const media = matchMedia("(max-width: 767px)");
    const change = () => {
      setMobile(media.matches);
      setMobileOpen(false);
    };
    change();
    media.addEventListener("change", change);
    try {
      setDesktopOpen(
        localStorage.getItem("lutera.workspace.sidebar.v1") !== "closed",
      );
    } catch {}
    return () => media.removeEventListener("change", change);
  }, []);
  useEffect(() => {
    if (!mobileOpen) return;
    navigation.current?.querySelector<HTMLInputElement>("input")?.focus();
    const escape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setMobileOpen(false);
        toggle.current?.focus();
      }
    };
    const outside = (e: PointerEvent) => {
      if (
        !navigation.current?.contains(e.target as Node) &&
        !toggle.current?.contains(e.target as Node)
      )
        setMobileOpen(false);
    };
    document.addEventListener("keydown", escape);
    document.addEventListener("pointerdown", outside);
    return () => {
      document.removeEventListener("keydown", escape);
      document.removeEventListener("pointerdown", outside);
    };
  }, [mobileOpen]);
  const open = mobile ? mobileOpen : desktopOpen;
  return (
    <div
      className="workspace"
      data-sidebar-open={desktopOpen}
      data-mobile-menu={mobileOpen}
    >
      <a className="workspace-skip" href="#workspace-main">
        Skip to workspace content
      </a>
      <header className="topbar">
        <button
          ref={toggle}
          className="secondary workspace-menu"
          type="button"
          aria-controls="workspace-navigation"
          aria-expanded={open}
          aria-label={open ? "Close workspace menu" : "Open workspace menu"}
          onClick={() => {
            if (mobile) setMobileOpen(!mobileOpen);
            else {
              setDesktopOpen(!desktopOpen);
              try {
                localStorage.setItem(
                  "lutera.workspace.sidebar.v1",
                  desktopOpen ? "closed" : "open",
                );
              } catch {}
            }
          }}
        >
          <svg
            viewBox="0 0 24 24"
            width="22"
            height="22"
            aria-hidden="true"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
          >
            {open ? (
              <path d="m6 6 12 12M18 6 6 18" />
            ) : (
              <path d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
        <img
          src="/brand/lutera-horizontal-light.svg"
          alt="Lutera"
          width="140"
          height="40"
        />
        <span className="private-label">Business workspace</span>
        <div className="account">
          <span className="account-email" title={email}>
            {email}
            <small>{role}</small>
          </span>
          <button className="secondary" onClick={onSignout} disabled={busy}>
            Sign out
          </button>
        </div>
      </header>
      <div className="workspace-grid">
        <aside
          ref={navigation}
          id="workspace-navigation"
          className="workspace-sidebar"
          aria-label="Workspace navigation"
        >
          <label className="field nav-search">
            <span>Find a section</span>
            <input
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search menu"
            />
          </label>
          <nav aria-label="Workspace sections">
            {tabs
              .filter(([, label]) =>
                label.toLowerCase().includes(search.toLowerCase()),
              )
              .map(([area, label]) => (
                <button
                  key={area}
                  aria-current={active === area ? "page" : undefined}
                  onClick={() => {
                    if (area !== active && !mayLeave()) return;
                    onSelect(area);
                    setSearch("");
                    setMobileOpen(false);
                    if (mobile)
                      requestAnimationFrame(() =>
                        document.getElementById("workspace-main")?.focus(),
                      );
                  }}
                >
                  {label}
                  <span aria-hidden="true">{active === area ? "•" : "›"}</span>
                </button>
              ))}
          </nav>
          {!tabs.some(([, label]) =>
            label.toLowerCase().includes(search.toLowerCase()),
          ) && <p role="status">No sections match your search.</p>}
          <a href="https://luteratech.com" target="_blank" rel="noreferrer">
            View public website ↗
          </a>
          <p className="sidebar-footnote">
            Private records. Approved access only.
          </p>
        </aside>
        {children}
      </div>
    </div>
  );
}
