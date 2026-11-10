---
name: light-dark-mode
description: >
  Implement, fix or audit light/dark mode on any website or web app, on any stack (static
  HTML, Astro, Vite/React, Next.js, SvelteKit, Vue): a data-theme attribute on the html
  element, semantic CSS variables with a dark override block, a blocking boot script so
  there is no flash of the wrong theme, a small controller for localStorage, OS
  preference, browser chrome color and cross-tab sync, and an accessible toggle or
  Light/Dark/System control. Use whenever the user asks for dark mode, a theme toggle or
  switcher, prefers-color-scheme, data-theme, color-scheme, theme-color, a flash of the
  wrong theme on load, dark mode for code blocks, canvas or images, or says the site
  "should follow the system theme", even if they only say "add a dark version". Not for
  Quantum Design token files (`system-light.json`, `system-dark.json`), which belong to
  the `quantum-design-tokens` skill.
---

# Light/Dark Mode

One mechanism for every site: **the resolved theme lives in `data-theme` on `<html>`,
colors live in CSS variables, and an inline script sets the attribute before first
paint.** Components never know which theme is active; they read variables, and the
variables change under them.

If the project uses Quantum Design tokens (`system-light.json` / `system-dark.json`,
`--components-tokens--*` variables), `quantum-design-tokens` owns the token files and the
boot script (its Phase 3). Skip Phases 3 and 4 here and keep that boot script, upgrade its
toggle in Phase 6 instead of adding a second one, read `theme-color` from a component
token instead of a literal, and do everything else.

## Hard rules (never violate)

1. **One attribute.** `<html data-theme="light|dark">` is the only switch. Never a
   `.dark` class somewhere else, a theme prop threaded through components, or two
   mechanisms side by side.
2. **Three preferences, two themes.** The stored preference is `light`, `dark` or
   `system`. What lands on `<html>` is always resolved to `light` or `dark`.
   Resolution order: stored choice → the default (normally `system`, which means the OS
   setting) → light.
3. **Colors are variables.** Light values on `:root, [data-theme="light"]`, dark
   overrides on `[data-theme="dark"]`, each block with its own `color-scheme`. Any
   literal color outside the token block is a bug.
4. **No flash.** A blocking inline script in `<head>`, ahead of every stylesheet, sets
   the attribute and the `theme-color` meta. Hydration only takes over from it.
5. **Validate what you read.** Storage can hold anything or throw. Accept only the
   three values; wrap every storage access in try/catch.
6. **Follow the OS live only while the preference is `system`.** An explicit choice
   wins until the user changes it.
7. **One set of constants.** Storage key, default preference and `theme-color` values
   are identical in the boot script and the controller. In SSR frameworks, build the
   boot script string from the same constants.
8. **Everything follows.** Native controls and scrollbars (`color-scheme`), the mobile
   browser bar (`theme-color`), code blocks, canvas, images and Storybook switch too.

## Phase 1 — Inspect

- Stack and where the document `<head>` is authored: `index.html`, `BaseHead.astro`,
  `_document.tsx`, `app/layout.tsx`, `app.html`, a template partial.
- Existing mechanisms: grep for `prefers-color-scheme`, `data-theme`, `.dark`,
  `color-scheme`, `theme-color`, `next-themes`, `darkMode`, `localStorage` + `theme`.
- Hardcoded colors in component CSS/JS: `#hex`, `rgb(`, `hsl(`, Tailwind palette
  classes (`bg-white`, `text-gray-900`).
- Things that won't follow CSS variables: syntax highlighting, `<canvas>`/WebGL/chart
  libraries, `<picture>` sources, iframes, inline SVG with fills.
- A Content-Security-Policy that blocks inline scripts (needs a nonce or hash).

If a maintained library already does this (for example `next-themes` with
`attribute="data-theme"`), keep it, check it against the hard rules, and do only the
missing steps. Don't add a second mechanism.

