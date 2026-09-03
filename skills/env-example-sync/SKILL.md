---
name: env-example-sync
description: >
  Reorder a .env to mirror its .env.example, add missing keys as commented defaults, and
  quarantine .env-only lines. Use when the user wants to sync, mirror, align, or diff a
  .env against a .env.example (any project).
disable-model-invocation: true
---

# Env Example Sync

Make a `.env` mirror its `.env.example` so the two are trivially diffable, **without** ever
changing the user's real values.

## Hard rules (never violate)

1. **Never** change, comment out, or uncomment an existing active value in `.env`. Preserve
   key, value, and quoting exactly.
2. **Never** print full secret values back to the user. Refer to them by key name only.
3. **Never** touch `.env.example`. It is the source of truth for order/structure only.
4. Only `.env` is rewritten.

## Inputs

- Default to `.env` and `.env.example` at the repo root.
- If either path is ambiguous or multiple exist (e.g. `apps/*/.env`), ask which pair
  before doing anything.
- If `.env` does not exist, ask whether to create it from `.env.example` verbatim, then
  stop.

## Phase 1 — Build the target layout

Rewrite `.env` as three parts, in this order:

1. **Mirrored body** — every section/comment/key from `.env.example`, in the **same** order.
   - Key active in `.env`: keep the `.env` value (uncommented), placed at the example's
     position.
   - Key commented (placeholder) in `.env.example` and absent from `.env`: copy the
     commented line verbatim.
   - Preserve the example's section header comments and blank-line spacing.
2. **Trailing block** `# ===== Local extras (not in .env.example) =====` — every line that
   exists only in `.env` (orphan keys, inline alternates, commented variants), kept in
   their original commented/active state.
3. Nothing else. No invented keys.

## Phase 2 — Confirm decisions

Ask these as **one** batched question (skip any already answered):

- Dead/deprecated `.env`-only blocks: move to Local extras, or delete?
- Inline commented alternates (staging creds, alt project ids): keep inline next to their
  key, or move all to Local extras?

Default if the user says "just do it": move everything `.env`-only to Local extras; delete
nothing.

## Phase 3 — Write

```
- [ ] 1. Read both files fully
- [ ] 2. Build key sets: example-order list, .env-active, .env-commented, .env-only
- [ ] 3. Detect value differences (same key active in both, different value) — collect, never change
- [ ] 4. Write mirrored body + Local extras block
- [ ] 5. Diff old vs new .env; confirm no active value changed and no key was lost
- [ ] 6. Report (see below)
```

## Phase 4 — Verify

After writing, re-read `.env` and confirm: (a) body key order equals `.env.example` key
order; (b) the set of active values is unchanged from the original; (c) no key disappeared
except ones the user approved for deletion.

## Report

Always, after writing:

```
## .env sync — <path>

- Reordering: done / sections moved
- Keys added from example (commented placeholders): <names>
- Keys moved to Local extras: <names>
- Keys deleted (only if the user opted in): <names>
- Value differences left untouched: `KEY` (.env=<value or [secret]>, example=<value>)
- Unsure: <.env lines with no example counterpart that were not clearly classifiable>
```

Flag value differences explicitly — when the value is not a credential they are real
behavioral mismatches, not just secrets.
