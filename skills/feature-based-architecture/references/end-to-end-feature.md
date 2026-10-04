# Adding a feature end to end

Load this when a new entity or capability spans the backend and the frontend.

For a new entity or capability, build in this order so each layer has something real to
call:

1. **Domain types** — `src/features/<f>/<Entity>.ts` in the backend; the frontend mirrors
   the same shape (PropTypes `shape` or a `types.ts`).
2. **Backend service** — business operations returning domain types; `null` for not found,
   a typed domain error for an invalid state.
3. **Backend router** — routes, validation, status codes; mounted by the feature itself.
   Add schema/repository files only if their trigger applies.
4. **Backend tests** — service with the layer below mocked; router through a test server.
5. **Frontend HTTP client** — a method on the shared client in `api/`, exposed through
   `features/common/api.js`.
6. **Frontend server read** — `features/<f>/queries.js` if a page renders it on the
   server.
7. **Hook** — `features/<f>/hooks/use<Thing>.js` with a `QUERY_KEY`, `initialData`, and
   invalidation on mutation.
8. **Handlers** — `create<Name>Handler` factories in `handlers.js`.
9. **Components** — presentational, built from design-system primitives and tokens.
10. **Container** — wires hooks + handlers into components.
11. **Page** — `getServerSideProps` calls `queries.js`, renders the container with
    `initialData`.
12. **Tests** — co-located, same style on both sides.
