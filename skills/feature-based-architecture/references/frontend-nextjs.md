# Frontend: React / Next.js feature modules and SSR

Load this when working on pages, containers, components, hooks, handlers, server-side rendering, API routes, React Query, or frontend tests.

Reference implementation: `cero-web` (Next.js pages router, React Query, styled-jsx, `@glrodasz/components`). If the project has an `AGENTS.md`, it is the authority; this file is the default.

## Contents

- [Feature module roles](#feature-module-roles)
- [Components and containers](#components-and-containers)
- [Hooks](#hooks)
- [Handlers](#handlers)
- [Helpers and constants](#helpers-and-constants)
- [Data flow: browser and server](#data-flow-browser-and-server)
- [API routes](#api-routes)
- [Config and environment](#config-and-environment)
- [Serverless rules](#serverless-rules)
- [Testing](#testing)
- [TypeScript projects](#typescript-projects)

## Feature module roles

```text
features/<feature>/
  components/   presentational: props in, JSX out, no data fetching
  containers/   stateful: call hooks, create handlers, render components
  hooks/        use* hooks: React Query, dialogs, timers, local state
  handlers.js   create<Name>Handler factories
  helpers.js    pure domain functions, no I/O, no React
  queries.js    server-side domain reads, shared by getServerSideProps and API routes
  constants.js  statuses, ids, limits — no magic strings elsewhere
```

A component folder may carry its own `handlers.js`, `helpers.js`, or `constants.js` when only that component uses them (`tasks/components/DraggableTask/handlers.js`). Promote them to the feature level when a second component needs them.

`pages/` files stay thin: auth wrapper, `getServerSideProps` calling `queries.js`, and rendering one container with `initialData`. No domain logic in pages.

## Components and containers

**Presentational components** (`components/`):

- Folder + barrel for new components: `Board/Board.js` + `Board/index.js` with `export { default } from './Board'`. Follow the project's existing flat files only where that is still the local norm.
- Built from design-system primitives and tokens (see `design-system.md`).
- Receive data and `on*` callbacks as props. Never import the HTTP client, React Query, or a data hook.
- Always declare `propTypes`; prefer `PropTypes.shape({...})` over bare `object`/`array`.

**Containers** (`containers/`):

- One per screen or stateful region (`Planning`, `FocusSession`, `EditTask`).
- Call hooks, instantiate handler factories, and pass the results down as `on*` props.
- Handle loading and error states (`LoadingError`) so components don't have to.

```jsx
const Planning = ({ initialData }) => {
  const tasks = useTasks({ initialData: initialData.tasks })
  const handleAddTask = createAddTaskHandler({ tasks })

  return <Board tasks={tasks.data} onAddTask={handleAddTask} />
}
```

## Hooks

- One hook per file, `use<Thing>.js`, default export.
- Data hooks use React Query: a `QUERY_KEY` constant, `initialData` passthrough from SSR, and `invalidateQueries(QUERY_KEY)` in every mutation's `onSuccess`.
- Return a stable, domain-named object: `{ isLoading, error, data, api: { create, remove, updateStatus } }`.
- Hooks read the HTTP client only through `features/common/api.js`:

```js
import { tasksApi } from '../../common/api'

const QUERY_KEY = 'tasks'

const useTasks = ({ initialData }) => {
  const queryClient = useQueryClient()
  const { data, isLoading, error } = useQuery([QUERY_KEY], () => tasksApi.getAll(), { initialData })
  const { mutateAsync: create } = useMutation((params) => tasksApi.create(params), {
    onSuccess: () => queryClient.invalidateQueries(QUERY_KEY),
  })
  return { data, isLoading, error, api: { create } }
}

export default useTasks
```

- Build on existing generic hooks instead of re-implementing: a plain dialog uses `useDialog`; a dialog that also holds a value (the id being deleted) uses `useDialogWithState`, then renames `value`/`setValue` to domain names.
- Optimistic local state (drag and drop) goes through a small hook like `useLocalData(fetchedData)`, not ad-hoc `useState` copies in containers.

## Handlers

Event handlers are **curried factories** in `handlers.js`, named `create<Name>Handler`. They take dependencies and return the handler, which keeps them pure and unit-testable without rendering.

```js
export const createAddTaskHandler =
  ({ tasks }) =>
  ({ value }) => {
    const { api } = tasks
    !isEmpty(value) && api.create({ description: value })
  }
```

Containers create them; components receive them as `on*` props. Business decisions inside a handler (limits, status transitions) delegate to `helpers.js` so they can be tested alone.

## Helpers and constants

- `helpers.js` holds pure domain functions (`reorderTasks`, `normalizeData`, `filterColumns`). If it needs `fetch`, React, or `window`, it is not a helper.
- `constants.js` holds statuses, column ids, and limits. Use them in URLs and request bodies too: `` `tasks?status=${IN_PROGRESS_COLUMN_ID}` ``.
- Configurable limits come from `config/` (env), not `constants.js`.
- Naming collision to watch: `sessionId` in `queries.js` is the visitor's storage session (cookie), not a focus session. Name new parameters unambiguously (`focusSessionId`).

## Data flow: browser and server

There are two paths to the same data, and they must never cross.

```text
BROWSER                                    SERVER RENDER
hooks/use<Thing>                           pages/<page>.js getServerSideProps
  → features/common/api.js                   → features/<f>/queries.js
  → api/<resource>.js (extends Request)      → datasources/index.js
  → HTTP  ${API_URL}/<resource>              → the store (json-server, Redis, fixtures, backend)
  → pages/api/[source]/**  (API route)
  → features/<f>/queries.js or datasources/
```

Rules:

- **SSR never calls the app's own API routes over HTTP.** It is already on the server; it calls `queries.js` directly. Self-fetching breaks behind deployment protection (401) and is slower anyway.
- **`queries.js` is the single implementation of a server-side read.** Both `getServerSideProps` and the API route call it, so they can't drift. Name reads by intent: `readTasks({ sessionId })`, `readActiveFocusSession({ sessionId })`.
- **SSR data enters React Query as `initialData`.** The page passes `initialData={{ tasks }}` to the container; the hook passes it to `useQuery`. Later mutations invalidate the key and refetch through the browser path.
- **The browser HTTP client is shared infrastructure** (`api/`), one class per resource extending `api/request.js`, instantiated in `api/index.js`, re-exported once from `features/common/api.js`. Do not create per-feature `api.js` files.
- **Always check `response.ok`** before treating a body as data, and turn every error body shape into a readable message (`{ error: 'msg' }` and `{ error: { code, message } }`), never `[object Object]`.
- **Storage access is infrastructure** (`datasources/`): one entry (`fetchResource`) that picks the store; CRUD semantics defined once (`collections/`) so every store behaves the same; stores supply only get/save.

When the real backend (a separate repo) is wired in, the `api` data source gets an HTTP path inside `datasources/`/`queries.js` (server-to-backend), and `API_URL` points the browser at the backend. The page and hook code do not change.

## API routes

- Live under the framework's API folder (`pages/api/[source]/**`); thin, like pages.
- Wrap every handler: a project wrapper (`datasources/withApiRoute`) on top of a generic one (`utils/withApiHandler`). The generic wrapper returns a JSON 500 with the real message on throw and a 405 when no method branch answered. The project wrapper adds project checks (the `[source]` namespace guard → 400).
- **Answer on every path.** Branch with `if (req.method === 'GET') { ... return res.status(200).json(...) }`; never leave a path that doesn't write a response.
- **Don't pass `res` into an intermediate step that must throw to stop the handler.** A step that writes the error response and returns lets the handler keep running.
- Business rules shared with SSR go through `queries.js`/helpers; don't re-implement them in the route.
- Use named status constants (`utils/httpCodes`) rather than bare numbers where the project has them.
- Never compile request input into a `RegExp` (ReDoS); match by substring or explicit alternation.

## Config and environment

- `config/` is the only place that reads `process.env`. Everything else imports named values.
- **One selector per decision.** If a single question ("which backend?") is answered by an env var, every derived value (browser `API_URL`, server store) comes from that one selector (`config/dataSource.js`). Never add a second variable that decides half of it. An unrecognized value throws at build time.
- `NEXT_PUBLIC_*` values are baked in at build time; changing them requires a rebuild.
- Every committed env file sets every numeric config key; a missing one becomes `NaN` and silently disables comparisons.

## Serverless rules

- No module-level mutable state shared across API routes or pages — each route can be its own function instance. Shared state goes through a real store.
- Locks and queues held in memory are per instance; document the limitation or move the lock into the store.

## Testing

- Co-located: `Thing.js` → `Thing.test.js`; snapshots in `__snapshots__/` beside them.
- `describe` labels use the path form: `describe('[ features / tasks / handlers ]')`, then `describe('#createAddTaskHandler')`, then `describe('when …')` / `it('should …')`.
- Arrange / Act / Assert with comment markers; name values `result` and `expected`.
- Test by role:
  - handlers and helpers: plain unit tests, mock collaborators with `jest.mock`.
  - hooks: `renderHook`, mock `features/common/api`.
  - components: snapshot + `@testing-library/react` + `user-event`; mock the design-system package with `dummyRender`.
  - queries: mock `datasources`.
- Integration tests (`*.integration.test.js`, TestCafe or Playwright) run against a deterministic store (`fixtures`) and are excluded from the unit run.
- Keep coverage thresholds honest: ratchet up, never lower to unblock a change.

## TypeScript projects

Same structure and rules. Additionally:

- Domain types per feature in `features/<f>/types.ts`, or `<Entity>.ts` mirroring the backend's entity file; import them with `import type`.
- Replace `propTypes` with typed props; keep `options` constants as the source of variant unions (`type ButtonType = typeof options.types[number]`).
- Path aliases are optional; if the project has none, keep relative imports rather than introducing aliases mid-project.
