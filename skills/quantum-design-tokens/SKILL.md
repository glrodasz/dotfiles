---
name: quantum-design-tokens
description: >
  Adopt, migrate to, extend, theme, or audit Quantum Design tokens — the three-level
  Global → System → Component token architecture in slim W3C DTCG JSON with light/dark
  system files — in a new or existing project, on any stack. Seeds the token JSON, wires
  a zero-dependency build and audit, sets up theming, and replaces hardcoded values
  until UI code uses component tokens only. Use whenever the user wants to set up or
  migrate a project to Quantum Design or design tokens, replace hardcoded
  colors/spacing/radius/typography with tokens, add tokens for a component or page, fix
  dark mode values, re-theme to another palette, build a token pipeline (CSS variables,
  Sass, Tailwind, CSS-in-JS, iOS, Android, Flutter), or audit token usage; also on
  "Quantum Design", "DTCG", "system tokens", "component tokens", or
  `--components-tokens--` variables.
---

# Quantum Design Tokens

Bring a project, new or existing, onto Quantum Design tokens and keep it there. Every
visual decision becomes a token in one of three levels. UI code only touches the top
level, so a re-theme or dark mode never edits a component. The JSON is the single source
of truth. Generated output is never edited by hand, and a migration never changes how
the UI looks without saying so in the report.

- Token format, level rules, full vocabulary, theming: see `references/token-spec.md`.
- Consuming tokens, theme boot, Tailwind/Sass/CSS-in-JS/native recipes, bridging existing
  variables, build algorithm for ports: see `references/platforms.md`.
- Seed token source: `assets/tokens/` (`global.json`, `system-light.json`,
  `system-dark.json`, `components.json`). These files are clean: 0 errors and 0 warnings.
- Build, audit, and value matching: `scripts/quantum-tokens.mjs` (Node ≥ 18, no
  dependencies).

```
Global     raw values: palettes, scales, font stacks            global.json
  ↓ referenced by
System     semantic roles: "Primary", "Danger", "Spacing.md"     system-light.json (+ system-dark.json)
  ↓ referenced by
Component  scoped roles: "button.background-color.primary.hover" components.json
  ↓ consumed by
UI code    stylesheets, style objects, native views
```

## Hard rules (never violate)

1. **UI code uses component tokens only.** Never reference system or global tokens from a
   stylesheet, style object, or native view.
2. **Each level references only the level directly below.** Component → System → Global.
3. **Colors always alias.** A raw color in a system or component token opts out of
   theming. A raw *non-color* value is allowed only with a `$description` saying why it
   has no ancestor.
4. **Themes override system color tokens only.** Component tokens never vary per theme.
5. **Generated output is never hand-edited.** Edit the JSON, rebuild, and require zero
   errors.
6. **References are exact JSON keys.** `{system.Typography.font-size.Body.sm}`,
   `{system.Border radius.sm}`, prefix `components` (plural). Copy keys character for
   character.

## Inputs

- **Target:** the current repository unless the user names another path.
- **Token source dir:** `tokens/` at the project root, or the existing one if the
  project already has DTCG files (e.g. `src/tokens/json/`).
- **Generated CSS:** next to the global stylesheet (e.g. `src/styles/design-tokens.css`).
- **Scope:** the whole UI by default. If the user names components or pages, migrate only
  those, but still set up the full token source and build.

## Phase 0 — Understand the target

1. **New or existing.** New = no meaningful styling yet. Existing = stylesheets,
   components, maybe an existing token or theme system.
2. **Stack:** framework, styling approach (plain CSS, CSS Modules, Sass, Tailwind v3/v4,
   CSS-in-JS, Vue/Svelte/Astro SFCs, native), entry stylesheet, how the app boots (for
   the theme script), package manager, CI.
3. **Existing design system:** grep for CSS custom properties, Tailwind theme config,
   Style Dictionary/Theo/Figma token exports, theme objects, `prefers-color-scheme`,
   `data-theme`/`.dark` toggles. Note what each one controls.
4. **Brand:** existing palette, fonts, and radius feel. Decide between the default schema
   (Metal chartreuse + Principal palette), another of the nine schemas, or a custom brand
   palette under `Colors.Custom`.
5. **Inventory** (existing projects): copy `scripts/quantum-tokens.mjs` to the project's
   `scripts/` and seed `tokens/` (Phase 1), then run
   `node scripts/quantum-tokens.mjs audit --scan src`. The `hardcoded` section is the
   migration backlog, and its count is the baseline for the report.

