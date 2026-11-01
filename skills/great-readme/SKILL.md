---
name: great-readme
description: >
  Rewrite or audit an open source README with the GREAT README formula — product-page
  hero, business why, 5-minute quick start, a C1 context diagram, and Claude-drawn
  light/dark SVGs instead of Mermaid. Use when the user runs /great-readme.
disable-model-invocation: true
---

# GREAT README

A README is a landing page and a short design doc in one. It must answer, in order:
**what is this, why should I care, how do I try it in 5 minutes, how does it work and why
was it built this way.** Business story first, then the tech.
Delivered as a PR per repo; the default branch is never touched.

## Hard rules (never violate)

1. Never describe what the code doesn't do.
2. Never push to the default branch, and never push or open a PR without an explicit yes
   from the user (unattended runs excepted).
3. Never ship a hero with a broken image or a placeholder, and never present a mockup or
   generated image as a screenshot of the real product.
4. Never put a Roadmap, status or Sustainability/business-model section in the README.
5. Ask before running anything on the user's computer.

## Phase 0 — Audit the repo

Before writing, read the current README, package metadata (`package.json`,
`pyproject.toml`, `Package.swift`…), CI workflows, LICENSE, `docs/`, existing
logos/screenshots, the live URL, and enough source to verify every claim (entry points,
workflow/graph definitions, schedules).

**Keep what's already good.** Preserve accurate prose, design principles, tables and
links. Change structure and missing pieces, not the author's voice.

## Phase 1 — Ask about gaps

Some gaps are the user's decision, not the README's. After the audit and before writing,
ask about every gap you found in **one round** (the question tool, max 4 questions; group
the rest), each with 2–4 concrete options derived from the repo, the recommended one first
and marked "(Recommended)". Typical gaps and how to build the options:

