---
name: reviewable-commits
description: >
  Reorganize the final diff of the current Git branch or pull request into a small sequence
  of logical, reviewable commits without preserving the accidental chronology of
  development. Use when asked to split, rebuild, clean up, or improve commits for code
  review; turn a large or WIP branch into coherent commits; squash fixups into their
  intended change; or "separar una rama/PR en commits lógicos". Operate on local Git
  repositories and optionally use GitHub CLI only to identify PR metadata. Preserve the
  exact final code state, avoid unrelated refactors, create a safety snapshot before
  rewriting history, verify the result, and never push rewritten history unless explicitly
  requested.
---

# Reviewable Commits

Rebuild branch history from the **final base-to-branch diff**, not from the existing
commit sequence. Produce the smallest useful set of commits that lets a reviewer
understand each intentional change without following the author's development mistakes,
fixups, or intermediate states.

## Hard rules (never violate)

1. Treat the final tree relative to the merge base as the source of truth. Ignore current
   commit boundaries unless they already match the desired structure.
2. Preserve the exact final code state, including intended uncommitted and untracked
   non-ignored files.
3. Make each commit represent one coherent purpose, behavior, or independently reviewable
   mechanical operation.
4. Keep implementation, directly related tests, documentation, configuration, generated
   output, and lockfile changes together when they belong to the same purpose.
5. Avoid development-history commits such as “add implementation,” “fix implementation,”
   “address review,” “rename after feedback,” or separate red/green test commits. Show the
   final intended form directly.
6. Do not introduce unrelated refactors, cleanup, renames, formatting, dependency
   upgrades, or style changes merely because they appear beneficial.
7. Prefer fewer complete commits over many tiny commits. Do not split by file, directory,
   architectural layer, or arbitrary line count.
8. Prefer every commit to build and pass relevant tests. Never create a temporarily broken
   state solely to make commits smaller.
9. Never rewrite the base branch, a detached HEAD, or a repository with unresolved
   conflicts or an in-progress merge, rebase, cherry-pick, or revert.
10. Never discard changes. Create a full-tree safety snapshot before resetting history.
11. Never push or force-push unless the user explicitly asks. When updating an existing
    remote branch or PR after verification, use `--force-with-lease`, never `--force`.

## Grouping rules

- Keep tests with the behavior they verify. Create a standalone test commit only when it
  documents existing behavior independently and the repository explicitly benefits from
  that convention.
- Keep a dependency declaration with its lockfile update.
- Keep generated artifacts with the schema, specification, template, or source that
  generates them.
- Separate a broad mechanical rename or formatting-only change only when it is
  behavior-preserving, large enough to obscure functional review, and genuinely required
  by the branch.
- Separate a preparatory refactor only when it is necessary for the functional change,
  contains no behavior change, and materially improves reviewability. Otherwise fold it
  into the relevant final change or omit it.
- Order database and API compatibility changes according to real deployment constraints.
  Do not force migrations into a separate commit when atomic review is clearer.
- Keep deletion of replaced code with the replacement when both express the same intent.
- Put independent bug fixes or features in separate commits even when they touch the same
  file.

## Phase 1 — Establish the target and base

1. Confirm the current directory is the intended Git repository.
2. Inspect:
   - `git status --short --branch`
   - `git log --oneline --decorate -20`
   - active Git operations and unresolved conflicts
3. Determine the comparison base in this priority order:
   1. Base explicitly supplied by the user.
   2. Base branch of the active pull request, when `gh pr view` is available and the PR
      head matches the current branch.
   3. The repository's remote default branch only when it is unambiguous.
4. Fetch the selected base when a remote is available, then use the merge base rather than
   assuming the branch tip itself is the fork point.
5. Stop and ask for the base only when it cannot be inferred safely. Do not guess across
   plausible release, integration, or stacked-branch bases.

For an active GitHub pull request, a useful inspection command is:

```bash
gh pr view --json number,url,headRefName,baseRefName
```

## Phase 2 — Analyze the final change

Inspect the complete final diff before planning commits:

```bash
git diff --name-status <merge-base>
git diff --stat <merge-base>
git diff <merge-base>
```

Also identify:

- tests and fixtures tied to each behavior
- schema or database migrations
- API contracts and generated clients
- dependency manifests and lockfiles
- generated files and their source definitions
- broad formatting or mechanical changes
- independent fixes accidentally included in the same branch
- changes that are unrelated to the stated task

