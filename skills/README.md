# Skills

Agent skills symlinked into Cursor and Claude from `~/dotfiles/skills`.

## Install

```bash
make slink-skills
```

This links every skill in this folder into both `~/.cursor/skills-cursor` and `~/.claude/skills`.

Individual targets: `make slink-skills-cursor`, `make slink-skills-claude`.

## Keeping skills consistent

- `skill-best-practices-sync` — refreshes the local copies of the upstream skill-authoring
  guides (Anthropic, agentskills.io, OpenAI) and the distilled rubric in
  `skill-best-practices-sync/references/best-practices.md`.
- `skills-audit` — reviews every skill here against that rubric and
  `skills-audit/references/house-style.md`, then standardizes them.
  Quick mechanical check: `python3 skills-audit/scripts/lint_skills.py`.
