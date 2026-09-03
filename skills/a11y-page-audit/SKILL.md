---
name: a11y-page-audit
description: >
  Run an accessibility and keyboard navigation audit on a web page or project, then fix
  what it finds — audit, fix, and verify, not just a report. Use whenever the user asks
  about accessibility, a11y, keyboard navigation, focus styles or focus management,
  screen readers, ARIA, WCAG compliance, skip links, tab order, or making a site
  keyboard-navigable before shipping.
---

# Accessibility & Keyboard Navigation Audit

Audit-then-fix workflow. The goal is to leave the codebase with working keyboard nav,
visible focus indicators, correct semantics, and proper ARIA — not just a report.

## Phase 0 — Understand the target

1. **Input type**: directory → scan components, layouts, global CSS. URL → fetch HTML and
   flag that source fixes need the actual codebase.
2. **Framework**: determines where layouts, head tags, and route changes live.
3. **Design system**: tokens / CSS custom properties / Tailwind / component library —
   determines how to implement the focus ring.

If ambiguous, ask one focused question before proceeding.

## Phase 1 — Audit & fix

Work through each category: record file path, current state, verdict (✅ PASS / ⚠️ WARN /
❌ FAIL), then apply the fix pattern for every ❌ and ⚠️.

### 1.1 Global CSS resets

**Check**: `* { outline: none }`, `*:focus { outline: none }`, or any blanket `outline: 0`
without a paired visible alternative — the most common a11y regression.

**Fix**: remove global outline resets. If a component legitimately needs a custom
indicator (e.g. `box-shadow` ring on inputs), keep `outline: none` only when paired with a
visible alternative using the focus token.

### 1.2 Focus ring system

**Check**: is there a shared, theme-aware focus ring?
- A design token / custom property for focus color that adapts between light and dark mode
- Passes WCAG AA contrast for UI components (3:1) against each mode's background
- A global `:focus-visible` rule applying the ring
- Components aliasing the token rather than hardcoding hex values

**Fix** — if missing, build it:
1. Add a system-level focus color token per theme. Pick from the existing palette when
   possible; each mode's value must pass 3:1 against that mode's background. If the brand
   palette has no passing color, use the closest passing color and document the override
   — don't sacrifice visibility for brand consistency.
2. Add component-level tokens aliasing it: `--focus-ring-color`, `--focus-ring-width: 2px`,
   `--focus-ring-offset: 2px`.
3. Add the global rule:
   ```css
   :focus-visible {
     outline: var(--focus-ring-width) solid var(--focus-ring-color);
     outline-offset: var(--focus-ring-offset);
   }
   ```
   Do NOT set `border-radius` here — `outline` follows the element's existing radius
   automatically; setting it changes the element's shape on focus.
4. Re-point existing per-component focus tokens to alias the system color.

### 1.3 Interactive elements

**Check** focus visibility and keyboard operability for: buttons (real `<button>` vs
`<div onClick>`), links (incl. anchor-wrapped cards), form inputs and custom checkboxes,
custom widgets (dropdowns, accordions, toggles, hamburger menus — keyboard operable?
`aria-expanded`?), and persistent landmarks (header/footer/nav tab order).

Watch for: `:focus` used instead of `:focus-visible` (rings on mouse click);
`outline: none` with no visible alternative; non-interactive elements with `onClick` but no
`role`, `tabIndex`, or keyboard handler.

**Fix**: replace `:focus` selectors with `:focus-visible` unless there's a documented
reason (rare — e.g. a text input that should always show its ring). Make custom widgets
keyboard-operable.

### 1.4 Skip link (WCAG 2.4.1)

**Check**: exists; is the first focusable element; target `<main>` has `tabIndex={-1}` so
focus actually moves; hidden with `transform` (not `display: none` — removes it from tab
order); revealed on `:focus-visible` (not `:focus` — shows on mouse click).

**Fix** — if missing:
```jsx
<a href="#main-content" className="skip-to-content">Skip to main content</a>
<main id="main-content" tabIndex={-1}>...</main>
```
Hidden by default via `transform: translateY(-200%)`, revealed on `:focus-visible`, styled
through design tokens, high z-index.

### 1.5 Semantic HTML

