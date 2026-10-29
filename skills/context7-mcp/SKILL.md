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

Answer from fetched docs. If Context7 returns nothing useful, say so rather than silently
falling back to memory. Every `query` is sent to an external API, so it never carries the
user's pasted code, logs, internal URLs, secrets, or personal data.

## Phase 1 — Resolve the library ID

Call `context7:resolve-library-id` with:

- `libraryName`: the library name extracted from the user's question
- `query`: what to look up in the docs, rewritten in your own words (improves relevance
  ranking), e.g. `Next.js middleware redirect based on auth cookie`, not the user's
  message with its pasted code

## Phase 2 — Select the best match

From the resolution results, choose per the tool's own selection guidance. If the user
mentioned a version (e.g. "React 19"), prefer version-specific IDs.

## Phase 3 — Fetch the documentation

Call `context7:query-docs` with:

- `libraryId`: the selected Context7 library ID (e.g. `/vercel/next.js`)
- `query`: one topic per call, rewritten the same way as in Phase 1. When the question
  spans several topics, make one call per topic (at most 3 per question), unless it is
  about how the topics interact.
- `language`: the language the user writes in (e.g. `TypeScript`), when known

## Phase 4 — Answer with the docs

Answer from the fetched docs: include their code examples and cite the resolved version.

## Phase 5 — Verify

Before sending, confirm the answer rests on the fetched docs, not on memory: every API
name or option mentioned appears in the `query-docs` result, and the version cited is the
one that was resolved. If resolution or the query returned nothing useful, say so
explicitly rather than answering from training data as if it were current.