| Gap | Options to offer (pick defaults from the repo) |
|---|---|
| **No LICENSE** | The license the owner uses in sibling repos or `package.json` `license` field (recommended when found); MIT for small tools and libraries; Apache-2.0 for apps/agents with integrations; "All rights reserved" (proprietary). Answer → add the LICENSE file with the owner's name and year, plus the badge. |
| **No logo** | Reuse an existing mark found nearby (name the file, e.g. a sibling app's icon); design 2–3 options with Claude; ship with the inline-title hero for now. |
| **No OG image** | Design one with Claude (recommended for apps and sites); use a real screenshot instead; ship with no visual for now. |
| **No product screenshot** (and no OG image) | Capture it myself (web app/Storybook, say from where); the user sends one (say exactly which screen and state); take it via computer use on their machine; ship without for now. |
| **Unverifiable live URL** | Use the URL found (say where it came from: GitHub homepage, config); a different URL; no live link. |
| **Recommended doc missing** (`SECURITY.md`, `CONTRIBUTING.md`) | Create it now (say what it would contain); skip. |
| **No releases / CI** | Skip the badge (recommended); set it up in a separate PR. |

If nobody can answer (unattended run), take the recommended option, say so in the PR
description, and keep the rendered README free of any mention of the gap.

## Phase 2 — Write the hero

The hero is the first screen, written in the reader's voice (see "Voice" in Phase 3).

**Logo on the left, never centered.** Preferred layout: logo floated left, with the name,
the one-liner and the badges stacked in a column to its right; the link row and the
OG image go full width below.

```html
<img src="docs/assets/logo.svg" width="164" align="left" alt="<Name> logo: <what it depicts>">

# <Name>

**<One sentence: what it does, for whom, with one concrete number or differentiator.>**

<badges: max 6, health first, then stack, all on one line>

<br clear="left">

[**Live site**](<url>) · [How it works](#how-it-works) · [Architecture](#architecture) · [Quick start](#quick-start)

<img src="<path to the OG image>" alt="<the OG image's text, written out>" width="860">
```

- The column only works if it is **no taller than the logo**: one-liner ≤ 2 lines at
  GitHub width (~120 characters), badges on one line. Size the logo (140–180px) so the
  column fits beside it; never let the one-liner wrap under the logo.
- `<br clear="left">` is required, or the link row floats beside the logo.
- **Fallback** when the logo is wide, not square, or the column can't fit: logo inline
  in the title, then the rest stacked, all left-aligned:
  `# <img src="docs/assets/logo.svg" width="44" align="top" alt="…"> <Name>`
- Dark mode: use a logo that works on both backgrounds (an app-icon tile is ideal); if
  it can't, wrap it in `<picture>` with a `prefers-color-scheme: dark` source.
- Check the hero in the GitHub preview (light and dark) before committing.

Rules:
- **One-liner** leads with the outcome, not the implementation. If the repo serves a
  bigger initiative (a live-coding series, a product family), the one-liner is still about
  *this* repo; context goes in the next paragraph.
- **Badges**, same shields.io style, max 6. Order: **health** (CI, coverage, version or
  latest release, license) → **stack** (`built with`, `LLM`, runtime/platform). Health
  badges must link somewhere real. Stack badges are part of the tech showcase.
- **Link row** works as a table of contents: live/website/download · docs or Storybook ·
  how it works · architecture · quick start · deploy/releases.
- **Visual = the project's OG image** (the social preview its site already uses): find it
  through the `og:image` meta tag in the site code (`og/*.png`, `public/landing/*/og.png`,
  `docs/assets/og-image.png`…) and reference that file directly, so the README and the
  link preview stay in sync. Its logo and name repeating the header is fine. Write the
  image's text out in the alt text. Don't add separate screenshots or banners next to it.
- No OG image (libraries, UI kits, CLIs): use a real product visual instead (a rendered
  component grid, the app in use), and ask whether to design an OG image (see Phase 1).
- Nothing critical lives only inside an image: the tagline is also in text (one-liner or
  alt text).

### Missing hero assets

During the audit, check for a logo (favicon, app icon, `public/`, `assets/`, `docs/`) and
an OG image (then a product visual). When one is missing, ask using the Phase 1 options;
the table below says how to carry out each. If the answer is to add it later, leave a
one-line HTML comment slot
(`<!-- Logo slot: add … then uncomment -->`) and the commented-out tag; nothing about it
appears in the rendered README.

| Missing | How to get it |
|---|---|
| **OG image** | Offer to design one with Claude (a design artifact, 1200×630, logo + tagline + 2–3 feature chips, matching the site), saved where the site serves it so the site can use it too. |
| **Screenshot of a web app or site** (no OG image) | Capture it yourself: Playwright against the live URL or a local dev server, 1440×900 at 2x, light theme, real data showing the outcome (not an empty state). Save to `docs/assets/`. |
| **Screenshot of a UI kit / library** | Run Storybook (or a demo page) locally and capture a grid of the key components; or a short code sample plus its rendered output. |
| **Screenshot of a native or desktop app** | Ask the user for one, telling them exactly which screen and state to capture; or, with their OK, take it through computer use on their machine. |
| **Logo / app icon** | Offer to design an original mark with Claude: a simple SVG (a design artifact in chat, or hand-written SVG here), square app-icon tile so it sits well on the left of the hero, readable at 32px, working on light and dark. Suggest 2–3 directions tied to what the product does and let the user pick. Use an existing app icon or favicon when there is one. |

No third-party logos, characters or brand marks in a generated logo.

## Phase 3 — Write the sections

Write the sections in the fixed order below.

### Voice

The README is written for a person who wants to learn about the project, not as notes from
an agent to the developer.

- **The README never talks about itself or its own files.** No "this section explains…",
  "diagram sources live in…", "images are kept in X so they aren't published", "this README
  covers…". Where files live belongs in Project layout only if a reader needs it.
- **No excuses or absence notices.** Don't announce what doesn't exist ("there is no CI
  yet", "no license file has been added", "no screenshot available"). Omit it, or ask and
  add it (see Phase 1).
- **Name the owner.** Copyright and credits use the person's name:
  "© <year> <owner name>. All rights reserved.", not "default copyright applies".
- **State decisions as facts about the project**, not as instructions or justifications
  ("Timepass talks only to macOS", not "this diagram shows who uses it…"). Contributing may
  address contributors directly ("run `make build`"), but never with internal to-dos.
- Findings that need the user's action (a failing test, an undeclared dependency, an old
  name in config) go in the PR description, never in the README.

### Sections (fixed order)

1. **Hero** (Phase 2)
2. **Why** — the problem from the user's pain (2–4 sentences), who it's for and not for,
   what it does differently, traction if real. Optional **Design principles** table
   (principle → in practice) when the project has opinions worth showing.
3. **Quick start** — prerequisites stated, copy-paste commands that succeed on a clean
   machine, the smallest working example. Long variants go in `<details>`.
4. **How it works** — the mechanism in markdown prose and small tables.
5. **Architecture** — the **C1 system context diagram, always**, followed by 2–3 short
   markdown paragraphs and a link to `docs/ARCHITECTURE.md` when deeper diagrams exist.
   Then a one-line **Tech stack** grouped by layer.
6. **Usage / configuration** — the 80% cases inline; everything else linked to `docs/`.
   Include a short **Project layout** tree when the repo has more than a handful of
   top-level folders.
7. **Documentation** — a two-column table (Doc | What's in it) of the docs that exist
   (see "Docs to reference"). Mark docs written in another language, e.g. "(Spanish)".
8. **Contributing** — how to add the common thing (a country, a component, a timezone),
   which command validates it, what CI runs. Link `CONTRIBUTING.md` if it exists.
9. **License** — license plus data/asset attributions.

Roadmap, status and Sustainability/business-model sections go stale, and the real roadmap
lives in the user's own tooling. If the README already has one, remove it (also from the
link row and any TOC) and list the removal in the PR description. Don't move it to another
doc or replace it with a link.

Keep the README under ~400 lines. Prose is short and scannable markdown; tables for
comparisons and step-by-step mechanics; bold sparingly.

### Docs to reference

Link only docs that exist and say something; never link an empty template. Create a
missing one only when the repo clearly needs it, and say so in the PR.

| Doc | Link it when |
|---|---|
| `docs/ARCHITECTURE.md` | there is anything below C1: containers (C2), process maps, modules |
| `CONTRIBUTING.md` | the repo takes outside contributions (setup, conventions, PR flow) |
| `docs/SETUP.md` / `DEPLOY.md` | someone can self-host or deploy their own instance |
| `docs/adr/` | decisions are recorded; the best tech-showcase material a repo has |
| `CHANGELOG.md` or GitHub Releases | the project is versioned (semantic-release, app releases) |
| `SECURITY.md` | it handles auth, money, credentials or personal data |
| `CODE_OF_CONDUCT.md` | there is a community (issues, Discussions, streams) |
| Methodology / data sources page | it's a data product: how numbers are collected and computed |
| API docs, Storybook, typedoc | it's a library or UI kit |
| Sub-package READMEs (`web/README.md`, `packages/*/README.md`) | it's a monorepo |
| `LICENSE` | always (badge + License section) |

Where they appear: the important ones in the hero link row (Docs/Storybook, Deploy);
contextually inside sections (Architecture → `ARCHITECTURE.md`, Quick start → `SETUP.md`);
all of them in the Documentation table.

## Phase 4 — Draw the diagrams

### 4.1 Decide what to draw

Answer this prompt against the code you actually read, before drawing anything:

> If you had to describe this in modules, a conceptual architecture, or a process map
> with data flows, how would you represent the current state and requirements of this?

From the answer pick diagrams by C4 level, each with one job:
- **C1 system context — required, goes in the README.** The system as one box in the
  center; people above it (pill-shaped); external systems below it (third-party APIs,
  data sources, LLMs, app stores). Each edge has a ≤4-word verb label ("fetches prices
  daily", "accepts findings in PRs"). No internals.
- **C2 containers** (what runs where) → `docs/ARCHITECTURE.md`: runtimes/hosts as
  containers, deployable units inside, people and external systems outside.
- **Process map** per important flow → `docs/ARCHITECTURE.md`: the real step names from
  the code, in order, with the data stores they hand off through.
- **Modules** (C3) → `docs/ARCHITECTURE.md`, only when the internal layering is the
  story (atoms → molecules → organisms, core → adapters).

Small projects (a menu bar app, a UI kit) usually need C1 only, and no
`ARCHITECTURE.md`. Don't invent a pipeline to fill space.

**Diagrams carry labels, never prose.** Inside an SVG: box titles, ≤5-word subtitles,
≤4-word edge labels, container names. Legends, notes, captions and explanations are
markdown around the image, never text in the SVG.

### 4.2 Draw one themeable SVG per diagram

Write `docs/diagrams/src/<name>.svg` by hand in Claude's diagram style, no Mermaid. Use only
the classes below: no inline colors, no `<style>`, no web fonts; the bake script adds them.

- Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 H" width="880" role="img">`
  then `<title>` and `<desc>` (one-sentence summary for screen readers).
- `<defs>`: marker `a` with `<path class="mk" d="M2 1L8 5L2 9"/>` and marker `al` with
  `<path class="mk e-coral" …/>` (viewBox `0 0 10 10`, refX 8, refY 5, markerWidth/Height
  7, `orient="auto-start-reverse"`).
- **Container**: `<g class="ct-{ramp}"><rect … rx="16"/>` + `.th` title and `.ts`
  subtitle top-left (x = left + 22). Add `dash` for logical groupings (`ct-purple dash`).
- **Node inside a container**: `<g class="n-{ramp}"><rect … height="50|56" rx="8"/>` +
  title + subtitle. **Standalone node** (outside containers): `s-{ramp}`.
  **People** are pills: `rx` = half the height.
- **Text**: `.th` = 14px title, `.tm` = 13px monospace title for code identifiers
  (function, file, job and package names), `.ts` = 12px subtitle and edge label. Always
  `text-anchor="middle" dominant-baseline="central"` inside boxes. Sentence case.
- **Edges**: `<path class="arr" d="M… H… V…" marker-end="url(#a)"/>`; orthogonal segments
  only. LLM/third-party-model calls: `class="arr llm e-coral"` + `url(#al)`.
- Ramps: purple, teal, coral, pink, gray, blue, green, amber, red. Use color for meaning,
  2–3 ramps per diagram + gray, consistently across a repo: one ramp per runtime/host,
  **coral dashed = LLM call**, gray = people, external systems and storage handoffs.
  Explain what colors and dashes mean in a markdown sentence, not in the SVG.

Layout rules (these are where diagrams break):
- 880 wide; safe area x 30–850. Boxes 165–220 wide, 20–40px gaps, ≥40px between rows.
  Max 4 boxes per row; longer flows wrap as a snake with an L-shaped connector
  (`M{x} {bottom} V{mid} H{x0} V{top}`).
- Box width ≥ max(title chars × 8, subtitle chars × 6.5) + 24. Subtitles ≤ 5 words.
- No line crosses a box or a label. Arrows that enter a container land at an x clear of
  the container's title/subtitle (keep container subtitles short so a drop at x ≈ 195
  is clear).
- Paths that pass over a container are written **after** that container in the file.
- Height = lowest element + ~20.

### 4.3 Bake and check

Run from the target repo's root:

```bash
python3 <skill-directory>/scripts/theme_svg.py docs/diagrams/src/*.svg --out docs/diagrams --png
```

It writes `<name>-light.svg` / `<name>-dark.svg` with colors and system fonts baked in
(GitHub renders README SVGs as `<img>`: no CSS variables, no web fonts) and, with
`--png`, previews loaded as `<img>` exactly like GitHub. **Look at every PNG** and fix
overlaps, clipped text, or arrows through boxes before moving on. Delete the PNGs before
committing.

`--png` needs Playwright and Chromium: `pip install playwright`, then
`playwright install chromium`.

### 4.4 Embed

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/<name>-dark.svg">
  <img src="docs/diagrams/<name>-light.svg" alt="<the whole flow in one sentence>" width="880">
</picture>
```

The text around each diagram is plain markdown: what it answers before it, the
non-obvious rule it shows after it. Paths in `docs/ARCHITECTURE.md` are relative to
`docs/` (`diagrams/<name>-dark.svg`, `../src/...`). Don't mention where diagram sources
live. Name sources after what they show: `context.svg` (C1), `containers.svg` (C2),
`<flow>.svg` for process maps. If `docs/` is a published site (GitHub Pages, `docs/CNAME`),
put diagrams and README images in `.github/readme/` instead, without explaining why.

## Phase 5 — Verify

Run this checklist, fix whatever fails, and rerun it until every item passes. An item that
can't pass goes in the PR description, never in the README.

- No Roadmap, status or Sustainability section anywhere in the README.
- Voice: nothing in the rendered README talks about the README, its files or its diagrams;
  no "yet"/"no X" absence notices; copyright names the owner.
- Every gap was asked about (or the recommended default was taken and listed in the PR).
- Logo on the left; the column beside it doesn't wrap under the logo (or the inline-title
  fallback is used).
- Hero has a real logo and the project's OG image (or a real product visual when there is
  no OG image), or the user was asked how to fill the gap (no broken images, no
  placeholders presented as final).
- Every number, schedule, command and file path in the README exists in the repo.
- Quick start commands run (execute them when the toolchain is available).
- All relative links and image paths resolve; badge URLs point at real workflows.
- Diagram step names match the code; no prose inside any SVG; light and dark previews
  checked; C1 is in the README.
- Render the README and `docs/ARCHITECTURE.md` (when it exists) like GitHub and show the
  screenshots to the user before opening the PR. Run from the target repo's root:
  ```bash
  python3 <skill-directory>/scripts/render_readme.py README.md docs/ARCHITECTURE.md --out "$TMPDIR/readme-preview"
  ```
  It writes `<name>-light.png` / `-dark.png`, draws stand-in badges if shields.io is
  unreachable, and exits 1 listing images that failed to load. Needs npm, plus
  `pip install markdown playwright` and `playwright install chromium`. Lists nested by 2
  spaces look flat here (Python-Markdown, not GitHub's parser) but nest on GitHub: leave them.

## Phase 6 — Deliver

When the checklist passes, wait for the user's explicit yes on the screenshots before
pushing or opening the PR; on an unattended run, skip the wait. Deliver on a branch
(`docs/great-readme`) with a PR per repo. Never push to the default branch. One commit for
diagrams, one for the README.

## Report

Print this in the chat response. The PR description carries the same gaps, removals and
findings.

```
## GREAT README — <repo>

PR: <url>

### Changes made
- <sections rewritten or kept, diagrams added>
- Removed: <Roadmap, status or Sustainability sections, if any>

### Gaps
- <gap>: <option taken, and whether it was asked or the recommended default>

### Still needs human attention
- <failing test, undeclared dependency, old name in config, checklist item that can't pass>
```
