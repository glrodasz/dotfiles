# Theme controller

The framework-agnostic module from Phase 5 and its framework bindings. Adapt the constants
to the choices from Phase 2, and keep them identical to the boot script.

## Contents

- Controller module
- React binding
- Other frameworks

## Controller module

```ts
// theme.ts
export type ThemePreference = "light" | "dark" | "system";
export type ResolvedTheme = "light" | "dark";
export interface ThemeState {
  preference: ThemePreference;
  resolved: ResolvedTheme;
}

export const STORAGE_KEY = "theme";
export const DEFAULT_PREFERENCE: ThemePreference = "system";
export const THEME_COLOR: Record<ResolvedTheme, string> = {
  light: "#f4f6f8",
  dark: "#121212",
};
const DARK_QUERY = "(prefers-color-scheme: dark)";

const isPreference = (v: unknown): v is ThemePreference =>
  v === "light" || v === "dark" || v === "system";

function readStored(): ThemePreference {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    return isPreference(v) ? v : DEFAULT_PREFERENCE;
  } catch {
    return DEFAULT_PREFERENCE; // storage blocked (private mode, sandboxed iframe)
  }
}

function systemTheme(): ResolvedTheme {
  return typeof window !== "undefined" && window.matchMedia?.(DARK_QUERY).matches
    ? "dark"
    : "light";
}

export function resolveTheme(preference: ThemePreference): ResolvedTheme {
  return preference === "system" ? systemTheme() : preference;
}

/** Used on the server and during hydration, so SSR markup never depends on the client. */
const serverResolved = (p: ThemePreference): ResolvedTheme => (p === "dark" ? "dark" : "light");
export const SERVER_STATE: ThemeState = {
  preference: DEFAULT_PREFERENCE,
  resolved: serverResolved(DEFAULT_PREFERENCE),
};

let state: ThemeState = SERVER_STATE;
const listeners = new Set<() => void>();
let started = false;

function apply(next: ThemeState) {
  const changed =
    next.preference !== state.preference || next.resolved !== state.resolved;
  state = next; // new object only on change, so getThemeState() is a stable snapshot
  document.documentElement.dataset.theme = next.resolved;
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute("content", THEME_COLOR[next.resolved]);
  if (changed) listeners.forEach((fn) => fn());
}

function start() {
  if (started || typeof window === "undefined") return;
  started = true;
  const preference = readStored();
  state = { preference, resolved: resolveTheme(preference) }; // matches what the boot script painted
  window.matchMedia?.(DARK_QUERY).addEventListener("change", () => {
    if (state.preference === "system") apply({ preference: "system", resolved: systemTheme() });
  });
  window.addEventListener("storage", (e) => {
    if (e.key !== STORAGE_KEY && e.key !== null) return; // null = storage cleared
    const preference = readStored();
    apply({ preference, resolved: resolveTheme(preference) });
  });
}

export function getThemeState(): ThemeState {
  start();
  return state;
}

export function setThemePreference(preference: ThemePreference) {
  start();
  try {
    localStorage.setItem(STORAGE_KEY, preference);
  } catch {
    // storage blocked: the theme still applies for this page view
  }
  apply({ preference, resolved: resolveTheme(preference) });
}

/** Two-state toggle: flips what is on screen and stores it as an explicit choice. */
export function toggleTheme() {
  setThemePreference(getThemeState().resolved === "dark" ? "light" : "dark");
}

export function subscribeTheme(fn: () => void): () => void {
  start();
  listeners.add(fn);
  return () => listeners.delete(fn);
}
```

## React binding

No provider needed; safe under SSR and hydration.

```ts
// useTheme.ts
import { useSyncExternalStore } from "react";
import { SERVER_STATE, getThemeState, setThemePreference, subscribeTheme, toggleTheme } from "./theme";

export function useTheme() {
  const { preference, resolved } = useSyncExternalStore(subscribeTheme, getThemeState, () => SERVER_STATE);
  return { preference, resolved, setPreference: setThemePreference, toggleTheme };
}
```

## Other frameworks

Other frameworks wrap the same three functions: a Vue `ref` updated in
`subscribeTheme`, a Svelte `readable` store, or plain DOM listeners.
