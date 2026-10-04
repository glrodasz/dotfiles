# Wiring tokens into a stack

How the generated output reaches UI code on each stack, how the theme is applied, and the
build algorithm for platforms the bundled Node script doesn't cover.

## Contents

1. Consuming tokens in UI code
2. Theme boot (web)
3. Stack recipes: plain CSS · Sass/Less · Tailwind v4 · Tailwind v3 · CSS-in-JS / TS ·
   CSS Modules and frameworks
4. Bridging an existing token or variable set
5. Native platforms
6. Build algorithm (for ports)

---

## 1. Consuming tokens in UI code

```css
/* ✅ component tokens only */
.qd-button--primary {
  background-color: var(--components-tokens--button--background-color--primary--default);
  padding: var(--components-tokens--button--spacing--large--vertical)
           var(--components-tokens--button--spacing--large--horizontal);
}

/* ❌ system/global tokens and raw values in UI code */
.qd-button--primary {
  background-color: var(--system-tokens--colors--complementary--principal);
  padding: 12px 32px;
}
```

- **Missing token?** Add it to `components.json`, point it at the right system token,
  rebuild, then use it. Never "temporarily" use a system or global token.
- **Local short aliases** are fine when they point at component tokens:
  `--color-bg: var(--components-tokens--site--colors--background);`
- **Structural values are not design decisions:** `display`, flex, `0`, `100%`, `50%`
  (circles), `auto`, `transparent`, `currentColor`, alpha masks.
- **Naming discipline:** the reference implementation pairs tokens with BEM classes
  prefixed `qd-` (`qd-button--primary`, `qd-input-text__container--error`).

## 2. Theme boot (web)

Put this inline and blocking in `<head>`, before any stylesheet that paints, so there is no
flash of the wrong theme. Set `data-theme` on `<html>`.

```html
<script>
  (function () {
    var saved = null;
    try { saved = localStorage.getItem('theme'); } catch (e) {}
    var theme = saved === 'light' || saved === 'dark'
      ? saved
      : (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', theme);
  })();
</script>
```

The toggle writes `localStorage.theme` and updates the attribute. Also update
`<meta name="theme-color">` from a component token read with
`getComputedStyle(document.documentElement).getPropertyValue(...)`, never a literal hex.
SSR frameworks may read a `theme` cookie on the server and render the attribute instead.

Component tokens are re-declared under `:root, [data-theme]`, so a subtree with its own
`data-theme` (a dark hero inside a light page) re-resolves correctly.

## 3. Stack recipes

All recipes run the same build. Add these package scripts and run the build before `dev`,
`build`, and Storybook:

```json
"tokens:build": "node scripts/quantum-tokens.mjs build --src tokens --out src/styles/design-tokens.css",
"tokens:audit": "node scripts/quantum-tokens.mjs audit --src tokens --out src/styles/design-tokens.css --scan src"
```

Commit or ignore the generated CSS consistently. If it's committed, CI must run the build
and fail on a diff.

**Plain CSS / Vite / Next.js / Astro.** Import the generated file once from the app entry
(`main.tsx`, `app/layout.tsx`, the base layout) before any other stylesheet.

**Sass / Less.** Import the generated CSS. Compile-time variables cannot re-theme at
runtime, so if Sass maps are wanted, their values must be `var(--components-tokens--…)`
strings, never resolved literals.

**Tailwind v4.** Map utilities to component tokens with `@theme inline` (it makes
utilities emit the referenced variable, so runtime theme switches propagate). Reset the
default palette and spacing to make raw utilities fail loudly:

```css
@import "tailwindcss";
@import "./design-tokens.css";

@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

@theme inline {
  --color-*: initial;
  --color-bg: var(--components-tokens--site--colors--background);
  --color-surface: var(--components-tokens--site--colors--surface);
  --color-text: var(--components-tokens--site--colors--text);
  --color-muted: var(--components-tokens--site--colors--text-muted);
  --color-accent: var(--components-tokens--site--colors--accent);
  --font-heading: var(--components-tokens--site--typography--font-family--headings);
  --font-body: var(--components-tokens--site--typography--font-family--body);
}
```

Only map component tokens. Spacing utilities need app-namespace spacing tokens (e.g.
`Site.spacing.md` → `{system.Spacing.md}`) so `p-md` goes through the component layer.
Since colors swap through the variables, `dark:` variants are rarely needed.

