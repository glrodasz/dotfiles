# SVG Diagram Spec

Hand-written, themeable SVG format for the diagrams in Phase 4.2.

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
  2-3 ramps per diagram + gray, consistently across a repo: one ramp per runtime/host,
  **coral dashed = LLM call**, gray = people, external systems and storage handoffs.
  Explain what colors and dashes mean in a markdown sentence, not in the SVG.

Layout rules (these are where diagrams break):
- 880 wide; safe area x 30-850. Boxes 165-220 wide, 20-40px gaps, ≥40px between rows.
  Max 4 boxes per row; longer flows wrap as a snake with an L-shaped connector
  (`M{x} {bottom} V{mid} H{x0} V{top}`).
- Box width ≥ max(title chars × 8, subtitle chars × 6.5) + 24. Subtitles ≤ 5 words.
- No line crosses a box or a label. Arrows that enter a container land at an x clear of
  the container's title/subtitle (keep container subtitles short so a drop at x ≈ 195
  is clear).
- Paths that pass over a container are written **after** that container in the file.
- Height = lowest element + ~20.
