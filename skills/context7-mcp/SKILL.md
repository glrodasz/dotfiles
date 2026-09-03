---
name: context7-mcp
description: >
  Fetch current library and framework documentation through Context7 instead of answering
  from training data. Use when the user asks about libraries, frameworks, API references,
  or needs code examples — setup questions ("How do I configure Next.js middleware?"),
  code generation involving libraries ("Write a Prisma query for…"), API references
  ("What are the Supabase auth methods?"), or mentions of specific frameworks like React,
  Vue, Next.js, Svelte, Express, Tailwind, Prisma, Supabase.
---

# Context7 Documentation Lookup

When the user asks about libraries, frameworks, or needs code examples, use Context7 to
fetch current documentation instead of relying on training data.

## Phase 1 — Resolve the library ID

Call `context7:resolve-library-id` with:

- `libraryName`: the library name extracted from the user's question
- `query`: the user's full question (improves relevance ranking)

## Phase 2 — Select the best match

From the resolution results, choose based on:

- Exact or closest name match to what the user asked for
- Higher benchmark scores indicate better documentation quality
- If the user mentioned a version (e.g. "React 19"), prefer version-specific IDs

## Phase 3 — Fetch the documentation

Call `context7:query-docs` with:

- `libraryId`: the selected Context7 library ID (e.g. `/vercel/next.js`)
- `query`: the user's specific question

## Phase 4 — Answer with the docs

Incorporate the fetched documentation into the response:

- Answer the user's question using current, accurate information
- Include relevant code examples from the docs
- Cite the library version when relevant

## Verify

Before sending, confirm the answer rests on the fetched docs, not on memory: every API
name or option mentioned appears in the `query-docs` result, and the version cited is the
one that was resolved. If resolution or the query returned nothing useful, say so
explicitly rather than answering from training data as if it were current.

## Notes & edge cases

- **Be specific**: pass the user's full question as the query for better results.
- **Version awareness**: when users mention versions ("Next.js 15", "React 19"), use
  version-specific library IDs if available from the resolution step.
- **Prefer official sources**: when multiple matches exist, prefer official/primary
  packages over community forks.