Ask one focused question only if the brand direction is unclear and the code doesn't
answer it. Otherwise proceed with the default schema and say so.

## Phase 1 — Seed the token source

1. Copy the four files in `assets/tokens/` into the token source dir unchanged. Never
   re-type them: the global palettes hold exact values.
2. **Brand.** If the project has its own palette, replace `Colors.Custom.Principal
   palette` (or add `Colors.Custom.<Brand>`) as `100`–`600` plus `opacity` (15% alpha),
   and repoint the `Primary` and `Complementary` system colors in both theme files. To
   pick a schema instead, repoint them at `Colors.Schemas.<Schema>.<Palette>` (see
   `references/token-spec.md` §6).
3. **Fonts.** Repoint `system › Typography.Font-family.*` at the project's families. Add a
   missing family to `global › Typography.Font-family` as a complete stack. Load the font
   files the way the stack already loads fonts.
4. **Prune nothing yet.** Unused components and palettes cost nothing, and the `unused`
   audit check reports them later.
5. If the project already has DTCG files, keep them. Run the audit and fix their
   `format`, `broken-reference`, and `raw-value` findings instead of replacing them.

## Phase 2 — Wire the build

1. Copy `scripts/quantum-tokens.mjs` into the project (`scripts/` or `tools/`), unless the
   Phase 0 inventory already did. It is the project's generator, not a dependency.
2. Add `tokens:build` and `tokens:audit` package scripts, and run the build before `dev`,
   `build`, Storybook, and tests (recipes in `references/platforms.md` §3).
3. Run: `node scripts/quantum-tokens.mjs build --src tokens --out <generated css>`. It
   must print `0 unresolved references`. It refuses to write on any error.
4. Import the generated CSS once, first, from the app entry. For Tailwind, Sass, or
   CSS-in-JS, add the mapping layer from `references/platforms.md` §3. Map component
   tokens only.
5. Add `tokens:audit` to CI. It exits non-zero on errors, and `--strict` also fails on
   warnings. Use `--strict` once the migration is complete.
6. Non-web targets: write a generator for the platform from `references/platforms.md`
   §5–6 that reads the same JSON.

## Phase 3 — Wire theming

1. Add the blocking theme boot script and a toggle (`references/platforms.md` §2):
   persisted choice → OS preference → light, set as `data-theme` on `<html>` before
   first paint.
2. Replace any existing dark-mode mechanism (`.dark` class, `prefers-color-scheme` blocks
   with literal colors, a theme context of hex values) with the token theme. Don't run two
   mechanisms side by side.
3. Theme-invariant roles (text on a yellow accent, paper illustrations) go in
   `Colors.Fixed` with identical values in both theme files.

## Phase 4 — Map and migrate values

Work one component or page at a time, smallest shared pieces first (buttons, inputs,
typography), then layouts and pages. For each literal:

1. **Find the role**, not the hex: background, muted text, border, focus, gap, radius,
   heading size.
2. **Find the system token on the matching scale.** Run
   `node scripts/quantum-tokens.mjs match '#646cff' 20px 1.5rem`. It lists the nearest
   system and global colors by ΔE, and the nearest Spacing, Sizing, Border radius,
   font-size, and Line-height steps. Pick by meaning first, distance second.
3. **Add or reuse a component token** in `components.json`, using the grammar
   `{component}.{property}.{variant|size}.{state}`. Use the app namespace (`Site`) for
   page-level roles. Point it at the system token.
4. **Off-scale values:**
   - ≤ 2px off a step (or ΔE < 5): snap to the step and list it under "Visual changes".
   - Recurring off-scale value (3+ uses): propose a new global step plus a system key, and
     ask before adding it, because scales are shared vocabulary.
   - One-off: a raw component token with a `$description` (fluid `clamp()`, `em`
     tracking, unitless line-height, stroke widths, tap-target floors).
   - Off-palette color: the nearest global shade if ΔE < 5. Otherwise add the shade to
     global (to `Colors.Custom` for brand colors) and reference it. Never use a raw hex in
     a system or component token.
5. **Replace the literal** with `var(--components-tokens--…)` (or the stack's mapped
   equivalent). Existing variables with many call sites get a bridge alias first
   (`references/platforms.md` §4).
