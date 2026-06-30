---
name: sync-env-example
description: Reorder a .env to mirror its .env.example, add missing keys as commented defaults, and quarantine .env-only lines. Use when the user wants to sync, mirror, align, or diff a .env against a .env.example (any project).
disable-model-invocation: true
---

# Sync .env to .env.example

Make a `.env` mirror its `.env.example` so the two are trivially diffable, WITHOUT ever changing the user's real values.

## Inputs

- Default to `.env` and `.env.example` at the repo root.
- If either path is ambiguous or multiple exist (e.g. `apps/*/.env`), ask which pair before doing anything.
- If `.env` does not exist, ask whether to create it from `.env.example` verbatim, then stop.

## Hard rules (never violate)

1. NEVER change, comment out, or uncomment an existing ACTIVE value in `.env`. Preserve key, value, and quoting exactly.
2. NEVER print full secret values back to the user. Refer to them by key name only.
3. NEVER touch `.env.example`. It is the source of truth for order/structure only.
4. Only `.env` is rewritten.

## What to produce

Rewrite `.env` as three parts, in this order:

1. **Mirrored body** — every section/comment/key from `.env.example`, in the SAME order.
   - Key active in `.env`: keep the `.env` value (uncommented), placed at the example's position.
   - Key commented (placeholder) in `.env.example` and absent from `.env`: copy the commented line verbatim.
   - Preserve the example's section header comments and blank-line spacing.
2. **Trailing block** `# ===== Local extras (not in .env.example) =====` — every line that exists only in `.env` (orphan keys, inline alternates, commented variants), kept in their original commented/active state.
3. Nothing else. No invented keys.

## Workflow

```
- [ ] 1. Read both files fully
- [ ] 2. Build key sets: example-order list, .env-active, .env-commented, .env-only
- [ ] 3. Detect VALUE DIFFERENCES (same key active in both, different value) — collect, do NOT change
- [ ] 4. Write mirrored body + Local extras block
- [ ] 5. Diff old vs new .env; confirm no active value changed and no key was lost
- [ ] 6. Report (see below)
```

## Decisions to confirm before writing

Ask these as ONE batched question (skip any already answered):

- Dead/deprecated `.env`-only blocks: move to Local extras, or delete?
- Inline commented alternates (staging creds, alt project ids): keep inline next to their key, or move all to Local extras?

Default if the user says "just do it": move everything `.env`-only to Local extras; delete nothing.

## Report (always, after writing)

- Reordering: done / sections moved.
- Keys added from example (commented placeholders): list by name.
- Keys moved to Local extras: list by name.
- Keys deleted: list by name (only if user opted in).
- VALUE DIFFERENCES left untouched: `KEY` (.env=<value or [secret]>, example=<value>) — flag these explicitly; they are real behavioral mismatches, not just secrets, when the value isn't a credential.
- Anything in `.env` with no example counterpart that you were unsure about.

## Verification

After writing, re-read `.env` and confirm: (a) body key order equals `.env.example` key order; (b) the set of active values is unchanged from the original; (c) no key disappeared except ones the user approved for deletion.