## Phase 2 — Decide (ask only if the user hasn't said)

| Decision | Default | Alternative |
|---|---|---|
| Default preference | `system` (follow the OS until the user picks) | `light` for products whose design is light-first; only an explicit `System` choice follows the OS |
| Control | Two-state toggle in the header (flips what is on screen and stores it) | Light / Dark / System segmented control in settings |
| Storage key | `theme` | `<app>:theme` when several apps share one origin |
| Signed-in sync | none | Save the preference on the user profile so it follows them across devices |

## Phase 3 — CSS tokens

Primitives first, then semantic tokens that point at them. Components only use the
semantic ones.

```css
:root {
  /* Primitives (theme-independent) */
  --gray-0: #ffffff;
  --gray-50: #f4f6f8;
  --gray-400: #9aa4ad;
  --gray-500: #6b7680;
  --gray-600: #59636c;
  --gray-800: #1f262c;
  --gray-900: #121212;
  --brand-500: #2a9dad;
  --brand-600: #1c7480;
}

/* Light: the default, and the fallback for any token the dark block omits */
:root,
[data-theme="light"] {
  color-scheme: light;
  --color-bg: var(--gray-50);
  --color-surface: var(--gray-0);
  --color-text: var(--gray-800);
  --color-text-muted: var(--gray-600);
  --color-border: var(--gray-500);
  --color-accent: var(--brand-600);
  --shadow: 0 2px 8px rgb(0 0 0 / 0.12);
}

[data-theme="dark"] {
  color-scheme: dark;
  --color-bg: var(--gray-900);
  --color-surface: var(--gray-800);
  --color-text: var(--gray-50);
  --color-text-muted: var(--gray-400);
  --color-border: var(--gray-500);
  --color-accent: var(--brand-500);
  --shadow: 0 2px 8px rgb(0 0 0 / 0.4);
}

body {
  background: var(--color-bg);
  color: var(--color-text);
}
```

Rules:
- The dark block overrides colors (and color-carrying values like shadows) only.
  Spacing, type and radius never change per theme.
- `[data-theme="light"]` sits in the light selector so a light island inside a dark
  page (`<section data-theme="light">`) resolves correctly, and vice versa.
- A color that must not change between themes (dark text on a yellow button, a band
  that stays dark in both) gets its own token with the same value in both blocks, or
  a locally scoped variable on that section. Don't let it inherit by accident.
- A component needing a one-off dark tweak uses `[data-theme="dark"] .component`
  (`:global([data-theme="dark"]) .component` in scoped styles). If it keeps happening,
  the token is missing.
- Migrate hardcoded colors to tokens as part of the job, and report anything left.

**Tailwind.** Map utility colors to the semantic variables under their own names (a
key that references a variable of the same name is circular) and point the `dark:`
variant at the attribute. v4:
`@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));` plus
`@theme inline { --color-page: var(--color-bg); --color-ink: var(--color-text); … }`
(gives `bg-page`, `text-ink`; `inline` makes utilities emit the variable, so a theme
switch reaches them). v3: `darkMode: ['selector', '[data-theme="dark"]']` and
`theme.colors: { page: "var(--color-bg)", … }`. With colors swapping through
variables, `dark:` variants are rarely needed.

## Phase 4 — Boot script (no flash)

Inline, blocking, the first script in `<head>`, after the `theme-color` meta it updates
and before any stylesheet. ES5, no imports, everything in try/catch.

```html
<meta name="theme-color" content="#f4f6f8" />
<script>
  (function () {
    var KEY = "theme";
    var DEFAULT = "system";
    var COLOR = { light: "#f4f6f8", dark: "#121212" };
    var p = DEFAULT;
    try {
      var s = localStorage.getItem(KEY);
      if (s === "light" || s === "dark" || s === "system") p = s;
    } catch (e) {}
    var dark =
      p === "dark" ||
      (p === "system" &&
        !!window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    var t = dark ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", t);
    var m = document.querySelector('meta[name="theme-color"]');
    if (m) m.setAttribute("content", COLOR[t]);
  })();
</script>
```

