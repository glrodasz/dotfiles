---
name: skills-social
description: >
  Regenerate a shareable JSON catalog of the user's skills — one entry per skill in
  ~/dotfiles/skills with a category, a short tagline, a trigger phrase and its slash
  invocation, ready to render as a social-media card. Use when the user wants to refresh,
  update, regenerate, share, or export their skills list, asks for the skills social media
  JSON or skills catalog JSON, or wants a shareable overview of the skills they have built.
---

# Skills Social JSON

Read every skill in the skills folder and write a catalog JSON built for sharing: one
entry per skill, each with a fixed category, a one-line tagline, the moment you would
reach for it, and its slash invocation. Never edit a `SKILL.md` — this skill writes
exactly one file.

## Inputs

Defaults; each is overridable by invocation args.

- **Skills root**: the directory containing this skill — `~/dotfiles/skills`
- **Source of truth**: `<root>/*/SKILL.md`. Enumerate those directories, never the
  symlinks in `~/.claude/skills` or `~/.cursor/skills-cursor` — those go stale when a
  skill is renamed
- **Output**: `<root>/skills-social.json`
- **Author**: `git config user.name` — never hardcode

## Phase 1 — Collect the skills

1. List every `<root>/*/SKILL.md`. Each one is an entry, including `skills-social` itself.
2. Read the `name` and `description` frontmatter of each. `name` must equal the directory
   name — report a mismatch rather than silently trusting either.
3. Note any skill carrying `disable-model-invocation: true`; its `trigger` says when the
   user runs it, not when it fires automatically.

## Phase 2 — Categorize

Assign exactly one category from this fixed vocabulary, so the rendered image can
color-code consistently. Do not invent a new value — widen an existing category instead.

| category | covers | current members |
| --- | --- | --- |
| `git-workflow` | branches, commits, PRs | `reviewable-commits`, `stacked-pr-splitter`, `branch-test-plan` |
| `code-quality` | how code gets written and changed | `branch-comment-cleanup`, `minimal-code-changes` |
| `web-audit` | shipping a page or site | `a11y-page-audit`, `prod-page-audit` |
| `tooling` | environment, docs, config plumbing | `context7-mcp`, `env-example-sync` |
| `meta` | skills and dotfiles about themselves | `skills-audit`, `skill-best-practices-sync`, `shell-aliases-social`, `skills-social` |

## Phase 3 — Write the taglines

Rewrite each frontmatter description into image copy. The frontmatter is trigger bait for
the model — never copy it verbatim.

- `description`: one sentence, at most 80 characters, present tense, stating the outcome
  ("Turns a branch diff into a manual QA plan"). No "Use when…", no "This skill".
- `trigger`: at most six words naming the moment ("before opening a PR"). Lowercase, no
  trailing period.
- `invocation`: `/<name>`.

## Phase 4 — Write the JSON

```json
{
  "meta": {
    "author": "<from git config user.name>",
    "source": "~/dotfiles/skills",
    "generated": "YYYY-MM-DD",
    "count": 13
  },
  "entries": [
    {
      "name": "branch-test-plan",
      "category": "git-workflow",
      "description": "Turns a branch diff into a manual QA plan with regression checks",
      "trigger": "before opening a PR",
      "invocation": "/branch-test-plan"
    }
  ]
}
```

Sort `entries` by category in the vocabulary order above, then by `name`, so regenerating
produces a stable diff. Two-space indent, trailing newline.

## Phase 5 — Verify

1. Valid JSON: `python3 -c "import json;json.load(open('skills-social.json'))"`.
2. `meta.count` equals the number of `entries` equals the number of `*/SKILL.md`
   directories under the root.
3. Every `category` is in the fixed vocabulary, and no `description` exceeds 80
   characters.
4. No private paths, hostnames, project IDs or credentials leaked out of any `SKILL.md` —
   the output is committed to a public repo.

## Report

Compare against the previous version of the file and print:

```
## Skills social — <date>

### Added
- <skill — category assigned>

### Removed
- <skill — no longer in the folder>

### Updated
- <skill — what changed: category, tagline, or trigger>

### Still needs human attention
- <name/directory mismatches, skills that resisted a one-line tagline>
```

## Notes & edge cases

- **A skill fits no category**: widen the closest category's scope rather than adding a
  value; add one only when three or more skills would share it, and say so in the report.
- **Stale symlinks**: `~/.claude/skills` can hold dangling links to renamed skills — never
  enumerate from there.
- **Self-inclusion**: `skills-social` appears in its own output.
- **Image generation**: out of scope. The JSON is the deliverable, mirroring
  `zsh/shell-aliases-social.json` and the image rendered from it.
