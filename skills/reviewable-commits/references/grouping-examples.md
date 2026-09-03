# Commit Grouping Examples

Consult these examples only when the final diff can plausibly be grouped in several ways.

## Contents

1. Prefer final intent over development chronology
2. Group by behavior, not architectural layer
3. Keep a bug fix with its regression test
4. Separate required mechanical work only when it clarifies review
5. Keep manifests and generated output with their source
6. Split independent changes even inside one file
7. Avoid arbitrary size-based splitting
8. Respect deployment compatibility

## 1. Prefer final intent over development chronology

Final diff adds an endpoint, validation, and tests. Existing history contains:

1. Add endpoint
2. Fix request validation
3. Rename response field
4. Update tests after rename

Bad rebuilt history:

```text
feat: add endpoint
fix: validate endpoint input
refactor: rename response field
test: update endpoint tests
```

Better rebuilt history:

```text
feat(api): add validated export endpoint
```

Include the endpoint in its final form, final field names, validation, and tests in the same commit.

## 2. Group by behavior, not architectural layer

Final diff adds notification preferences across a migration, server, UI, and tests.

Usually bad:

```text
chore(db): add preference columns
feat(api): add preference endpoint
feat(ui): add preference controls
test: add preference tests
```

Potentially better when the change is small and atomic:

```text
feat(notifications): let users configure delivery preferences
```

A useful two-commit split when the persistence contract is independently reviewable:

```text
feat(notifications): persist delivery preferences
feat(notifications): expose preference controls to users
```

Keep each commit's direct tests with that commit.

## 3. Keep a bug fix with its regression test

Bad:

```text
test(billing): reproduce timezone proration bug
fix(billing): calculate prorations in account timezone
```

Preferred unless the repository explicitly requires red/green commits:

```text
fix(billing): calculate prorations in account timezone
```

Include the regression test in the same commit so the reviewer sees the defect, contract, and fix together.

## 4. Separate required mechanical work only when it clarifies review

A feature requires renaming a widely used type across hundreds of references.

Good when the rename is behavior-preserving and would otherwise bury the feature:

```text
refactor(auth): rename SessionToken to AccessToken
feat(auth): support scoped access tokens
```

Bad when the rename is optional cleanup discovered during the task:

```text
refactor(auth): rename several token helpers
feat(auth): support scoped access tokens
```

Omit the optional rename or keep only the minimal edits required for the feature.

## 5. Keep manifests and generated output with their source

Preferred:

```text
build(api): add the OpenAPI code generator dependency
feat(api): define invoice export and regenerate the client
```

The dependency commit includes the package manifest and lockfile. The feature commit includes the OpenAPI source and generated client. Do not create a generic `update lockfile` or `regenerate files` commit.

## 6. Split independent changes even inside one file

A controller file contains both a pagination fix and a new export action.

Preferred:

```text
fix(customers): preserve cursor when filtering results
feat(customers): add CSV export
```

Use patch staging so each hunk goes with its own purpose. Shared supporting edits belong with the change that needs them, or in a prerequisite commit only when both later commits genuinely depend on them.

## 7. Avoid arbitrary size-based splitting

A 900-line generated parser update may belong in one commit with its grammar source. A 40-line diff containing two independent fixes should be two commits. Optimize for reviewer reasoning, not a fixed line count.

## 8. Respect deployment compatibility

For an expand-and-contract database rollout, separate commits may be necessary:

```text
feat(db): add nullable canonical_customer_id
feat(customers): dual-write canonical customer IDs
```

Do not invent this sequence merely to make history look incremental. Use it only when each state is intentionally deployable or independently reviewable. Otherwise keep the migration and application behavior atomic.
