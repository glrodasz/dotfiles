---
name: a11y-page-audit
description: >
  Run a comprehensive accessibility and keyboard navigation audit on a web page or project,
  then fix what it finds. Use this skill whenever the user wants to check accessibility,
  keyboard navigation, focus management, screen reader support, ARIA usage, or WCAG compliance.
  Trigger on phrases like "accessibility audit", "a11y check", "keyboard navigation",
  "focus ring", "focus styles", "screen reader", "WCAG", "skip link", "tab order",
  "aria labels", "focus-visible", "focus management", or any request to make a site
  accessible or keyboard-navigable before shipping. Also trigger when the user says
  "can I tab through this?", "is this accessible?", "audit focus styles", or asks about
  semantic HTML landmarks, heading hierarchy, or focus traps. This skill covers the full
  pipeline — audit, fix, and verify — not just reporting.
---

# Accessibility & Keyboard Navigation Audit

A systematic audit-then-fix workflow for accessibility and keyboard navigation readiness.
The goal is to leave the codebase with working keyboard nav, visible focus indicators,
correct semantics, and proper ARIA — not just a report of what's wrong.

---

## Phase 0 — Understand the Target

Before touching anything, establish:

1. **Input type**: File path / project directory / URL?
   - Directory → scan for components, layouts, global CSS
   - URL → fetch HTML and flag that source fixes need the actual codebase
2. **Framework**: Next.js, Remix, plain HTML, Vue, etc. — this determines where layouts, head tags, and route changes live.
3. **Design system**: Does the project use design tokens? CSS custom properties? Tailwind? A component library? This determines how to implement the focus ring (token-based vs. utility-class vs. raw CSS).

If ambiguous, ask one focused question before proceeding.

---

## Phase 1 — Audit (read-only, no changes yet)

Audit every category below. For each item, record: file path, current state, and verdict (✅ PASS / ⚠️ WARN / ❌ FAIL).

### 1.1 Global CSS Reset Check

Search the entire codebase for focus-suppressing rules:

- `* { outline: none }` or `*:focus { outline: none }` in resets or global styles
- Any blanket `outline: 0` / `outline: none` without a paired visible alternative
- These are the single most common accessibility regressions — flag them prominently

### 1.2 Focus Ring System

Check whether a shared, theme-aware focus ring exists:

- Is there a design token or CSS custom property for focus color? (e.g. `--color-focus`, `--focus-ring-color`)
- Does the focus color change between light and dark mode?
- Does the focus color pass WCAG AA contrast (3:1 minimum for UI components) against both light and dark backgrounds?
- Is there a global `:focus-visible` rule applying the ring?
- Are components overriding focus styles with hardcoded hex values instead of aliasing the token?

### 1.3 Interactive Element Inventory

For each category, check focus visibility and keyboard operability:

| Category | What to check |
|---|---|
| **Buttons** | Real `<button>` vs `<div onClick>`. Focus ring visible? |
| **Links** | `<a>` / framework `<Link>`. Focus ring visible? Anchor-wrapped cards? |
| **Form inputs** | `<input>`, `<textarea>`, `<select>`, custom checkboxes. Focus indicator present? |
| **Custom widgets** | Dropdowns, accordions, toggles, hamburger menus. Keyboard operable? `aria-expanded`? |
| **Persistent landmarks** | Header, footer, nav — same elements on every page. Tab order correct? |

Pay special attention to:
- Elements using `:focus` instead of `:focus-visible` (causes focus ring on mouse click)
- `outline: none` paired with no visible alternative
- Non-interactive elements with `onClick` but no `role`, `tabIndex`, or keyboard handler

### 1.4 Skip Link

WCAG 2.4.1 requires a mechanism to bypass repeated blocks.

- Does a skip link exist?
- Is it the first focusable element on the page?
- Does the target (`<main>` or equivalent) have `tabIndex={-1}` so focus actually moves?
- Is the skip link hidden with `transform` (correct) or `display: none` (wrong — removes from tab order)?
- Does the reveal use `:focus-visible` (correct) or `:focus` (wrong — shows on click)?

### 1.5 Semantic HTML