`COLOR` holds the page background of each theme (the `--color-bg` values), so the
mobile browser bar blends with the page. Never `type="module"`, `defer` or `async`: a
deferred script runs after first paint, which is exactly the flash.

## Phase 5 — Controller

One framework-agnostic module owns the attribute after load: storage, the OS listener,
cross-tab sync and the meta tag. UI code calls it and never touches `data-theme`.

Read `references/theme-controller.md` when writing the controller or its framework
binding; it holds the module to adapt. Skip it when a maintained library stays in place
(Phase 1).

Its exports, used in the phases below: `STORAGE_KEY`, `DEFAULT_PREFERENCE`, `THEME_COLOR`,
`getThemeState`, `setThemePreference`, `toggleTheme`, `subscribeTheme`.

**Signed-in sync (optional).** When the user profile loads, call
`setThemePreference(profile.theme)` if it is a valid preference: the saved choice wins
over the device cache, and writing it to storage makes the next boot right on this
device. On change, call `setThemePreference(next)` and then save `next` to the profile.

## Phase 6 — The control

**Two-state toggle.** A real `<button type="button">` showing the icon of the theme you
will switch *to* (moon in light, sun in dark).
- Client-rendered UI (SPA, React): the label states the action and comes from state:
  `aria-label={resolved === "dark" ? "Switch to light theme" : "Switch to dark theme"}`.
- Server-rendered or static markup: render both icons and swap them with CSS, so the
  HTML is identical in both themes and correct before any JS runs:

```css
.theme-toggle__sun { display: none; }
[data-theme="dark"] .theme-toggle__sun { display: block; }
[data-theme="dark"] .theme-toggle__moon { display: none; }
```

  Give it a fixed accessible name ("Dark mode") with `aria-pressed` set from
  `getThemeState().resolved === "dark"` on load and in `subscribeTheme`. Wire it with
  `button.addEventListener("click", toggleTheme)`.

**Light / Dark / System control.** A `role="radiogroup"` with three `role="radio"`
buttons (`aria-checked` from `preference`, not `resolved`), arrow-key movement between
options, and `setThemePreference(option)` on select. Label the options with text, not
only icons.

Both need a visible `:focus-visible` outline using a token, a hit area of at least
24×24 px, and translated labels if the site is localized.

## Phase 7 — Wire it into the stack

- **Static HTML / any template engine.** Boot script in the shared `<head>` partial;
  controller loaded as a module at the end of `<body>`.
- **Astro.** Boot script as `<script is:inline>` in the base head component; the
  toggle component's `<script>` imports the controller. With `<ClientRouter />`, the
  new page's `<html>` replaces the attribute on every navigation, so re-apply it:

```ts
import { THEME_COLOR, getThemeState } from "./theme";
document.addEventListener("astro:after-swap", () => {
  const { resolved } = getThemeState();
  document.documentElement.dataset.theme = resolved;
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", THEME_COLOR[resolved]);
});
```

- **Vite / client-rendered SPA.** Boot script in `index.html`, the `useTheme` hook (or
  equivalent) in components.
- **Next.js, Pages Router.** In `pages/_document.tsx`: `<Html data-theme="light">`, the
  `<meta name="theme-color">`, then
  `<script dangerouslySetInnerHTML={{ __html: THEME_BOOT }} />` first in `<Head>`, with
  `THEME_BOOT` built as a template string from the exported constants. Next hydrates
  only `#__next`, so touching `<html>` causes no mismatch.
- **Next.js, App Router.** In `app/layout.tsx`: `<html suppressHydrationWarning>` (the
  attribute legitimately differs from the server HTML) and the same inline script in
  `<head>`. Put the theme-color meta in the layout's `<head>` too, not in `metadata`,
  so it exists before the script runs.
