---
name: skill-best-practices-sync
description: >
  Check whether the local copies of the skill-authoring best-practice docs (Anthropic,
  agentskills.io, OpenAI) still match the live pages, refresh the ones that changed, and
  fold the changes into the distilled best-practices digest. Use when the user wants to
  check, refresh, update, or sync skill best practices, asks whether the skill guidelines
  are up to date, or before running a skills audit.
---

# Skill Best Practices Sync

Keep `references/best-practices.md` — the rubric the `skills-audit` skill applies — faithful
to its upstream sources. Sources, their fetch URLs, hashes and fetch dates live in
`references/sources.json`; verbatim copies live in `references/sources/<slug>.md`.

"Up to date" means *content unchanged*, not *fetched recently*: none of the upstream pages
expose a version or last-updated date, so the script compares normalized text hashes.

## Phase 0 — Check

Run: `python3 scripts/sync_sources.py check`

One row per source: `UNCHANGED`, `CHANGED`, `NEW`, or `FETCH-ERR`. Exit code 1 means at least
one source differs. If every row is `UNCHANGED`, report that and stop — nothing else to do.

`FETCH-ERR` is not a change. Report it, keep the local copy, and continue with the others.

## Phase 1 — Update the local copies

Run: `python3 scripts/sync_sources.py update`

For each changed source the script prints a unified diff (local → live), overwrites
`references/sources/<slug>.md`, and records the new hash and timestamp in `sources.json`.
Read every diff in full — the diffs are the input to Phase 2.

To preview without writing: `python3 scripts/sync_sources.py diff [slug]`.

## Phase 2 — Fold changes into the digest

`references/best-practices.md` is a distilled rubric with a source tag on every rule
(`[A]` Anthropic, `[S]` agentskills.io, `[O1]` OpenAI build-skills, `[O2]` OpenAI Codex
guide). For each diff hunk decide:

- **New or changed rule** → add or edit the rule under the matching section, keep the tag.
- **Removed rule** → remove it, or drop the tag if another source still states it.
- **Wording-only / navigation / marketing change** → no digest edit.
- **Two sources now disagree** → record it under "Where the sources differ" with both positions.

Keep the digest's shape: MUST for hard validation rules, SHOULD for judgment calls, one line
per rule, tags on every line. Do not paste source prose in; distill it.

## Phase 3 — Verify

1. `python3 scripts/sync_sources.py check` → all `UNCHANGED`.
2. Every rule you touched in the digest still carries a source tag, and the tag's source
   actually says it (grep the source file).
3. `references/best-practices.md` still opens with its Contents list and stays under
   ~250 lines.

## Report

```
## Best-practices sync — <date>

| source | status | lines changed |
|--------|--------|---------------|

### Digest changes
- <rule added / changed / removed, with tag>

### Not folded in (and why)
- <hunk that was navigation noise, marketing, etc.>
```

If nothing changed: a one-line "All <N> sources unchanged since <last fetched_at>."

## Notes & edge cases

- **Adding a source**: append an entry to `sources.json` (`slug`, `title`, `url`,
  `fetch_url`, `format`, `relevance`, `notes`, `sha256: null`, `fetched_at: null`), pick a
  new tag letter for the digest, run `update <slug>`, then distill it into the digest.
- **Markdown endpoints**: `platform.claude.com`, `agentskills.io` and
  `learn.chatgpt.com/docs/*` serve raw markdown via a `.md` suffix. Always prefer that over
  HTML — it diffs cleanly.
- **HTML fallback**: `format: "html"` runs a minimal HTML→text conversion scoped to
  `<article>` (then `<main>`). If a page redesign floods the diff with navigation text,
  fix the extractor in `scripts/sync_sources.py`, not the digest.
- **Noisy diffs**: whitespace is normalized before hashing. If a source still flips
  between runs with no meaningful change (nonces, timestamps), add a normalization rule
  in `normalize()` rather than ignoring the source.
- **`[O2]` is low relevance**: only its skills, `AGENTS.md`, and common-mistakes sections
  matter. A big diff there is usually not a digest change.
- **Commits**: do not commit; the user decides when the dotfiles repo gets a commit.