**Tailwind v3.** Same mapping in `tailwind.config` `theme` (not `extend`, to drop the
default palette), with `darkMode: ['selector', '[data-theme="dark"]']`.

**CSS-in-JS / TypeScript.** Generate or hand-write a typed map whose values are
`var(--components-tokens--…)` strings (`tokens.components.button.spacing.large.vertical`).
Never inline resolved literals: they don't re-theme. Canvas/WebGL code that needs a real
value reads it at runtime with `getComputedStyle` and re-reads it on theme change.

**CSS Modules, Vue, Svelte, Astro.** Use `var(--components-tokens--…)` in component styles
exactly as in plain CSS. The audit scans `.vue`, `.svelte`, and `.astro` files.

## 4. Bridging an existing token or variable set

When the project already has variables (`--color-primary`, Tailwind theme keys, a
Style Dictionary output, a theme object):

1. Map every existing **raw** value: palette colors to the nearest global shade or a new
   `Colors.Custom.<Brand>` palette, lengths to the scales (`match` command).
2. Map every existing **semantic** name to a system role by meaning (`--color-primary` →
   `Colors.Primary.principal`). When the project's semantics differ, repoint the system
   token at a different global; don't invent new system groups.
3. Add a component token for each role the UI uses, then turn the old variable into a
   **bridge alias**: `--color-primary: var(--components-tokens--site--colors--accent);`.
   Existing call sites keep working and now theme correctly.
4. Migrate call sites to component tokens one component at a time. Delete each bridge
   alias once the audit shows no remaining uses. Bridges are temporary: list the ones
   still in place in the report.

## 5. Native platforms

Keep the three levels as separate namespaces. Wherever late binding exists, component
symbols reference system symbols so a theme change propagates without regeneration.

| Target | Naming | Component → system alias | Theme switch | Units |
|---|---|---|---|---|
| iOS (Swift) | `ComponentTokens.Button.Spacing.largeVertical` | Dynamic colors (light/dark appearances) referenced by system symbols | Trait collection / color scheme | pt |
| Android | Compose: `ComponentTokens.Button.spacingLargeVertical`; XML: `components_tokens_button_spacing_large_vertical` | Resource reference (`@color/system_tokens_…`) | `values/` vs `values-night/` | dp / sp |
| Flutter | `ThemeExtension` per level | Fields read from the system extension | Light/dark `ThemeData` | logical px |
| React Native | `tokens.components.button.spacingLargeVertical` | Getter or hook that reads the active system palette | `useColorScheme` + persisted choice | dp (unitless numbers) |

Write a generator for the target that implements §6 and keeps the JSON in this skill's
format as the single source of truth. Never hand-maintain native token files.

## 6. Build algorithm (for ports)

1. **Load** `global.json`, `system-light.json`, `system-dark.json` (missing = empty),
   `components.json`.
2. **Flatten** depth-first. A node with a string `$type` and a defined `$value` is a token;
   otherwise recurse into keys that don't start with `$`. Path = `<level root>.<keys
   joined by ".">`, roots `global tokens`, `system tokens`, `components tokens`.
3. **Detect references:** a string value matching `^\{(.+)\}$`.
4. **Two resolution spaces:** light = global ∪ system-light ∪ components; dark = global ∪
   system-dark.
5. **Resolve:** map the prefix (`global`/`system`/`components`) to its root and look up the
   path exactly. Resolve recursively with cycle detection. An unresolved reference fails
   the build.
6. **Name:** `--` + lowercase, whitespace runs → `-`, `.` → `--`, drop everything outside
   `[a-z0-9-]`. `system tokens.Border radius.sm` → `--system-tokens--border-radius--sm`.
7. **Emit values:**
   - A component token whose target is a system (or component) token is emitted as an
     alias to that symbol, never a literal. This is what lets theme switches reach
     components.
   - Colors: strip a trailing `ff` alpha; keep other 8-digit hex.
   - Numbers: round float noise to 4 decimals. Add the platform unit when the path
     contains `font-size`, `line-height`, `spacing`, `sizing`, `radius`, `width`, `height`
     or `offset`, **except** ratio paths (a `Scale` segment). Everything else is unitless.
   - Strings verbatim.
8. **Lay out:** globals, non-color system tokens; component aliases in every themed scope;
   light system colors in the default scope; dark overrides in the dark scope.
9. **Report** counts per level, dark overrides, and every error. Write nothing on error.
