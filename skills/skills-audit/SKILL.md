---
name: skills-audit
description: >
  Review every skill in ~/dotfiles/skills against the skill-authoring best practices and
  the house style, report findings per skill, then standardize frontmatter, structure and
  wording — audit, fix, and verify, not just a report. Use when the user wants to review,
  audit, lint, standardize, or clean up their skills, asks whether a SKILL.md follows best
  practices, or after adding or editing a skill.
---

# Skills Audit

Bring every `<skill>/SKILL.md` in the collection up to the same standard: valid per the
spec, aligned with the distilled best practices, and written in the house style. Findings
are reported first; files are only edited after an explicit yes.

Two references drive the review — read both fully before judging anything:

- `../skill-best-practices-sync/references/best-practices.md` — the upstream rubric
  (MUST/SHOULD, source-tagged). Owned by the `skill-best-practices-sync` skill.
- `references/house-style.md` — the local conventions (layout, frontmatter shape,
  section order, tone).

## Hard rules (never violate)

1. Never change what a skill *does*. Standardize frontmatter, structure, wording and
   layout; leave behavior, tool choices and guardrails as they are. A behavioral
   suggestion goes in the report under "Needs your call", not into the file.
2. Never weaken a description's trigger phrases. They drive discovery; rewording them is
   a judgment call for the user.
3. Never edit a skill without showing the proposed change first and getting a yes.

## Phase 0 — Confirm the rubric is current

Run: `python3 ../skill-best-practices-sync/scripts/sync_sources.py check`

- All `UNCHANGED` → continue.
- Any `CHANGED` / `NEW` → tell the user the rubric may be stale and offer to run the
  `skill-best-practices-sync` skill first. Continue with the current digest if they decline.
- `FETCH-ERR` (offline) → note it in the report and continue.

## Phase 1 — Mechanical lint

Run: `python3 scripts/lint_skills.py`

Add `--skill <name>` (repeatable) to scope to one skill, `--json` for machine output.
Severities: `error` = spec violation, `warn` = checkable SHOULD from the digest,
`style` = house-style deviation, `info` = cross-skill observation (naming mix, description
style mix). Keep the output; it is the skeleton of the report.

The linter does not judge prose. Phase 2 does.

## Phase 2 — Read and judge

Read each `SKILL.md` in full (plus any `references/` and `scripts/` it bundles) and answer,
per skill, citing line numbers:

- **Conciseness**: which sentences explain something the model already knows? Which
  paragraphs would the skill work without?
- **What + when**: does the description say both, front-loaded, in third person, with the
  phrases a user would actually type?
- **Defaults, not menus**: any place offering several tools or approaches as equals?
- **Specificity vs fragility**: are fragile steps prescriptive (exact command, "do not
  add flags") and open-ended steps left free? Any step over- or under-specified?
- **Procedures over declarations**: does it teach the approach, or hard-code one answer?
- **Verification loop**: is there a check-fix-recheck step before the report?
- **Terminology**: one term per concept throughout?
- **Progressive disclosure**: anything long enough to move to `references/` with a clear
  "read this when…"? Any bundled file that SKILL.md never tells the model when to open?
- **House style**: title, opening paragraph, `Phase N —` sections, `Report` template,
  `Notes & edge cases` last, ~90-column wrap — per `references/house-style.md`.

Then look across the collection: are names one pattern? Do descriptions share one
shape? Do the same section names mean the same thing everywhere?

## Phase 3 — Report

Print in the chat response. Do not write files yet.

```
## Skills audit — <N> skills

| skill | errors | warns | style | verdict |
|-------|--------|-------|-------|---------|
| …     |        |       |       | clean / needs fixes |

### <skill-name>
- **Fix** `<rule>` <what and where> → <proposed change, one line>
- **Needs your call** <behavioral or trigger-phrase suggestion, with the reason>

### Across the collection
- <naming / description-shape / section-name consistency findings + the proposed standard>

### Rubric status
<UNCHANGED for all sources | stale: … | offline>
```

End with: "Apply the **Fix** items? (all / pick skills / none)".

## Phase 4 — Apply

Only after a yes. For each approved skill:

1. Edit `SKILL.md` in place. Keep every trigger phrase; keep every hard rule; keep the
   content order unless the fix *is* the order.
2. Prefer the smallest diff that satisfies the rule: reflow a description into `>` form,
   rename `Step N —` to `Phase N —`, add a missing `## Phase N — Verify`, wrap long prose
   lines.
3. When a skill's body is near the line budget, move the largest self-contained block
   into `references/<descriptive-name>.md`, add a Contents list if it exceeds 100 lines,
   and link it from SKILL.md with a "read this when…" sentence.
4. Update `references/house-style.md` if the user chose a new collection-wide standard
   (naming form, description opener) so the next audit enforces it.

## Phase 5 — Verify

1. `python3 scripts/lint_skills.py` → zero errors; every previously reported finding that
   was approved is gone; no new findings introduced.
2. Re-read each edited description once more as a discovery signal: would the skill still
   trigger on every phrase it triggered on before?
3. `git -C ~/dotfiles diff --stat skills/` — only the approved skills changed.

Report what was applied, what was skipped and why, and what remains in "Needs your call".

## Notes & edge cases

- **Single skill**: when the user names one skill (or just added one), scope Phases 1–5 to
  it with `--skill <name>`, but still run the collection-level checks so it matches its
  neighbors.
- **This skill and `skill-best-practices-sync` are in scope too.** Audit them like the
  rest; do not exempt them.
- **Cross-skill path**: `../skill-best-practices-sync/…` resolves because both skills live
  in `~/dotfiles/skills` and are symlinked side by side into `~/.claude/skills`. If the
  path fails, run from `~/dotfiles/skills/skills-audit`.
- **`disable-model-invocation: true`** is deliberate on skills the user wants to trigger
  manually — never remove it as a "cleanup".
- **Descriptions shorter than the house shape** (e.g. `context7-mcp`): reshaping into
  "verb + what — Use when …" is a Fix; adding *new* trigger phrases is Needs-your-call.
- **Style findings are not failures.** A skill may deviate deliberately; say so in the
  report and move on when the user confirms.
- **Commits**: do not commit; the user decides when the dotfiles repo gets a commit.
