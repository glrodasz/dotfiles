# Output Template

Use this structure for the final answer. Omit execution-only sections when operating in plan-only mode, but keep the plan and coverage sections.

## Contents

- PR split recommendation — Bottom line, Current change, Proposed dependency graph, PR summary,
  Detailed PR boundaries, Review and merge order, Coverage and equivalence, Execution plan,
  Applied result, Assumptions and risks
- Pull request body template — the body for each published PR

# PR split recommendation

## Bottom line

State:

- Whether the plan is compliant with the 1,000-line target and 2,000-line maximum.
- The number of proposed PRs.
- How many are independent and how many are stacked.
- The maximum stack depth.
- The main organizing principle: behavior, dependency, ownership, rollout safety, or a combination.

## Current change

| Metric | Value |
|---|---:|
| Base | `<base-ref>` |
| Source | `<source-ref-or-pr>` |
| Commits | `<count>` |
| Files | `<count>` |
| Reviewable lines | `<additions + deletions>` |
| Auxiliary lines | `<generated + snapshots + vendor + lockfiles>` |
| Binary files | `<count>` |
| Effective CODEOWNERS | `<path on base, or none>` |

Briefly explain why the current PR is hard to review.

## Proposed dependency graph

Use a compact tree or Mermaid graph. Distinguish independent roots and dependent children. Example:

```text
main
├── PR 1: shared contract
│   ├── PR 2: producer
│   └── PR 3: consumer
└── PR 4: independent admin UI
```

## PR summary

| PR | Title | Base | Depends on | Primary owners | Reviewable lines | Auxiliary lines | Status |
|---|---|---|---|---|---:|---:|---|
| 1 | `<imperative title>` | `<base>` | None | `<owners>` | `<n>` | `<n>` | Target / justified / non-compliant |

List PRs in review and merge order. Use separate numbering for independent stacks only when that improves clarity.

## Detailed PR boundaries

### PR 1: `<title>`

- **Purpose:** One-sentence behavior or prerequisite.
- **Base branch:** `<trunk-or-parent>`
- **Proposed branch:** `<branch-name>`
- **Depends on:** `<none-or-PR>`
- **Primary owners:** `<CODEOWNERS matches>`
- **Additional reviewers:** `<inferred reviewers, clearly labeled>`
- **Review scope:** What each reviewer should assess.
- **Included changes:** Files, symbols, endpoints, migrations, or precise hunks.
- **Excluded changes:** Closely related work intentionally left to later PRs.
- **Size:** `<reviewable>` reviewable, `<auxiliary>` auxiliary, `<binary>` binary files.
- **Checks:** Exact tests, type checks, builds, migrations, or manual validation.
- **Merge or rollout notes:** Compatibility, flags, sequencing, retargeting, or deployment concerns.
- **Why this boundary:** Explain semantic cohesion and dependency logic.

Repeat for every PR.

## Review and merge order

State:

1. Which PRs can be reviewed in parallel.
2. Which approvals block higher layers.
3. The bottom-up merge order for each stack.
4. How child PRs are rebased or retargeted after a parent merges when native stack support is not used.

## Coverage and equivalence

Report all of the following:

- Original changed paths assigned: `<n>/<n>`.
- Original reviewable lines accounted for: `<n>/<n>`.
- Original auxiliary lines accounted for: `<n>/<n>`.
- Shared files split by hunk: `<list or none>`.
- Duplicate semantic changes: `<none or explanation>`.
- Unassigned changes: `<none or list>`.
- New changes not present in original PR: `<none or list>`.
- Final-tree equivalence: `planned`, `verified`, or `failed`.

Do not claim verified equivalence unless a tree comparison was actually run.

## Execution plan

Provide exact, repository-specific steps rather than a generic Git tutorial. Include:

- Safety branch name.
- Branch creation order and bases.
- Commits to cherry-pick when cleanly reusable.
- Files or hunks to reconstruct when commits are mixed.
- Checks to run after each branch.
- Final integration-tree comparison.
- Push and PR creation commands only in Publish mode.

## Applied result

Include this section only after local or remote execution.

| PR layer | Branch | Commit | Remote PR | Checks | Equivalence |
|---|---|---|---|---|---|
| 1 | `<branch>` | `<sha>` | `<URL or not published>` | `<result>` | `<result>` |

List any conflict, skipped check, permission limitation, or deviation explicitly.

## Assumptions and risks

List only material assumptions. Distinguish confirmed repository facts from inferences.

---

# Pull request body template

Use this body for each published PR and adapt it to the repository's own template.

```markdown
## Purpose

<One coherent outcome introduced by this layer.>

## Stack

- Trunk: `<trunk>`
- Depends on: `<parent PR or none>`
- Previous: `<link or none>`
- Next: `<link or none>`
- Original oversized PR: `<link or none>`

Review only the diff between this branch and its declared base.

## Review scope

- `<owner/team>`: `<specific files, behavior, or risk to review>`
- `<owner/team>`: `<specific files, behavior, or risk to review>`

## Included

- `<change>`
- `<change>`

## Intentionally excluded

- `<later-layer change>`

## Size

- Reviewable lines: `<n>`
- Auxiliary lines: `<n>`
- Binary files: `<n>`

## Validation

- [ ] `<test or check>`
- [ ] `<test or check>`

## Merge notes

<Bottom-up order, compatibility requirements, and retarget or rebase notes.>
```
