---
name: branch-test-plan
description: >
  Build a manual test plan from the current branch's diff — the real user journeys that
  reach the changed code, plus the regression checks for everything that shares it. Use
  when the user asks for a test plan, QA plan, or smoke test steps, asks "how do I test
  this", "what should I verify before merging", or wants to know what could regress from
  these changes.
---

# Branch Test Plan

Turn a branch diff into a manual test plan a human can execute step by step. Every
scenario must be anchored to a code path you actually traced — no invented flows, no
generic "test the happy path" filler.

Output is the chat response. Nothing is written to disk or posted to GitHub without asking.

## Phase 0 — Establish the diff scope

1. Detect the base branch: `git symbolic-ref refs/remotes/origin/HEAD`; fall back to
   `main`, `master`, `develop` (first that exists). If more than one is plausible, ask.
2. `BASE=$(git merge-base HEAD <base>)`.
3. Collect the full change set:
   - `git diff $BASE...HEAD` — committed work on the branch
   - `git diff` and `git diff --cached` — uncommitted work, so WIP is covered too
4. If the change set is empty, say so and stop. Don't produce a plan for nothing.

## Phase 1 — Determine intent (never guess)

Read the **full diff**, not just `--stat`. Then gather intent signals:

- Commit messages on the branch (`git log $BASE..HEAD --oneline`)
- PR body, when one exists: `gh pr view --json title,body` (skip silently if `gh` is
  unavailable or there's no PR)
- Ticket IDs in the branch name
- Changed tests — they often state the intended behavior more precisely than the code
- Changed docs, changelogs, feature-flag definitions

Produce a one-paragraph **"What this branch changes"** statement. If intent is still
ambiguous after all of the above, ask before writing the plan.

## Phase 2 — Trace reachable user journeys

The core step. For each changed symbol or file, search **upward** to the entry points.

1. For every modified exported symbol, component, endpoint, hook, migration, or config
   key, find its references (LSP references first, Grep as backup — include string
   literals and dynamic keys).
2. Follow each chain until it lands on something a human can trigger: a route or page, a
   screen, a CLI command, an API endpoint, a cron/queue job, a webhook, an event handler.
3. Record each journey as `entry point → path through changed code → observable outcome`,
   citing `file:line` at each hop.
4. Note the preconditions you discover along the way: auth and roles, feature flags, env
   vars, seed data, pending migrations, third-party sandbox credentials.

If a changed symbol has no reachable entry point, say so explicitly — dead code or a
partially wired feature is itself a finding worth reporting.

## Phase 3 — Derive the regressions

Regression risk comes from what the change **shares**, not what it adds:

- **Other callers** of a modified function or component — the Phase 2 reference list minus
  the intended journeys. These are the highest-value regression checks.
- **Changed shared types / interfaces / DB schema / API contracts** → check consumers on
  both sides of the boundary.
- **Config, middleware, providers, layouts, global CSS, build settings** → everything
  downstream inherits the change.
- **Deleted or renamed exports** → stale imports and dynamic references; string-keyed
  lookups won't show up in a type check.
- **Data migrations** → behavior on pre-existing rows, and the rollback path.
- **Shared state** — caches, stores, context providers touched by the change.

## Phase 4 — Write the plan

Sections, in this order:

1. **What this branch changes** — the Phase 1 statement plus a short changed-area summary.
2. **Setup / preconditions** — checkout, install, migrations, env vars, feature flags,
   test accounts and roles, seed data. Concrete commands where possible.
3. **Scenarios** — grouped happy path → edge cases → error paths.
4. **Regression checks** — same table shape, each row stating *why* it's at risk.
5. **Already covered by automated tests** — scenarios the existing suite covers, with the
   command to run them. This keeps the manual list short and honest.
6. **Not verifiable locally** — needs staging, real third-party credentials, or production
   data. Say what would have to be true to test it.

Scenario table shape:

```
| ID | Pri | Steps | Expected result | Code touched |
|----|-----|-------|-----------------|--------------|
| S1 | P0  | 1. … 2. … | … | `src/foo.ts:42` |
```

**Priorities** so a 10-minute pass is possible:
- **P0** — the core changed behavior and the highest-risk regression
- **P1** — edge cases and error paths
- **P2** — cosmetic, rare, or low-blast-radius

## Verification & output

- Before writing, confirm every cited path still exists — a stale `file:line` makes the
  whole plan untrustworthy.
- Print the plan in the chat response. **Do not write files or post to GitHub as part of
  the run.**
- After printing, offer two follow-ups and wait for an explicit yes:
  - save it to a markdown file (let the user pick the path)
  - post it as a PR comment via `gh pr comment`

## Notes & edge cases

- **Big diffs**: if the change set spans many areas, group scenarios by area and keep the
  P0 list to the handful that actually exercise the change.
- **Refactor-only branches**: the plan is mostly regression checks — the point is proving
  nothing changed. Say that up front instead of inventing feature scenarios.
- **Backend-only changes**: entry points are endpoints, jobs, and CLI commands; give
  `curl` invocations or the exact command rather than UI steps.
- **Feature-flagged work**: every scenario needs its flag state stated, and the flag-off
  path is itself a P0 regression check.
- **Generated files** (lockfiles, snapshots, build output): exclude from journey tracing,
  but flag dependency bumps — they carry their own regression surface.
