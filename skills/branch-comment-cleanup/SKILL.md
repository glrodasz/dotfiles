---
name: branch-comment-cleanup
description: >
  Strip unnecessary comments from the current branch's changes and make the code
  self-explanatory instead — renaming, extracting, and naming constants where a comment
  was propping up unclear code. Only business-logic and "why" comments survive. Use when
  the user wants to clean up comments, remove AI narration comments, make code
  self-documenting, or tidy a diff before opening a PR.
---

# Branch Comment Cleanup

Remove comments the code should be saying itself, restricted to what this branch
introduced. Where a comment exists because the code is unclear, fix the code — rename,
extract, name the constant — rather than rewording the comment.

**Mode: apply, then report.** Make the edits, verify, and report. `git diff` is the review
surface. Stop and ask only for the cases listed under "Needs your call".

## Hard rules (never violate)

1. **Only touch lines added or modified by this branch.** Pre-existing comments and
   untouched files are off-limits, however bad they look. If you spot something worth
   fixing out of scope, mention it in the report — don't edit it.
2. **Behavior-preserving only.** No logic changes, no reordering that could shift side
   effects.
3. **Renames must update every reference** — LSP rename where available, otherwise
   exhaustive grep including string literals, dynamic keys, and test files. Never rename a
   public or exported API without asking.
4. **Repo conventions win.** Before deleting any doc comment, check `CLAUDE.md` /
   `AGENTS.md`, ESLint config (`jsdoc/*`, `eslint-plugin-tsdoc`, header rules), and
   whether the file's neighbors follow a documented style.

## Phase 0 — Scope

1. Detect the base branch: `git symbolic-ref refs/remotes/origin/HEAD`; fall back to
   `main`, `master`, `develop`. Ask if ambiguous.
2. `BASE=$(git merge-base HEAD <base>)`.
3. `git diff $BASE...HEAD -U0` plus `git diff -U0` and `git diff --cached -U0` for
   uncommitted work — `-U0` gives the exact added-line ranges with no context bleed.
4. Build a per-file list of touched line ranges. Only comments **inside** those ranges are
   in scope.
5. Record `git diff $BASE...HEAD --name-only` now — Phase 3 compares against it.

## Phase 1 — Classify every comment in scope

**DELETE**
- Restates the code: `// increment counter`, `// return the result`
- Step-by-step narration: `// First we…`, `// Now handle…`, `// Finally…`
- Section-divider banners inside a function
- JSDoc/docblocks that only repeat the signature, parameter names, or types the language
  already declares
- Commented-out code
- Changelog or attribution noise: `// added by`, `// new in v2`, `// updated`
- Comments explaining a diff to the reviewer rather than the code to a reader

**KEEP**
- Domain and business rules, especially with their source (`// VAT is 21% per EU rule X`)
- Non-obvious *why*: chosen trade-offs, ordering constraints, why the obvious approach
  fails
- Workarounds, with a link to the upstream issue
- Performance, security, legal, or compliance constraints
- Links to specs, RFCs, tickets
- Regex intent, and the shape of data it matches
- Doc comments the repo's lint rules or public API conventions require
- License headers

**REFACTOR INSTEAD** — the comment is a symptom; fix the cause and the comment goes away:
- Explains *what* a block does → extract a named function
- Labels a magic value → named constant
- Clarifies a vague identifier → rename the identifier
- Explains a condition → guard clause, or a well-named boolean
- Explains what a chunk of a long function does → split the function

## Phase 2 — Apply

Deletions first, then refactors. Prefer the smallest refactor that removes the need for
the comment — a rename beats an extraction, an extraction beats a restructure. Stay inside
the code this branch introduced.

## Phase 3 — Verify

- Run the repo's **real** commands — discover them from `package.json` scripts, `Makefile`,
  `justfile`, or CI config. Don't assume `npm test`. Typecheck, lint, tests, build.
- **Scope check**: `git diff $BASE...HEAD --name-only` must match the list recorded in
  Phase 0. A new file appearing means you edited out of scope — revert it.
- Re-read the diff and confirm no logic line changed meaning.

## Report

```
## Comment cleanup — <branch>

| File:line | Comment | Action | Reason |
|-----------|---------|--------|--------|
| src/x.ts:42 | `// loop over users` | removed | restates the code |
| src/y.ts:10 | `// 3 retries — payment gateway SLA` | kept | business constraint |
| src/z.ts:88 | `// calculate the discount` | refactored | extracted `calculateDiscount()` |

### Renames & extractions
- `d` → `discountRate` (src/z.ts, 4 references updated)

### Verification
- typecheck / lint / tests: <actual commands and results>
- scope: N files touched, same set as before cleanup

### Needs your call
- <unticketed TODOs, exported-API renames, comments that may encode tribal knowledge>

### Out of scope (not touched)
- <pre-existing issues worth a follow-up>
```

## Notes & edge cases

- **Unticketed TODO/FIXME**: never delete silently. List it under "Needs your call" — it
  may be a real open thread.
- **Exported API renames**: ask first. The blast radius extends past the repo.
- **Tests**: descriptive comments in tests are often redundant with the `it(...)` name —
  fold the meaning into the test name rather than keeping both.
- **Generated files** (lockfiles, codegen output, migrations from a tool): skip entirely,
  even when they appear in the diff.
- **A comment you don't understand** is a comment you keep. Flag it instead of deleting —
  unfamiliarity is not evidence of redundancy.
- **Commented-out code**: safe to delete; git has it. Say so in the report.
