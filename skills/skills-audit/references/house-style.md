# House style for skills in `~/dotfiles/skills`

Local conventions layered on top of the upstream best practices. Derived from the most
recent, most consistent skills (`branch-test-plan`, `branch-comment-cleanup`,
`a11y-page-audit`). Where a rule here and the digest conflict, the digest wins.

## Layout

- One directory per skill: `<skill-name>/SKILL.md`. Optional `scripts/` (executed),
  `references/` (read on demand). No other top-level files.
- `name` equals the directory name.
- Skills are symlinked into `~/.claude/skills` and `~/.cursor/skills-cursor` by
  `make slink-skills`, so everything must be self-contained and path-relative.

## Frontmatter

- Fields: `name`, `description`, and only when the skill must never auto-trigger,
  `disable-model-invocation: true`. Nothing else.
- Names are kebab-case noun phrases naming the deliverable or target
  (`branch-test-plan`, `prod-page-audit`, `shell-aliases-social`). Verb-first names
  (`sync-env-example`) are the exception, not the pattern.
- `description` uses the YAML folded block (`description: >`) when it exceeds one line,
  wrapped at ~90 columns, indented two spaces.
- Description shape, in order:
  1. Imperative verb + what it does, one or two sentences. An em-dash clause sharpens the
     scope (`— audit, fix, and verify, not just a report`).
  2. `Use when the user …` / `Use whenever the user …` followed by the concrete phrases a
     user would type, comma-separated, quoted where they are literal questions.
- Third person, no "I", no "you can", no "This skill should be used when".

## Body

- Opens with `# <Human-Readable Title>` (Title Case), then one short paragraph stating the
  goal and the guardrail (what is never touched, what is never written to disk).
- Sections are H2, in this order when they apply:
  - `## Hard rules (never violate)` — numbered, only for skills that edit user files.
  - `## Phase 0 — <Scope / Understand the target>` … `## Phase N — Verify` — em-dash
    (`—`) separator, "Phase" not "Step", sentence-case titles.
  - `## Report` — followed by a fenced template the model fills in. Report templates
    typically contain `### Changes made`, `### Still needs human attention`.
  - `## Notes & edge cases` — bolded lead-in per bullet (`- **Big diffs**: …`). Always last.
- Substeps inside a phase are numbered lists; H3 only when a phase has named sub-areas
  (`### 1.2 Focus ring system`).
- Prose wraps at ~90 columns. Code, tables, and URLs are exempt.
- Commands are inline code with the exact invocation. Scripts are introduced with
  `Run:` (execute) or `See` (read as reference).
- Checklists use `- [ ]` inside a fenced block when the model should copy and tick them.
- Output goes to the chat response unless the skill's purpose is to write a file; any
  file write or external post is preceded by an explicit yes from the user.
- No "Old patterns" needed yet — none of the skills carry deprecated paths.

## Tone

- Terse, imperative, specific. No explanations of things the model already knows.
- Say what *not* to do where a plausible wrong turn exists ("no invented flows, no
  generic 'test the happy path' filler").
- Prefer a stated default over a menu of options.