- **SvelteKit.** Boot script in `src/app.html`'s `<head>`.
- **Other SSR.** Emit the boot script as the first inline script of the
  server-rendered `<head>`.
- **CSP without inline scripts.** Add the boot script's hash or a per-request nonce. If
  that is impossible, mirror the choice into a `theme` cookie and render `data-theme`
  on the server; `system` then falls back to the CSS default until the controller
  starts.

## Phase 8 — Things that don't follow CSS variables

- **Syntax highlighting.** Use dual themes and switch on the attribute. Shiki (Astro
  `markdown.shikiConfig`): `themes: { light: "github-light", dark: "<dark theme>" }`,
  `defaultColor: "light"`, then:

```css
[data-theme="dark"] .shiki,
[data-theme="dark"] .shiki span {
  color: var(--shiki-dark) !important;
  background-color: var(--shiki-dark-bg) !important;
}
```

  (Astro's class is `.astro-code`.) Other highlighters: load both stylesheets, scope
  each under its `[data-theme]`.
- **Canvas, WebGL, charts.** Read colors from the variables with
  `getComputedStyle(document.documentElement).getPropertyValue("--color-…")` at draw
  time and redraw on change. Observe the attribute rather than a theme prop; framework
  effects can run in an order that leaves a prop one render stale:

```ts
new MutationObserver(redraw).observe(document.documentElement, {
  attributes: true,
  attributeFilter: ["data-theme"],
});
```

- **Images.** `<picture><source media="(prefers-color-scheme: dark)">` follows the OS,
  not the toggle. Use inline SVG with `currentColor`/variables, or two images swapped
  by `[data-theme]` rules.
- **Iframes and embeds** don't inherit the attribute. Pass a theme parameter if the
  embed supports one; otherwise accept and note it.
- **Storybook.** A `theme` global with a toolbar (light/dark) and a decorator that sets
  `document.documentElement.dataset.theme` from `context.globals.theme`. Import the
  same token CSS in `preview`.
- **Transitions.** Don't put `transition` on colors globally; every element animating
  at once makes the switch feel slow.

## Phase 9 — Verify

Run the site and check each case, in both themes:

1. Hard reload with no stored value, OS light and OS dark (DevTools → Rendering →
   emulate `prefers-color-scheme`); then with `light` and `dark` stored. First paint is
   already correct: no flash, including with CPU throttling and the cache disabled. SSR
   stacks log no hydration warnings.
2. Toggle at runtime: every component follows without a reload. Anything that doesn't
   still has a literal color; grep for `#hex`/`rgb(` outside the token file.
3. Form controls, scrollbars and autofill look native in dark (`color-scheme`).
4. The mobile browser bar matches the page background; the boot `COLOR` map matches
   `--color-bg` in both themes.
5. With preference `system`, flip the OS setting with the page open: it follows. With
   an explicit choice, it doesn't.
6. Two tabs: change the theme in one, the other follows.
7. Storage blocked (private window, or throw from `localStorage` in a test): no errors,
   the OS theme applies.
8. Text contrast at least 4.5:1 (3:1 for large text and UI borders) in both themes.
9. Code blocks, canvas, images and Storybook switch.
10. If the project has a test runner: unit tests mock `window.matchMedia` with a
    controllable `matches` and a `change` listener, clear storage before each test, and
    cover: default, stored choice wins, invalid value ignored, OS change followed only
    under `system`.

Fix any failing case and rerun the checks before the report. A case that can't pass or
can't be run goes under `Verified` in the report, with the reason.

## Report

```
Light/dark mode — <project>
Stack: <framework> · Default: <system|light> · Control: <toggle|segmented> · Key: <key>
Files: <boot location>, <controller>, <token CSS>, <control component>
Migrated: <n> hardcoded colors → tokens · Left: <list with file:line, or none>
Special cases: <code blocks / canvas / images / embeds and how each was handled>
Verified: <cases 1–10, any that could not be run and why>
```