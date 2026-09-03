---
name: stacked-pr-splitter
description: >
  Analyze an oversized current pull request or branch diff and redesign it as a small,
  reviewable set of independent and/or stacked pull requests. Use when a PR is difficult to
  review, spans multiple features, modules, or teams, exceeds roughly 1,000 changed
  human-authored lines, has tangled dependencies, or needs CODEOWNERS-aware review
  boundaries. Inspect Git history, diff statistics, tests, generated files, and CODEOWNERS;
  propose a dependency graph, branch and base plan, reviewer routing, tests, and exact
  coverage of the original change. Apply the split locally or publish PRs only when
  explicitly requested, while preserving final behavior and avoiding unrelated refactors.
---

# Stacked PR Splitter

Turn one oversized change into the smallest sensible dependency graph of reviewable pull
requests. Optimize for reviewer comprehension, ownership, independent verification, and
safe merge order. Do not optimize for equal line counts.

## Hard rules (never violate)

1. Preserve the intended final behavior and complete final tree of the original PR.
2. Do not introduce cleanup, redesign, formatting churn, dependency upgrades, or unrelated
   refactors.
3. Prefer independent PRs from the original base when changes can stand alone.
4. Stack a PR only when it has a real compile-time, runtime, schema, API, migration, or
   review dependency on a lower PR.
5. Keep implementation and its direct tests together.
6. Make every PR coherent, reviewable, and valid against its declared base.
7. Target at most 1,000 reviewable changed lines per PR.
8. Permit 1,001 to 2,000 reviewable changed lines only with a concrete cohesion or safety
   justification.
9. Do not propose a PR above 2,000 reviewable changed lines. Mark the plan non-compliant
   if no safe split is found and explain the indivisible boundary.
10. Report generated, vendored, snapshot, binary, and lockfile changes separately. Never
    use them to hide a large human-authored change.
11. Read and respect repository-local instructions such as `AGENTS.md`, `CLAUDE.md`,
    `CONTRIBUTING.md`, and relevant README files.
12. Match the response language to the user's language.

The budget exists because reviewer attention drops sharply past a few hundred lines: about
1,000 reviewable lines is the most one reviewer can assess carefully in one sitting, and
beyond 2,000 a review degrades into a rubber stamp.

## Phase 0 — Select the operating mode

Infer the mode from the request:

1. **Plan only**: Use for requests such as "analyze", "suggest", "design the split", or
   ambiguous requests. Inspect without changing Git state.
2. **Apply locally**: Use only when the user asks to split, restructure, create branches,
   or rewrite the local PR. Create local branches and commits, but do not push.
3. **Publish**: Use only when the user explicitly asks to push, open, create, or update
   remote PRs. Prefer draft PRs unless the user requests ready-for-review PRs.

Do not close, replace, force-push, or comment on the original PR unless explicitly
requested.

## Phase 1 — Establish the source and base

- Work from the repository root.
- Resolve the source from the supplied PR, branch, or current `HEAD`.
- Resolve the original PR base with `gh pr view` when available. Otherwise use the
  configured remote default branch, then common base branches such as `main` or `master`.
- Record the source branch, source commit SHA, base ref, merge-base SHA, and working-tree
  status.
- Treat the original base as the stack trunk.
- Never discard, reset, clean, or auto-stash uncommitted work. If the tree is dirty,
  continue in plan-only mode and state that local application is blocked.
- Run the bundled analyzer when a Git repository is available:

```bash
python3 <skill-directory>/scripts/analyze_pr.py --repo . --head HEAD --format json
```

Pass `--base <ref>` when the base cannot be inferred reliably.

## Phase 2 — Inventory the change

Inspect all of the following before designing boundaries:

- Commit history between merge-base and source.
- Changed files, additions, deletions, renames, binaries, and directory distribution.
- Relevant diffs, symbols, imports, interfaces, schemas, migrations, feature flags, and
  tests.
- Generated files, lockfiles, snapshots, vendored files, and machine-produced artifacts.
- The effective `CODEOWNERS` file from the original base branch.
- CI, branch protection, test, build, deployment, and migration constraints visible in the
  repository.

Do not infer a semantic split from filenames, directories, commit messages, or ownership
alone. Read enough of the actual diff to understand behavior and dependencies.

## Phase 3 — Map ownership correctly

- Locate `CODEOWNERS` on the original base in this order: `.github/CODEOWNERS`,
  `CODEOWNERS`, then `docs/CODEOWNERS`.
- Apply the last matching valid pattern for each path.
- Preserve entries with multiple owners and entries that intentionally clear ownership.
- Do not invent an owner for unmatched files. Suggest a logical reviewer separately and
  label that suggestion as inferred.
- Prefer one primary owner group per PR when semantic boundaries permit.
- If one owner group's coherent change exceeds 1,000 reviewable lines, split it again by
  behavior, use case, endpoint, component, migration phase, or another semantic boundary.
- If a cross-team change is atomic, keep it together and list every affected owner.
  Explain why splitting at the ownership boundary would create an invalid or misleading
  review.

