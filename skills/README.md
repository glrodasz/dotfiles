# Skills

Agent skills symlinked into Cursor and Claude from `~/dotfiles/skills`.

## Install

```bash
make slink-skills
```

This links every skill in this folder into both `~/.cursor/skills-cursor` and `~/.claude/skills`.

Individual targets: `make slink-skills-cursor`, `make slink-skills-claude`.

## Local skills

Private or machine-specific skills go in `~/.skills.local/<name>/SKILL.md`. It works like
`~/.zshrc.local`: the folder lives outside this repo, so it is never committed, and every
step treats it as optional.

- `make slink-skills` links them next to the repo skills (shown as `linked <name> (local)`).
- `skills-audit` and `lint_skills.py` lint, read and fix them along with the rest.
- `skills-social` leaves them out.
- A local skill must not reuse a repo skill's name (lint error `XS003`).

## Keeping skills consistent

- `skill-best-practices-sync` — refreshes the local copies of the upstream skill-authoring
  guides (Anthropic, agentskills.io, OpenAI) and the distilled rubric in
  `skill-best-practices-sync/references/best-practices.md`.
- `skills-audit` — reviews every skill here against that rubric and
  `skills-audit/references/house-style.md`, then standardizes them.
  Quick mechanical check: `python3 skills-audit/scripts/lint_skills.py`.

## Sharing

- `skills-social` — regenerates `skills-social.json`, a shareable catalog of every skill
  here (category, tagline, trigger), for rendering a social-media card.