6. **Rebuild and re-audit** after each component. `hardcoded` should shrink, and
   `missing-token` and `bad-usage` must stay at zero.

Legitimate leftovers: structural values (`0`, `100%`, `50%` circles, `auto`,
`transparent`, `currentColor`, alpha masks) and token tooling such as a token explorer.
Mark a justified line with a `quantum-tokens-ignore` comment, or exempt a directory with
`--exempt <path>`. Keep exemptions narrow and list them in the report.

## Phase 5 — Verify

1. Run: `node scripts/quantum-tokens.mjs build …` → 0 unresolved references.
2. Run: `node scripts/quantum-tokens.mjs audit --scan src` → 0 errors. Every remaining
   warning is fixed or has a stated reason.
3. Render the main pages in **both themes**. Use the `run` skill or the dev server and a
   browser screenshot when available. Check text contrast on surfaces, focus rings,
   `Fixed.on-accent` on `Complementary.principal`, and no flash of the wrong theme on
   reload.
4. Toggle the theme at runtime: every component follows without a reload. A component that
   doesn't is reading a resolved literal (JS constants, canvas, Tailwind without
   `inline`).

```
- [ ] Token JSON seeded; build passes with 0 unresolved references.
- [ ] Generated CSS imported first; never hand-edited; build runs before dev/build/CI.
- [ ] Audit: 0 errors; bad-usage 0; remaining hardcoded/raw-value warnings justified.
- [ ] UI code references component tokens only; bridge aliases listed or removed.
- [ ] Theme boot sets data-theme on <html> before paint; persisted → OS → light.
- [ ] Both themes viewed; theme-invariant roles live in Colors.Fixed in both files.
- [ ] Every visual change from snapping is listed in the report.
```

## After migration — day-to-day changes

- **Token for an existing component:** reuse its property, variant and state names, point
  it at the system token whose meaning matches, rebuild, then use it.
- **New component:** list every visual property per variant, size and state, and add
  `components.json › <component>`. Typography follows the closest `Typography.Styles`
  entry.
- **Dark-mode fix:** confirm the key exists in light, then add the same path to
  `system-dark.json` with a global reference. If no shade fits, add one to global first.
- **Re-theme:** repoint system color references in light, then dark. Leave component
  tokens untouched, then check contrast.
- **Type scale change:** `references/token-spec.md` §6.

## Report

```markdown
## Quantum Design tokens — <project>

**Stack:** <framework · styling · targets>   **Mode:** new | migration (<scope>)
**Theme:** <schema / brand palette> · fonts <Headings / Body / Code>

### Changes made
- Token source: <dir> (seeded | existing, fixed N issues) · generated: <file>
- Build + audit wired: <package scripts, CI step>
- Theming: <boot script, toggle, replaced mechanism>
- Migrated: <components/pages> — hardcoded <before> → <after>
- Tokens added: <component tokens, new global shades/steps>

### Visual changes
- <file:line> <old> → <token> (<new value>) — <why: snapped / new step>

### Still needs human attention
- <off-scale values awaiting a scale decision, bridge aliases left, exemptions, contrast checks not run>

### Audit
<errors · warnings · info, with the remaining warnings and why>
```

## Notes & edge cases

- **Big codebases:** migrate shared atoms first and land each component as its own commit.
  Bridge aliases keep the app working between commits.
- **Existing DTCG with `$extensions` or Figma metadata:** strip it. Slim DTCG only, and the
  audit flags the rest as `format` errors.
- **Dynamic token names** (`` `--components-tokens--button--${variant}` ``) are skipped by
  the usage scan, and the tokens they reach show as `unused`. Prefer full names where
  practical.
- **Canvas/WebGL/charts** need real color values. Read component tokens with
  `getComputedStyle` at draw time and redraw on theme change.
- **Email templates and OG images** can't use CSS variables. Resolve component tokens at
  build time from the generated CSS and accept that they don't theme.
- **Stories, tests, and specs** are skipped by the hardcoded scan. Demo scaffolding isn't
  product UI.
- **Seed differences:** the seed's dark file references global shades everywhere (the
  feedback colors use the 300/600 steps), and `components.json` ships the generic
  components plus a minimal `Site` namespace. Rename `Site` to the app's name only if
  every reference and generated name changes with it.
- **The `quantum-design` UI-generation skill** builds components on these tokens. This
  skill owns the token source, build, theming, and migration.