## Phase 4 — Design the dependency graph

Load `references/splitting-rules.md` and apply its priority order and special cases.

- Start with candidate independent vertical slices.
- Extract shared prerequisites only when multiple slices truly depend on them or when they
  form a meaningful review unit.
- Build a directed acyclic graph, not automatically one long chain.
- Use multiple independent PRs or multiple short stacks when possible.
- Keep stack depth as low as the dependency structure allows.
- Place a dependency in the same PR or a lower PR, never in a higher PR.
- Give every PR one clear purpose and one concise review narrative.
- Assign direct tests and validation to the PR that introduces the behavior.
- Keep intermediate states deployable when the repository deploys every merge. Use
  additive schema and compatibility phases when necessary.

## Phase 5 — Enforce the size budget

Define line counts as follows:

- **Reviewable lines**: additions plus deletions in human-authored source, tests,
  configuration, migrations, and documentation.
- **Auxiliary lines**: additions plus deletions in generated files, snapshots, vendored
  files, and lockfiles.
- **Total lines**: all numeric additions plus deletions. Report binary files separately.

For every proposed PR, apply the budget from hard rules 7 to 9, and:

- Do not split a coherent 300-line change merely to balance PR sizes.
- Isolate a very large generated or lockfile diff when doing so improves review, but keep
  its source-of-truth change and regeneration instructions obvious.

## Phase 6 — Verify the plan

Before presenting or applying the split, verify:

- Every original changed path and semantic change is assigned.
- No semantic change is duplicated or omitted.
- Shared-file hunks are assigned to the correct layer.
- The dependency graph is acyclic.
- Every PR has the correct base branch.
- Every PR is understandable without reviewing higher layers.
- Every PR can build and run its declared checks against its own base.
- CODEOWNERS and inferred reviewers are explicit.
- The union of all PRs reconstructs the original final tree.
- The plan contains no unrelated improvements.

## Phase 7 — Produce the review plan

Load `references/output-template.md` and follow it. Include:

- Current PR metrics and why it is difficult to review.
- A concise bottom-line recommendation.
- Independent PRs and stack relationships.
- A dependency diagram.
- A summary table with base, dependency, owners, size, and test scope.
- Detailed boundaries for every PR.
- Coverage and equivalence checks.
- Exact local execution steps when useful.
- Assumptions and unresolved risks without pretending certainty.

## Phase 8 — Apply the split locally

Perform these steps only in Apply locally or Publish mode:

1. Require a clean working tree.
2. Record the original source SHA and create a uniquely named safety branch at that SHA.
   Never delete or rewrite the original branch by default.
3. Create each new branch from its declared trunk or parent branch.
4. Prefer existing commits only when an entire commit belongs to one proposed PR.
5. When commits are mixed, reconstruct the final change from the recorded source SHA using
   whole-file restoration for exclusive files and hunk-level patches for files shared
   across layers. Do not reimplement the feature from memory.
6. Commit the final intended state for each review unit. Do not create artificial "work in
   progress" evolution unless an intermediate compatibility layer is required.
7. Run the narrowest relevant checks after each PR, then the repository's required checks
   when feasible.
8. Verify each branch diff against its declared base and recalculate line counts and
   ownership.
9. Create a disposable integration branch or worktree, apply all unique PR commits in
   topological order, and compare its final tree with the recorded original source SHA.
   Require an empty tree diff.
10. Keep the safety branch and report all created branch names, commit SHAs, checks, and
    any deviations.

Abort local application without destructive cleanup if a conflict cannot be resolved
confidently. Preserve all work and return the validated plan plus the exact blocking
conflict.

## Phase 9 — Publish the PRs

Perform these steps only in Publish mode:

- Confirm that the remote, authentication, and push permissions are available through the
  existing environment.
- Prefer GitHub's native `gh stack` workflow for a linear stack when `gh stack --help`
  succeeds. Inspect the installed command help before relying on flags because the feature
  may evolve.
- Use ordinary branches and `gh pr create` as the portable fallback and for independent PR
  graphs.
- Set the bottom PR base to the original trunk. Set each dependent PR base to its
  immediate parent branch.
- Publish as drafts by default so the complete graph, descriptions, and links can be
  checked before requesting reviews.
- Use the PR body structure from `references/output-template.md`, including purpose,
  dependency, review scope, ownership, size, tests, and stack navigation.
- Link every PR to the original oversized PR when one exists.
- For non-native stacks, explain the bottom-up merge and retarget/rebase sequence.
- Never force-push an existing shared branch without explicit permission. Use
  `--force-with-lease` only when a requested stack operation requires it and the remote
  state has been checked.

## Completion standard

Finish only when the result is one of these:

- A compliant, fully specified split plan.
- A locally created and equivalence-verified branch graph.
- A published set of linked draft or ready PRs with verified bases and checks.
- A clearly marked non-compliant plan that identifies the exact boundary preventing a safe
  sub-2,000-line split.
