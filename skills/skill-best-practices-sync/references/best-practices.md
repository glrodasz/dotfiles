# Skill-authoring best practices — distilled digest

Rubric synthesized from the four upstream sources tracked in `sources.json`. Each rule
carries its provenance so a source change can be traced to the rule it affects:

- **[A]** Anthropic — Skill authoring best practices (`sources/anthropic-skill-authoring.md`)
- **[S]** agentskills.io — Best practices for skill creators (`sources/agentskills-best-practices.md`)
- **[O1]** OpenAI — Build skills (`sources/openai-build-skills.md`)
- **[O2]** OpenAI — Codex best practices, skills section only (`sources/openai-codex-best-practices.md`)

Rules marked **MUST** are hard validation rules (a skill is invalid without them). Everything
else is a **SHOULD** — a judgment call that the audit reports but may leave alone with a reason.

## Contents

- Frontmatter
- Naming
- Description
- Size and progressive disclosure
- Body content
- Structure patterns
- Scripts and bundled files
- Anti-patterns
- Testing and iteration
- Where the sources differ

## Frontmatter

- MUST have a YAML frontmatter block with `name` and `description`. [A][S][O1]
- `name` MUST be ≤ 64 characters, lowercase letters, digits and hyphens only, no XML tags,
  and must not contain the reserved words `anthropic` or `claude`. [A]
- `description` MUST be non-empty, ≤ 1,024 characters, no XML tags. [A]
- Only one description field per skill; it is the sole signal used for discovery. [A]
- Optional fields are fine (`disable-model-invocation`, `allowed-tools`, `version`,
  `compatibility`, `metadata`) but keep them minimal — they load into every session. [A][S]

## Naming

- SHOULD use a consistent pattern across the whole collection; inconsistency is the
  explicit anti-pattern. Anthropic prefers gerund form (`processing-pdfs`) but accepts noun
  phrases (`pdf-processing`) and action form (`process-pdfs`). [A]
- SHOULD NOT be vague (`helper`, `utils`, `tools`) or over-generic (`documents`, `files`). [A]
- SHOULD match the directory name so the skill is found where its name says it is. [A][O1]

## Description

- MUST say **what the skill does and when to use it**; both halves, in that order. [A][S][O1][O2]
- SHOULD be written in the third person — it is injected into the system prompt, so
  "I can help you…" and "You can use this to…" cause discovery problems. [A]
- SHOULD include the concrete trigger phrases a user would actually say, plus key domain
  terms, so the skill is picked out of a list of 100+. [A][O2]
- SHOULD front-load the key use case and trigger words: Codex truncates descriptions when
  the skills list exceeds 2% of the context window (8,000 chars if unknown). [O1]
- SHOULD state scope and boundaries — when it should and should *not* trigger. [O1]
- Vague descriptions (`Helps with documents`, `Processes data`) are the canonical bad
  example. [A]

## Size and progressive disclosure

- SHOULD keep the SKILL.md body under 500 lines / ~5,000 tokens; split when approaching
  the limit. [A][S]
- Only `name` + `description` are pre-loaded; SKILL.md loads on trigger; bundled files load
  only when read. Bundle comprehensive material freely — it costs nothing until opened. [A][O1]
- Reference files SHOULD link **directly from SKILL.md, one level deep**. Nested references
  (`SKILL.md → advanced.md → details.md`) get partially read. [A]