**Check**:
- Exactly one `<main>` per page (SPAs commonly nest multiples)
- One `<h1>`, no skipped heading levels
- Landmarks (`<header>`, `<nav>`, `<main>`, `<footer>`, `<aside>`) instead of `<div>` + role
- Footer/sidebar section titles are headings, not `<p>`/`<span>`
- No double-announcing: `alt=""` on decorative images whose accessible name comes from a
  sibling
- `<html lang="...">` set

**Fix**: collapse nested `<main>`s (keep one, demote others to `<div>`); promote section
titles to headings with `font-family: inherit; margin-top: 0;` to preserve rendering; fix
heading gaps; set decorative `alt=""`; add `lang`.

### 1.6 ARIA

**Check & fix**:
- Icon-only buttons (hamburger, theme toggle, close, search) → `aria-label`
- Disclosure triggers (menus, accordions, collapsibles) → `aria-expanded` (with JS toggle
  if needed)
- Form errors → `aria-invalid` + `aria-describedby` linking to the message
- Decorative SVGs/emojis next to text → `aria-hidden="true"`
- Remove redundant ARIA (`<button role="button">`, `<nav role="navigation">`)

### 1.7 SPA route-change focus (if applicable)

**Check**: after client-side navigation, does focus reset so the next Tab starts from the
top? Does scroll reset?

**Fix**: in the route-change/scroll-restoration hook, scroll to top and blur
`document.activeElement` (when it's an HTMLElement other than `body`) on pathname change.

### 1.8 Overflow-hidden focus clipping

**Check**: parents with `overflow: hidden` (cards, pills, button groups) containing
focusable children — the parent clips an outline that extends beyond its bounds.

**Fix**:
- **Pill / small element**: negative offset so the ring draws inside — `outline-offset: -2px`
- **Card / large target**: move the ring to the parent and suppress the inner one:
  ```css
  .card:has(a:focus-visible) {
    outline: var(--focus-ring-width) solid var(--focus-ring-color);
    outline-offset: var(--focus-ring-offset);
  }
  .card a:focus-visible { outline: none; }
  ```
  Use `:has(:focus-visible)`, not `:focus-within` — the latter triggers on mouse focus.

## Phase 2 — Verify

**Keyboard walkthrough** (repeat on every major route):
1. Load the page, press Tab — first stop must be the skip link.
2. Continue: skip-link → logo → nav → main CTAs → cards → footer links. Nothing silently
   skipped; no focus trap (except modals with proper escape handling).
3. Every focused element shows a clearly visible ring.
4. Toggle dark mode, tab again — ring switches color and stays visible.
5. Route changes reset focus to the top (next Tab hits skip-link again).

**Forms**: tab into every input (indicator visible), Enter submits, error states expose
`aria-invalid` + linked messages.

**Automated smoke test**: run axe DevTools or Lighthouse a11y. Treat the score as a
regression catch, not a substitute for the manual walkthrough.

## Report

```
## Accessibility Audit Report — [Page/Project]

Focus System     [PASS / BUILT / NEEDS WORK]
Skip Link        [PASS / ADDED / MISSING]
Keyboard Nav     [score /10] + findings
Semantic HTML    [score /10] + findings
ARIA             [score /10] + findings
SPA Focus Reset  [PASS / FIXED / N/A]

### Changes made
- [files modified/created, one line each]

### Still needs human attention
- [manual testing, content decisions, visual review]

### Conventions to document
- [rules for AGENTS.md / CLAUDE.md so future contributors maintain these patterns]
```

## Notes & edge cases

- **Tailwind**: check for `outline-none` in the base layer; replace with
  `focus-visible:ring-*` utilities tied to the token.
- **Component libraries (Radix, Headless UI, shadcn)**: they handle ARIA internally — audit
  the rendered DOM, not the source.
- **CSS-in-JS**: focus resets may hide in `createGlobalStyle` or theme objects — search all
  style definitions for `outline`.
- **Next.js App Router**: route-change focus reset lives in a client component wrapping
  `usePathname()`; the skip-link target goes on `<main>` in `app/layout.tsx`.
- **The three traps**: (1) `border-radius` in the global focus rule changes element shape
  on focus; (2) `overflow: hidden` parents clip inner outlines — move the ring to the
  parent via `:has(:focus-visible)`; (3) skip-link on `:focus` instead of `:focus-visible`
  reveals on mouse click.
