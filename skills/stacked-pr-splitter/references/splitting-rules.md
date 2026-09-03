# Splitting Rules

Use these rules to choose semantic PR boundaries. Apply them in priority order; a lower-priority rule must not break a higher-priority one.

## Contents

- Priority order
- Prefer vertical slices
- Use a foundation PR selectively
- Split by ownership without breaking semantics
- Keep tests with behavior
- Handle shared files carefully
- Handle generated artifacts and lockfiles
- Handle database and deployment changes
- Handle API and schema contracts
- Handle refactors and mechanical changes
- Handle commits
- Decision examples
- Anti-patterns

## Priority order

1. Preserve final behavior and scope.
2. Keep each PR buildable, testable, and safe against its declared base.
3. Preserve true technical dependencies.
4. Create a coherent review narrative.
5. Align ownership and reviewer expertise.
6. Stay within the line budget.
7. Minimize stack depth and reviewer coordination.
8. Balance sizes only after all other constraints are satisfied.

## Prefer vertical slices

Prefer independent vertical slices when each slice can deliver a complete behavior without another slice. Examples include:

- One endpoint or command with its validation and tests.
- One user-visible workflow with backend, frontend, and tests when the same reviewers can assess it coherently.
- One provider, adapter, integration, or feature flag path.
- One bug fix and its regression test.

Base independent slices directly on the original trunk. Do not force them into a linear stack merely because they originated in one branch.

## Use a foundation PR selectively

Create a lower foundation PR only when the foundation is itself meaningful and at least one higher PR truly depends on it. Suitable foundation changes include:

- Shared types or interfaces used by multiple later PRs.
- Additive database schema or migration primitives.
- Reusable test infrastructure needed by multiple slices.
- A behavior-preserving mechanical change that would otherwise obscure every later diff.

Avoid a foundation PR that contains unused abstractions, speculative infrastructure, or dead code. If only one PR consumes a prerequisite, usually keep the prerequisite with that consumer.

## Split by ownership without breaking semantics

Use CODEOWNERS as a strong boundary signal, not an absolute file partition.

- Prefer a PR whose primary review can be completed by one owner group.
- Split a large same-owner change by behavior, component, endpoint, command, migration phase, or user workflow.
- At a cross-team contract, prefer a lower contract or provider PR and a higher consumer PR when both states remain valid.
- Keep a cross-team atomic change together when neither side is meaningful or safe alone. List all owner groups and give each group a focused review scope.
- Do not put unrelated files together merely because they share the same owner.
- Do not assign owners based only on directory names when CODEOWNERS is present.

## Keep tests with behavior

Keep direct unit, integration, contract, and regression tests in the same PR as the behavior they validate. Separate test infrastructure only when it is reusable, behavior-neutral, and needed by multiple later PRs.

Do not create an "all tests" PR above implementation PRs. It weakens independent verification and makes lower layers appear safer than they are.

## Handle shared files carefully

A file may legitimately appear in more than one stacked layer when different coherent hunks belong to different concerns. In that case:

- Assign each hunk to exactly one layer.
- Keep lower-layer edits minimal and stable for higher layers.
- Explain the file's role in each PR.
- Verify the combined final file exactly matches the original source SHA.

Avoid repeatedly rewriting the same lines across layers. That creates review churn and fragile rebases.

## Handle generated artifacts and lockfiles

- Identify the human-authored source of every generated change.
- Keep generated output with its source change when reviewers need to confirm regeneration consistency.
- Isolate a huge generated or lockfile-only diff when it would otherwise drown out human-authored logic.
- Include the generator command, tool version, and validation when discoverable.
- Report both reviewable and auxiliary line counts.
- Never classify unfamiliar code as generated merely to meet the budget.

## Handle database and deployment changes

When every merge may deploy independently, favor an expand-migrate-contract sequence:

1. Add backward-compatible schema, data paths, flags, or contracts.
2. Add producers and consumers that work with old and new states.
3. Migrate or backfill data.
4. Switch reads or writes.
5. Remove old schema or code only after compatibility is proven.

Place destructive cleanup last. Do not create an intermediate PR that requires an unmerged higher PR to keep production working.

## Handle API and schema contracts

Put a contract below its consumers only when the contract can exist safely before adoption. Keep contract and implementation together when the contract alone would be misleading, unusable, or externally breaking.

For generated clients, decide based on reviewability:

- Keep schema and generated client together when generation is deterministic and consumers need the client immediately.
- Otherwise use a contract PR, a generated-client PR, and consumer PRs, with explicit dependencies.

## Handle refactors and mechanical changes

Separate a mechanical change only when all of these are true:

- It is behavior-preserving.
- It is required by the target change.
- It materially reduces noise in later reviews.
- It can be validated independently.

Examples: a pure rename, file move, formatting-only migration, or mechanical API replacement. Do not use the large PR as an excuse for unrelated cleanup.

## Handle commits

Use existing commits as boundaries only when their complete diffs already match semantic PR units. Do not preserve a noisy historical evolution merely because it exists.

A PR should show the final coherent change for that layer. Squash, reorder, split, or reconstruct commits locally when requested, while preserving the original branch and final tree.

## Decision examples

### Independent features owned by different teams

Original change contains unrelated billing export and profile settings work.

- PR A: billing export, based on trunk, billing owners.
- PR B: profile settings, based on trunk, identity owners.

Use two independent PRs, not a stack.

### Shared contract with two consumers

Original change adds a shared event schema, a producer, and two consumers.

- PR A: additive event contract and compatibility tests.
- PR B: producer implementation, based on PR A.
- PR C: consumer one, based on PR A.
- PR D: consumer two, based on PR A.

Use a small dependency graph with sibling consumers, not one four-level chain.

### One team owns more than 2,000 reviewable lines

Original change adds six independent endpoints in one service.

- Extract any common minimal routing or validation prerequisite only if truly shared.
- Split endpoints into coherent use-case PRs, each with tests.
- Base independent endpoint PRs on trunk or the shared prerequisite.

Do not create arbitrary 1,000-line file chunks.

### Cross-team atomic workflow

A provider contract and its only consumer must change together to avoid a broken deployment.

- Keep both in one PR if no compatibility phase is possible.
- List both owner groups.
- Give each group an explicit review scope.
- If the PR exceeds 1,000 lines, first look for behavior-neutral prerequisites or compatible rollout phases; do not split into invalid halves.

## Anti-patterns

Reject plans that do any of the following:

- Split solely by file count or equal line count.
- Put all tests, docs, or generated files in one unrelated final PR.
- Create an intermediate branch that does not compile or cannot deploy safely.
- Force independent work into a deep stack.
- Mix unrelated cleanup with required changes.
- Assign a PR to an owner group while most of its risk belongs elsewhere.
- Hide more than 2,000 human-authored lines behind a large generated diff.
- Omit changes from the original PR or introduce changes not present in it.