- Tell the agent *when* to load each file ("read `references/api-errors.md` if the API
  returns non-200"), not just that it exists. [S]
- Reference files longer than ~100 lines SHOULD open with a table of contents so a partial
  read still shows the full scope. [A]
- Organize bundled files by domain with descriptive names (`reference/finance.md`, not
  `docs/file2.md`). [A]
- Conventional layout: `SKILL.md` + optional `scripts/` (executed), `references/` (read),
  `assets/` (templates/resources). [S][O1]

## Body content

- **Concise is key.** The agent is already very smart; add only what it lacks — project
  conventions, non-obvious procedures, edge cases, which tool to use. Cut anything it would
  get right without the instruction. [A][S]
- **Moderate detail beats exhaustive.** Over-comprehensive skills send the agent down
  irrelevant paths; concise stepwise guidance with one working example wins. [S]
- **Match specificity to fragility.** High freedom (heuristics) where many approaches work;
  low freedom (exact commands, "do not add flags") where operations are fragile or a
  sequence matters. Calibrate each section independently. [A][S]
- **Explain why** for flexible instructions — the agent makes better context-dependent
  decisions when it knows the purpose. [S]
- **Procedures over declarations.** Teach how to approach a class of problems, not the
  answer to one instance. [S]
- **Provide a default, not a menu.** Pick one tool/approach; mention alternatives only as an
  escape hatch. [A][S]
- **Consistent terminology.** One term per concept throughout (always "field", never a mix
  of "field / box / element"). [A]
- **No time-sensitive information.** Put deprecated behavior in an "Old patterns" section
  instead of "before/after <date>" branches. [A]
- **Imperative steps with explicit inputs and outputs.** [O1]
- **Keep each skill focused on one job** — a coherent unit like a well-scoped function.
  Too narrow forces several skills to load; too broad is hard to trigger precisely. [S][O1][O2]
- Forward slashes in every path, even on Windows. [A]

## Structure patterns

Use the ones that fit; not every skill needs all of them.

- **Workflow with checklist** for multistep tasks — a copyable `- [ ]` list the agent ticks
  off, so validation steps are not skipped. [A][S]
- **Feedback / validation loop** — do the work, run a validator (script, reference doc, or
  self-check), fix, repeat until it passes; only then proceed. [A][S]
- **Plan-validate-execute** for batch or destructive operations — write an intermediate
  plan file, validate it against a source of truth, then apply. [A][S]
- **Template pattern** for output format — a concrete template beats prose; say whether it
  is strict ("ALWAYS use this exact structure") or a sensible default. [A][S]
- **Examples pattern** — input/output pairs when style matters. [A]
- **Conditional workflow** — decision points that route to sub-workflows; push large
  branches into separate files. [A]
- **Gotchas section** — concrete, environment-specific facts that defy reasonable
  assumptions; keep them in SKILL.md, and add one every time the agent needs correcting. [S]

## Scripts and bundled files

- Prefer instructions over scripts unless deterministic behavior or external tooling is
  needed; include scripts only when they improve reliability. [O1][O2]
- When an agent reinvents the same logic every run, that is the signal to bundle a tested
  script. Scripts are more reliable than generated code and cost no context. [A][S]
- Scripts SHOULD solve, not defer — handle error conditions explicitly with messages the
  agent can act on ("Field X not found. Available: …"). [A][S]
- No "voodoo constants": every timeout/retry/limit gets a one-line justification. [A]
- Make execution intent explicit: "Run `x.py`" (execute) vs "See `x.py` for the
  algorithm" (read). [A]
- Never assume packages are installed — list dependencies and how to install them. [A]
- MCP tools SHOULD be referenced fully qualified as `ServerName:tool_name`. [A]
- Use the agent's vision on rendered images when layout matters. [A]

## Anti-patterns

- Windows-style paths. [A]
- Offering too many options. [A][S]
- Explaining things the model already knows (what a PDF is, how HTTP works). [A][S]
- Deeply nested references. [A]
- Generic advice ("handle errors appropriately") in place of specific corrections. [S]
- Covering every edge case up front instead of starting from one representative task. [O2]
- Long prompts carrying durable rules that belong in a skill or `AGENTS.md`/`CLAUDE.md`. [O2]
- Vague names and vague descriptions. [A]

## Testing and iteration

- Start from real expertise: extract the skill from a task you actually completed, or
  synthesize from project artifacts (runbooks, review comments, incident reports) — not
  from generic knowledge. [S][O2]
- Build evaluations *before* extensive documentation: identify gaps without the skill,
  write ~3 scenarios, baseline, write minimal instructions, iterate. [A]
- Refine with real execution — read the traces, not just the outputs; feed every result
  back, not only failures. [S]
- Observe how the agent navigates the skill: unexpected read order, missed links,
  over-read sections, never-read files all point at structural fixes. [A]
- Test the description against real prompts to confirm trigger behavior; test with every
  model tier the skill will run on. [A][O1]
- Iterate with two agents: one authors ("Claude A"), a fresh one uses ("Claude B"). [A]

## Pre-share checklist (Anthropic) [A]

Core: specific description with key terms · what + when · body < 500 lines · details in
separate files · no time-sensitive info · consistent terminology · concrete examples ·
one-level references · progressive disclosure · clear workflow steps.

Code: scripts solve rather than defer · explicit error handling · no voodoo constants ·
dependencies listed · scripts documented · forward slashes · validation for critical steps ·
feedback loops for quality-critical tasks.

Testing: ≥ 3 evaluations · tested across models · tested on real usage · team feedback.

## Where the sources differ

- **Naming form.** Anthropic leans gerund (`processing-pdfs`); agentskills.io and OpenAI
  are silent. Consistency within the collection matters more than the form chosen.
- **Description voice.** Anthropic's examples open with an imperative verb ("Extract
  text…"); Anthropic's own `plugin-dev` skill uses "This skill should be used when…". Both
  are third person and valid; pick one per collection.
- **Portability metadata.** OpenAI adds an optional `agents/openai.yaml` (display name,
  icons, `allow_implicit_invocation`, tool dependencies). Irrelevant for Claude Code but
  harmless if present.
- **Scripts.** OpenAI: "prefer instructions over scripts"; Anthropic: "pre-made scripts are
  more reliable, save tokens". Reconciled: instruction-only by default, script when the
  same deterministic logic keeps being regenerated.
- **Discovery locations.** Codex reads `.agents/skills` (repo, parents, `$HOME`); Claude
  Code reads `.claude/skills` and `~/.claude/skills`. Symlinks are followed by both.
- **[O2] relevance.** Only the "Turn repeatable work into skills", `AGENTS.md`, and "Common
  mistakes" sections apply; the rest is general Codex usage.