Do not silently omit unrelated changes. Put genuinely independent changes in their own
commit, or report them before proceeding when their inclusion is questionable.

## Phase 3 — Design the commit plan

Plan from intent and reviewer comprehension, not from chronology or folders. Apply the
grouping rules above; read
[references/grouping-examples.md](references/grouping-examples.md) when the grouping is
ambiguous.

Prefer vertical slices. For example, a small API behavior plus its validation, UI use, and
tests may be one commit even though it spans several layers. Split it only when each
resulting commit has a distinct purpose and remains understandable on its own.

Present the plan before mutating history using this structure:

```text
1. <proposed commit subject>
   Intent: <single purpose represented by the commit>
   Includes: <files, hunks, tests, generated artifacts, or migrations>
   Validation: <targeted checks to run>

2. ...
```

Proceed without waiting for another confirmation when the repository, base, scope, and
requested rewrite are already clear. Pause only for a material ambiguity or unsafe
repository state.

## Phase 4 — Snapshot and flatten the branch

Run the bundled helper from the skill directory:

```bash
python3 scripts/reviewable_commits.py prepare --base <base-ref> --apply
```

Record the emitted state-file path and backup branch. The helper (standard library only,
nothing to install) snapshots the complete final tree to a backup commit and branch,
records the original HEAD, merge base and final tree in the state file, then mixed-resets
to the merge base so the final tree's content stays in the working tree for recommitting.

Do not substitute `git reset --hard` for this workflow.

## Phase 5 — Build each commit

For every planned commit:

1. Stage only its intended files or hunks with explicit paths and `git add -p` where
   needed.
2. Inspect both the staged summary and full staged patch:

   ```bash
   git diff --cached --stat
   git diff --cached
   git diff --cached --check
   ```

3. Confirm the staged patch contains no unrelated formatting, refactors, generated files
   without their source, or tests for another change.
4. Run the narrowest meaningful validation before committing.
5. Commit using the repository's existing message convention.
6. Reinspect the remaining unstaged diff and adjust later grouping only when the actual
   dependency structure requires it.

When one file contains hunks for multiple commits, split the hunks rather than assigning
the entire file arbitrarily. When a hunk cannot be split safely, keep the coupled change
together or temporarily edit the working copy while preserving the final tree for the
final verification.

## Phase 6 — Write the commit messages

Infer the repository's convention from recent history:

```bash
git log -20 --pretty=format:%s
```

Use Conventional Commits only when the repository already uses them. Otherwise follow the
local style.

Write a concise imperative subject describing the completed intent. Add a body when the
reason, constraint, migration behavior, or tradeoff is not obvious. Explain **why** the
change exists rather than narrating file operations.

Avoid subjects such as:

- `WIP`
- `fix stuff`
- `address comments`
- `cleanup`
- `changes`
- `fix previous commit`

## Phase 7 — Verify the rebuilt history

After all commits are created, run:

```bash
python3 scripts/reviewable_commits.py verify --state <state-file>
```

Then run the broadest practical project validation and inspect the resulting history:

```bash
git log --reverse --stat <merge-base>..HEAD
git diff --check <merge-base>..HEAD
git status --short
```

The work is complete only when:

- the working tree is clean
- the final `HEAD` tree exactly matches the captured final tree
- no empty, fixup, squash, or WIP commits remain
- every original intended change appears in exactly one appropriate commit
- relevant tests, linting, type checks, builds, or migration checks pass, or any
  unavailable validation is reported explicitly

## Phase 8 — Push only when requested

When the user explicitly requests updating an existing remote branch or pull request, push
only after successful verification:

```bash
git push --force-with-lease origin HEAD:<branch-name>
```

Use a normal push when no remote history is being replaced. Never delete the safety backup
as part of the same operation.

## Report

Return a compact report in this form:

```text
Rebuilt <count> commits from <base-ref> (<merge-base-short-sha>):

<short-sha> <subject>
  <one-line reviewer-oriented purpose>

...

Validation:
- Final tree: exact match
- Working tree: clean
- Tests/checks: <commands and result>
- Remote update: not performed | pushed with --force-with-lease
- Safety backup: <backup-branch>
```

Report any deviation from the original plan, test failure, excluded change, or unresolved
concern directly.
