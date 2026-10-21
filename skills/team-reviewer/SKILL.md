---
name: team-reviewer
description: >
  Review code from the perspective of this team's human reviewers, using the rules
  learned from their past PR comments. Use when asked to review a diff, branch or PR,
  before opening a PR, or when the user asks "what would the team flag here", "review
  this like my team would", or "is this ready for review".
allowed-tools: Bash(sh ${CLAUDE_SKILL_DIR}/scripts/*) Bash(git diff *) Bash(git log *) Bash(gh pr diff *) Bash(gh pr view *)
---

# Team Reviewer

Review a change the way this team's human reviewers would, applying the rules distilled
from their comments by `/harvest-reviews`. Report only — never edit the code, never post
to GitHub. The rules live in a per-computer, gitignored store next to this file.

## Learned rules (top 15)

!`sh ${CLAUDE_SKILL_DIR}/scripts/context.sh rules`

Every rule, one line each with evidence counts: `${CLAUDE_SKILL_DIR}/.review-harvest/index.md`.
Details per rule (why, before→after hunk): `${CLAUDE_SKILL_DIR}/.review-harvest/rules.md`.
Things not to flag:
`${CLAUDE_SKILL_DIR}/.review-harvest/false-positives.md`. Real examples per category
(reviewer, project, code, comment, fix): `${CLAUDE_SKILL_DIR}/.review-harvest/examples/`.

## Current branch diff

!`sh ${CLAUDE_SKILL_DIR}/scripts/context.sh diff`

## Phase 0 — Scope

1. Target, in order: what the user named (PR number → `gh pr diff <n>` and
   `gh pr view <n> --json title,body,files`; branch → `git diff <base>...<branch>`;
   paths → those files), else the branch diff above. Add `git diff HEAD` when the user
   wants uncommitted work included.
2. Empty diff → say so and stop.
3. Read the PR description or commit messages (`git log <base>..HEAD --oneline`) for
   intent; a finding that contradicts stated intent is worth more than a style nit.

## Phase 1 — Load the rules

1. Read `index.md` and `false-positives.md` in full when they exist. The top 15 above are
   the strongest; the rest still apply. `rules.md` is large — look up a rule's section by
   its id (Grep for `` `<rule-id>` ``) only when you need its why or before→after.
2. `N×` is how many reviewer threads back a rule and `NΔ` how many led to a code change;
   weigh single-thread rules lightly. Prefer rules whose **Projects** include the current
   repo (`gh repo view --json nameWithOwner`); treat rules seen only elsewhere as weaker.
3. Skip rules marked `stale` or `contradicted` unless the diff matches them exactly — then
   mention the status.
4. No store yet → review with general judgment and say the result is not team-calibrated.

## Phase 2 — Review

1. Walk the diff file by file. For each hunk, check every rule whose category could apply.
   Open the surrounding code when a rule depends on context the hunk hides (callers,
   tests next to the file, types).
2. Open `examples/<category>.md` when unsure whether a rule fires — match on what the
   reviewers actually objected to, not on surface similarity.
3. Drop anything listed in `false-positives.md`.
4. Note real problems the rules do not cover as **novel**; don't stretch a rule to fit.
5. Severity:
   - **Blocking** — correctness, security, data loss, or a rule whose evidence shows
     reviewers held the PR for it
   - **Should fix** — a rule with repeated evidence that usually led to a change
   - **Nit** — style, naming, or a rule that was often waived
6. Every finding needs a concrete `file:line` in the new code and a one-line fix. No
   findings without a location, no restating the diff.

## Report

```markdown
## Team review — <target> (<N> files, +<a>/-<d>)

Calibrated on <N> learned rules (store updated <date>) | Not calibrated: no store yet

### Blocking
- `path/file.ts:42` — <what is wrong> → <fix>. _Rule: `<rule-id>`_

### Should fix
- …

### Nit
- …

### Novel (not covered by learned rules)
- `path/file.ts:88` — <issue> → <fix>

### Looks good
<one or two lines on what reviewers usually push back on that this change already does well>
```

Omit empty sections. If nothing is found, say so plainly — don't invent nits.

## Notes & edge cases

- **Huge diffs**: the injected diff is capped; read the remaining files with
  `git diff <base>...HEAD -- <path>` before concluding.
- **Generated files** (lockfiles, snapshots, build output): skip unless a rule targets
  them.
- **Seeding**: the store is per computer. On a new machine run `/harvest-reviews 90d`
  in the team repo first.
- **Rule disagreement**: if the user says a rule is wrong, suggest the next
  `/harvest-reviews` run, or edit `rules.json` in the store and rerun its render script.