- Exactly one `<main>` per page (SPAs commonly nest multiples — flag this)
- Heading hierarchy: one `<h1>` per page, no skipped levels (h1 → h3 with no h2)
- Semantic landmarks used: `<header>`, `<nav>`, `<main>`, `<footer>`, `<aside>` instead of `<div>` with role attributes
- Footer/sidebar section titles using headings, not `<p>` or `<span>`
- No double-announcing: image `alt` duplicating adjacent heading/link text (use `alt=""` for decorative images when the accessible name comes from a sibling)
- `<html lang="...">` set

### 1.6 ARIA

- Icon-only buttons have `aria-label` (hamburger, theme toggle, close, search)
- Disclosure triggers (mobile menu, accordions, collapsibles) have `aria-expanded`
- Form inputs with errors have `aria-invalid` + `aria-describedby` linking to the error message
- Decorative SVGs and emojis next to text have `aria-hidden="true"`
- No redundant ARIA: `<button>` doesn't need `role="button"`, `<nav>` doesn't need `role="navigation"`

### 1.7 SPA Route-Change Focus (if applicable)

In single-page apps, after a client-side navigation:
- Does focus reset so the next Tab starts from the top?
- Does the scroll position reset?
- Check the scroll-restoration / route-change hook for `document.activeElement.blur()` or equivalent

### 1.8 Overflow-Hidden Focus Traps

Search for components where a parent has `overflow: hidden` (cards, pills, button groups) and a child is focusable. The parent clips `outline-offset` that extends beyond its bounds.

Flag each instance and note which fix pattern applies:
- **Pill / small element**: use negative `outline-offset` (e.g. `-2px`) so the ring draws inside
- **Card / large click target**: move the focus ring to the parent via `:has(...:focus-visible)` and suppress the inner element's outline

---

## Phase 2 — Fix

Work through every ❌ FAIL and ⚠️ WARN from the audit. Follow these principles:

### 2.1 Focus Ring — Build or Repair the System

If no shared focus ring exists, create one:

1. **Add a system-level focus color token** (adapt naming to the project's token convention):
   - Light mode: a saturated color with AA contrast against the page background (e.g. `#0040B8`)
   - Dark mode: a different value that passes AA on the dark surface (e.g. `#F7DF1D`)
   - Pick from the existing palette when possible

2. **Add component-level focus-ring tokens** aliasing to the system color:
   - `--focus-ring-color` → system focus color
   - `--focus-ring-width` → `2px`
   - `--focus-ring-offset` → `2px`

3. **Add the global rule** in the project's global CSS:
   ```css
   :focus-visible {
     outline: var(--focus-ring-width) solid var(--focus-ring-color);
     outline-offset: var(--focus-ring-offset);
   }
   ```
   Do NOT set `border-radius` in this rule — modern browsers make `outline` follow the element's existing `border-radius` automatically. Setting it here changes the element's visual shape on focus.

4. **Re-point** any existing per-component focus tokens to alias the system color.

5. **Remove** any global `outline: none` resets. If a component legitimately needs a custom focus indicator (e.g. `box-shadow` ring on inputs), keep `outline: none` but pair it with the visible alternative using the focus token.

### 2.2 :focus-visible Everywhere

Replace every `:focus` selector with `:focus-visible` unless there's a documented reason to keep `:focus` (extremely rare — e.g. a text input that should always show its ring).

### 2.3 Skip Link

If missing, add:

```jsx
<a href="#main-content" className="skip-to-content">Skip to main content</a>
{/* ... */}
<main id="main-content" tabIndex={-1}>...</main>
```

Style it:
- Hidden by default with `transform: translateY(-200%)` (not `display: none`)
- Revealed on `:focus-visible`
- All visual values through design tokens (no hardcoded colors, padding, etc.)
- High z-index so it appears above everything

### 2.4 Semantic HTML Fixes

- Collapse nested `<main>` elements — keep one as the landmark, change others to `<div>`
- Promote footer/sidebar titles from `<p>`/`<span>` to headings. Add `font-family: inherit; margin-top: 0;` to preserve visual rendering
- Fix heading hierarchy gaps
- Set `alt=""` on decorative images that duplicate adjacent text
- Add `lang` attribute to `<html>` if missing

### 2.5 ARIA Fixes

- Add `aria-label` to icon-only buttons
- Add `aria-expanded` to disclosure triggers (with JS toggle if not already present)
- Wire `aria-invalid` + `aria-describedby` on form error states
- Add `aria-hidden="true"` to decorative SVGs/emojis
- Remove redundant roles from semantic elements

### 2.6 SPA Route-Change Fix

In the scroll-restoration or route-change hook:

```js
useEffect(() => {
  window.scrollTo({ top: 0, left: 0 });
  const active = document.activeElement;
  if (active instanceof HTMLElement && active !== document.body) {
    active.blur();
  }
}, [pathname]);
```

### 2.7 Overflow-Hidden Fixes

For each flagged instance:

**Pill / button group** — set negative outline-offset on the inner focusable element:
```css
.pill-link:focus-visible {
  outline-offset: -2px;
}
```

**Card** — move focus ring to parent, suppress inner:
```css
.card:has(a:focus-visible) {
  outline: var(--focus-ring-width) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}
.card a:focus-visible {
  outline: none;
}
```

Use `:has(:focus-visible)` not `:focus-within` — the latter triggers on mouse focus.

---

## Phase 3 — Verify

After all fixes, run through this checklist:

### Keyboard Walkthrough

1. Load the page, press Tab. First stop must be the skip link.
2. Continue tabbing: skip-link → logo/home link → nav items → main content CTAs → cards → footer links.
3. No element silently skipped. No focus trap (except intentional modals with proper escape handling).
4. Every focused element has a clearly visible ring.
5. Toggle dark mode → tab again → ring color switches, still clearly visible against the dark background.
6. Repeat on every major route/page.
7. Confirm route changes reset focus to the top (next Tab hits skip-link again).

### Form Check

- Tab into every form input — focus indicator visible
- Submit with Enter works
- Error states show `aria-invalid` and linked error messages

### Automated Smoke Test

Run axe DevTools or Lighthouse accessibility audit. Treat the score as a smoke test — it catches obvious regressions but is not a substitute for the manual keyboard walkthrough above.

---

## Phase 4 — Report

Output a structured summary:

```
## Accessibility Audit Report — [Page/Project Name]

### Focus System       [PASS / BUILT / NEEDS WORK]
...

### Skip Link          [PASS / ADDED / MISSING]
...

### Keyboard Nav       [score /10]
✅ ...
⚠️ ...
❌ ...

### Semantic HTML      [score /10]
✅ ...
⚠️ ...
❌ ...

### ARIA               [score /10]
✅ ...
⚠️ ...
❌ ...

### SPA Focus Reset    [PASS / FIXED / N/A]
...

---

### Changes Made
- [list of files modified or created, with one-line description]

### Still Needs Human Attention
- [items requiring manual testing, content decisions, or visual design review]

### Conventions to Document
- [rules to add to AGENTS.md / CLAUDE.md / project docs so future contributors maintain these patterns]
```

---

## Notes & Edge Cases

- **Tailwind projects**: The focus ring system maps to Tailwind's `ring-*` utilities. Check for `outline-none` in the base layer and replace with `focus-visible:ring-2 focus-visible:ring-[token]` or equivalent.
- **Component libraries (Radix, Headless UI, shadcn)**: These often handle ARIA internally. Audit their rendered output rather than the source — check that `aria-expanded`, `aria-selected`, etc. actually appear in the DOM.
- **CSS-in-JS (styled-components, Emotion)**: Focus resets might be buried in a `createGlobalStyle` or theme object. Search for `outline` across all style definitions.
- **Next.js App Router**: Route-change focus reset goes in a client component wrapping `usePathname()`. The skip-link target goes on the `<main>` in `app/layout.tsx`.
- **Color contrast of focus ring**: If the project's brand palette doesn't include a color that passes AA on both light and dark surfaces, pick the closest passing color and document the override. Don't sacrifice visibility for brand consistency.
- **The three traps to watch for**:
  1. Setting `border-radius` in the global focus rule changes element shape on focus — don't do it.
  2. Cards with `overflow: hidden` clip the inner element's outline — move the ring to the parent via `:has(:focus-visible)`.
  3. Skip-link using `:focus` instead of `:focus-visible` reveals on mouse click — use `:focus-visible` only.
