---
name: minimal-code-changes
description: >
  Enforce minimal, narrowly scoped modifications when implementing features, fixing bugs,
  changing tests, updating configuration, or otherwise editing an existing codebase. Use
  whenever code must be changed and the requested behavior can be delivered without broad
  cleanup, especially for requests mentioning minimal diffs, surgical changes, preserving
  existing structure, avoiding refactors, or not touching unrelated code. Prevent
  opportunistic renaming, reformatting, abstraction, dependency upgrades, architecture
  changes, and unrelated fixes. Do not block an explicitly requested refactor, but keep even
  that refactor strictly within the named scope.
---

# Minimal Code Changes

Implement the requested behavior with the smallest correct semantic diff.

Treat code outside the necessary change boundary as read-only. Set the default refactor
budget to zero. Do not improve code merely because an improvement becomes apparent while
working nearby.

Minimal does not mean cryptic or fragile. Keep the patch correct, maintainable, and
consistent with the existing local style without expanding its scope.

## Priorities

Apply these priorities in order:

1. Satisfy the requested behavior correctly.
2. Preserve existing behavior outside the request.
3. Minimize the semantic and textual diff.
4. Follow the codebase's existing local conventions.
5. Improve elegance only within the lines that must change.

## Phase 1 — Define the change contract

Before editing, identify:

- The exact requested outcome.
- The narrowest relevant file, symbol, function, component, or configuration entry.
- The existing behavior that must remain unchanged.
- The focused validation needed to prove the change.

When the request is ambiguous, choose the least expansive reasonable interpretation and
state the assumption. Do not silently broaden the task.

## Phase 2 — Inspect narrowly

Read enough surrounding code to understand the target and its immediate dependencies.
Search for existing patterns that the patch should follow.

Do not turn repository exploration into a cleanup exercise.

## Phase 3 — Establish the change boundary

Use this default boundary:

- **Primary boundary:** the exact function, class, component, module, or configuration
  entry responsible for the requested behavior.
- **Secondary boundary:** immediate callers, dependencies, types, or tests only when the
  primary change cannot work correctly without them.
- **Outside the boundary:** read-only unless the user explicitly expands the scope.

Prefer changing an existing condition, branch, argument, or local implementation over
introducing a new abstraction.

## Phase 4 — Implement surgically

- Edit the fewest files and lines reasonably possible.
- Preserve existing names, control flow, public APIs, file locations, and architecture.
- Reuse current dependencies and established local patterns.
- Match nearby formatting instead of reformatting surrounding code.
- Add comments or documentation only when required to explain new non-obvious behavior.
- Preserve pre-existing user changes in the working tree.
- Avoid destructive Git operations and never revert unrelated work.

## Phase 5 — Validate narrowly

Run the most focused relevant checks available, such as a targeted test, type check, lint
command, or build for the affected package.

Add or modify only tests that directly verify the requested behavior. Do not rewrite broad
test suites, regenerate unrelated snapshots, or fix unrelated failures.

If an unrelated pre-existing issue blocks validation, report it separately. Do not repair
it unless the requested change cannot be delivered safely without doing so.

## Phase 6 — Verify the diff

Review the final diff before finishing.

For every changed line, ask: **Can this line be justified directly by the requested
behavior, its focused validation, or a necessary compatibility constraint?**

If not, revert that line. Remove formatting churn, reordered imports, renamed variables,
generated noise, and incidental cleanup.

## Refactor gate

Permit a refactor only when every condition below is true:

1. It is directly necessary to implement the requested behavior correctly or to prevent a
   regression introduced by the patch.
2. No narrower implementation is reasonably available.
3. It remains inside the smallest enclosing function, component, module, or explicitly
   requested area.
4. It preserves external behavior except for the requested change.
5. It can be validated with focused checks.

Code cleanliness, stylistic preference, duplication reduction, modernization, or future
flexibility alone are not sufficient reasons.

When a broader refactor is truly unavoidable, keep it as small as possible and explicitly
explain why it was required. Do not use it to include adjacent improvements.

## Changes forbidden by default

Do not perform any of the following unless explicitly requested or required by the
refactor gate:

- Rename variables, functions, types, files, directories, or public symbols.
- Move code between files or reorganize modules.
- Extract helpers, introduce generalized abstractions, or redesign interfaces.
- Replace design patterns, libraries, frameworks, or APIs.
- Add, remove, or upgrade dependencies.
- Change public contracts, schemas, data models, or configuration shapes.
- Reformat untouched code or reorder imports across unrelated sections.
- Run repository-wide formatters, linters with auto-fix, codemods, or generators that
  create broad churn.
- Fix unrelated bugs, warnings, type errors, security findings, spelling, comments, or
  dead code.
- Expand error handling beyond the path affected by the request.
- Rewrite tests simply to make them cleaner.
- Modify generated files when changing their source is sufficient.

A serious unrelated issue may be reported as a separate follow-up, but must not be folded
into the patch without authorization unless leaving it untouched would make the requested
implementation immediately unsafe.

## Tool discipline

- Prefer targeted edits over bulk replacements.
- Scope formatter, lint, build, and test commands to the affected file or package when
  possible.
- Inspect `git diff` or the equivalent before completion.
- Distinguish pre-existing changes from changes made for the current request.
- Do not alter lockfiles unless dependency resolution actually changed.
- Do not regenerate artifacts merely because tooling makes it convenient.

## Report

Keep the final report focused:

```
## <requested change> — <file or area>

1. State what behavior changed and where.
2. State which focused checks were run and their result.
3. Mention an intentionally untouched adjacent issue only when it is important for the user to know.
```

## Examples

### Add a timeout to one request

**Do:** Pass the timeout through the existing client call and update the focused test.

**Do not:** Introduce a new HTTP client factory, rename environment variables, centralize
all request settings, or upgrade the HTTP library.

### Fix a null-value crash in a parser

**Do:** Add the narrowest guard at the failing path and add a regression test.

**Do not:** Rewrite the parser, redesign its return type, rename neighboring fields, or
clean up unrelated branches.

### Add one field to an existing response

**Do:** Update the responsible mapping, its type only if required, and focused tests.

**Do not:** Reorganize the response layer, replace the serializer, or normalize every
related endpoint.

### Explicitly requested refactor

**Do:** Refactor only the named service, component, or pattern and preserve behavior with
focused validation.

**Do not:** extend the refactor into adjacent modules simply because they use similar
code.
