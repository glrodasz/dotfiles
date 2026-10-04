---
name: feature-based-architecture
description: >
  Organize, scaffold, and refactor full-stack JavaScript/TypeScript codebases around
  features/domains instead of technical layers, with atomic design and design tokens on
  the UI side and feature modules on the Node backend. Use whenever creating a feature,
  page, component, container, hook, handler, helper, util, query, API route, endpoint,
  router, service, or repository; deciding where a file belongs; choosing between
  helpers, utils, common, lib, or infrastructure folders; styling a component or adding
  a color/spacing value (design tokens); deciding whether a component belongs in the app
  or in the design system; wiring server-side rendering (getServerSideProps, React Query
  initial data); naming files or directories; extracting or sharing code between
  features; or restructuring a project's folder layout. Trigger even when the user never
  says "architecture" and only asks "where should this go?", "add X to the project",
  "add an endpoint", "style this", or "clean up this utils folder".
---

# Feature-Based Architecture

Place code by ownership, not by technical type.

**Golden rule: put code where its knowledge belongs.** Code that knows about `Task` lives
near tasks. Code that knows nothing about the domain may be a utility. Code that connects
the app to storage, a backend, or an external system belongs in a named infrastructure
folder.

Folder names exist to communicate ownership, responsibility, and boundaries. They are not
a filing system for file types.

The same rule applies on both sides of the wire: a frontend feature folder and a backend
feature folder for the same domain should be recognizably the same thing.

## Which reference to load

This file holds the rules that apply everywhere. Load a reference only when the task
touches its area:

| Task touches | Load |
|---|---|
| Components, styling, colors/spacing, theming, "is this a design-system component?" | [references/design-system.md](references/design-system.md) |
| Next.js/React: pages, containers, hooks, handlers, SSR, API routes, React Query, frontend tests | [references/frontend-nextjs.md](references/frontend-nextjs.md) |
| Node backend: Express/Fastify routers, services, repositories, validation, errors, config, backend tests | [references/backend-node.md](references/backend-node.md) |
| Another feature needs this code, or deciding whether to extract it to `common/`, `utils/` or the design system | [references/sharing-code.md](references/sharing-code.md) |

A feature that spans the stack (new entity end to end) needs all three; read
[references/end-to-end-feature.md](references/end-to-end-feature.md) too and build in that order.

## Workflow

Follow these steps every time you create, move, or name a file.

### 1. Read the project first

Before writing anything, inspect the existing structure and record its conventions:

- Where features live (`features/`, `src/features/`, `modules/`, or none yet)
- Whether the project has an `AGENTS.md`, `CLAUDE.md`, or architecture doc. **If it does,
  it overrides this skill.**
- Naming case for feature folders, component files, and role files (`focusSession/` vs
  `focus-session/`, `Board/Board.js`, `tasks.router.ts`)
- Whether feature roles are single files (`helpers.js`, `handlers.js`) or folders
  (`helpers/`)
- Whether components are folder + barrel (`Board/index.js`) or flat files
- What the generic folder is called (`utils/`, `utilities/`) and what is actually in it
- Which infrastructure folders exist (`api/`, `datasources/`, `config/`, `lib/`) and what
  each one owns
- Whether UI primitives come from an external design-system package
- Language and module system (JS/TS, ESM/CommonJS, `.js` extensions in TS imports)

The existing convention wins over this skill's defaults. A consistent project with
slightly different labels is better than one with two competing styles.

### 2. Identify the owner

Ask what the code *knows about*, not what kind of file it is. See [Placement
decision](#placement-decision).

### 3. Place it

Put the file in the owning feature, or in the correct shared location if it has no domain
owner.

### 4. Name it

Match the project's established style. See [Naming](#naming).

### 5. Check the dependency direction

Confirm the new imports point the allowed way. See [Dependency
direction](#dependency-direction).

## Where code lives

Default layout for a frontend app (Next.js pages router shown; adapt to the framework):

```text
features/
├── tasks/                    domain feature
│   ├── components/           presentational: Board/Board.js + Board/index.js
│   ├── containers/           stateful wiring: hooks + handlers → components
│   ├── hooks/                useTasks.js, useDeleteConfirmation.js
│   ├── handlers.js           createAddTaskHandler, createDeleteTaskHandler
│   ├── helpers.js            pure domain functions
│   ├── queries.js            server-side domain reads (SSR + API routes)
│   └── constants.js          statuses, limits, ids
├── planning/                 screen/flow feature: composes domain features
│   ├── components/
│   └── containers/Planning.js
└── common/                   React code shared by ≥2 features
    ├── components/           MainLayout, UserHeader
    ├── hooks/                useDialog, useLocalData
    └── api.js                the one entry point to the HTTP client
pages/                        thin routes: getServerSideProps + render a container
api/                          infrastructure: browser HTTP client
datasources/                  infrastructure: server-side storage access
config/                       infrastructure: env reads, the one place process.env is read
utils/                        generic, domain-free functions
styles/                       global styles and token overrides only
```

Default layout for a Node backend:

```text
src/
├── features/
│   ├── tasks/
│   │   ├── Task.ts               domain types + domain constants
│   │   ├── tasks.router.ts       HTTP: routes, input parsing, status codes
│   │   ├── tasks.service.ts      business operations, returns domain types
│   │   ├── tasks.schema.ts       (on demand) request validation
│   │   └── tasks.repository.ts   (on demand) persistence
│   └── common/                   cross-feature domain pieces (rare)
├── lib/                          db connection, logger
├── utils/                        httpStatus.ts and other domain-free code
├── middlewares/                  error pipeline, not-found, validation factory
├── config.ts
├── app.ts                        builds the app (testable)
└── server.ts                     connects + listens
```

| Location | Holds | Knows the domain? |
|---|---|---|
| `features/<domain>/` | Everything that exists because that domain exists | Yes |
| `features/<screen>/` | A screen or flow that composes domain features (planning, retrospective) | Yes |
| `features/common/` | React components/hooks (or backend pieces) shared by two or more features | Barely: shared app concepts, no single owner |
| `utils/` | Generic functions that could be copied into an unrelated project; one function per file, named after it (`isEmpty.js`), grouped only for constant tables (`time.js`, `httpCodes.js`) | No |
| Named infra folders (`api/`, `datasources/`, `config/`, `src/lib/`) | Clients, storage access, env, SDK wrappers | No (they serve the domain without encoding its rules) |
| Design-system package | Atoms and molecules, tokens | No |
| `pages/` / `app/` | Framework routing, kept thin | Composes features only |

Create a role file or subfolder only when there is something to put in it. A feature with
two files does not need seven empty slots.

**Role files grow into folders.** Start with `helpers.js`; when it holds several unrelated
responsibilities or passes ~200 lines, split it into `helpers/<name>.js`. Do the same for
`handlers.js`, `queries.js`, `constants.js`. Keep the import surface stable while doing
it.

**Domain features vs screen features.** Name domain features after the domain (`tasks`,
`focusSession`). A screen/flow feature (`planning`, `retrospective`) is legitimate when it
owns containers and screen-specific components that compose several domains. Screen
features may also have their own `hooks/`, `helpers.js`, and `constants.js` for logic that
only that screen needs. Screen features import domain features; domain features never
import screen features. A page about a single domain (a list of finished focus sessions)
does not need a screen feature: its container lives in the domain feature. Create a screen
feature when a page composes two or more domains.

**Same noun on both sides.** Use the same domain noun for a feature in the frontend and
the backend. Singular vs plural follows each side's existing convention
(`features/focusSession/` in the web app, `src/features/focusSessions/` in the API) —
don't rename an existing feature to align them.

## Placement decision

Ask these questions in order and stop at the first yes.

1. **Is it specific to one feature/domain?** Place it inside that feature, in the role
   matching its job:
   - renders UI from props → `components/`
   - wires hooks and handlers to components → `containers/`
   - React state, effects, or React Query → `hooks/`
   - builds an event handler from dependencies → `handlers.js`
   - pure domain logic, no I/O → `helpers.js`
   - server-side domain read used by SSR and/or API routes → `queries.js`
   - fixed values, statuses, limits → `constants.js`
   - (backend) HTTP concern → `<feature>.router.ts`; business operation →
     `<feature>.service.ts`; persistence → `<feature>.repository.ts`; input shape →
     `<feature>.schema.ts`; types → `<Entity>.ts`
2. **Does it connect the app to storage, a backend, or an external system?** (HTTP client,
   DB client, auth, analytics, storage, SDK wrapper) → the matching infrastructure folder;
   `lib/` if none fits.
3. **Is it a React component or hook shared by two or more features?** →
   `features/common/`.
4. **Is it a domain-free UI primitive (button, input, card, modal)?** → the design-system
   package, not the app. See [references/design-system.md](references/design-system.md).
5. **Is it a domain-free function?** → `utils/`.

If none apply, the code probably has an owner you have not identified yet. Look again at
step 1 before inventing a new top-level folder.

**Examples**

- `reorderTasks(tasks, …)` → `features/tasks/helpers.js`. It takes `Task`s.
- `formatMilliseconds(ms)` → `utils/`. It knows nothing about tasks or sessions.
- `createAddTaskHandler({ tasks })` → `features/tasks/handlers.js`.
- `readTasks({ sessionId })` used by `getServerSideProps` and an API route →
  `features/tasks/queries.js`.
- The Redis client → `datasources/memory/client.js`. Infrastructure.
- `useInterval` used by two features → `features/common/hooks/`. `useTasks` →
  `features/tasks/hooks/`.
- A generic `Badge` → design-system package. A `TaskCounterBadge` that takes a `Task[]` →
  `features/tasks/components/`.
- `PATCH /tasks/:id/archive` (only completed tasks) → `tasks.service.ts` (`archiveTask`:
  returns `null` if missing, throws a typed conflict error if not completed) and
  `tasks.router.ts` (route; `null` → 404; the error pipeline maps the conflict to 409).

## Helpers vs utils

The single test: **does this function know about the application's domain?**

- **Yes → helper.** It takes domain objects, uses domain terminology (task, session,
  status), or encodes a business rule. Keep it inside its feature.
- **No → util.** It could be copied into an unrelated project and still make sense.

A global `utils/` containing `task.js`, `session.js`, and `user.js` hides who owns each
behavior. Nobody knows what is safe to change, and the folder grows without limit. The aim
is not to eliminate helpers; it is to make their owner obvious.

## Infrastructure is not utils

Infrastructure is the machinery the app talks *through*: HTTP clients, storage adapters,
DB connections, env config, SDK wrappers. Give each piece a precisely named folder when
the project has more than one (`api/` for the browser HTTP client, `datasources/` for
server storage, `config/` for env). Use `lib/` as the home for infrastructure that has no
better name.

The designated infrastructure homes (`lib/`, `middlewares/`, `config`) may be created for
their first file — that is not the "new top-level folder for a single file" anti-pattern,
which targets invented, vaguely named folders.

Separate the infrastructure from the domain operations performed against it:

```text
api/request.js                 ← how the browser talks to the backend
features/common/api.js         ← the one entry point features use for it
datasources/index.js           ← how the server reaches storage
features/tasks/queries.js      ← what the tasks domain reads through it
src/lib/db.ts                  ← backend DB connection
src/features/tasks/tasks.service.ts ← what tasks does with it
```

Do not put pure functions like `groupBy` in infrastructure, and do not put a DB client in
`utils/`. Do not create per-feature `api.js` re-exports of the shared HTTP client.

## Dependency direction

Imports point inward toward more generic code, never outward toward more specific code.

```text
pages/ → containers/ → components/ → design-system package
              │
              ├→ hooks/ → features/common/api.js → api/
              ├→ handlers.js
              └→ helpers.js, constants.js

pages/ (SSR) → features/*/queries.js → datasources/
backend: router → service → repository/model → src/lib/

everything may import → utils/, config/
```

Hard rules:

- `utils/` never imports from `features/`, infrastructure, or the framework's routing.
- Infrastructure (`api/`, `datasources/`, `lib/`) never imports from `features/`.
- Presentational `components/` never call data hooks or the HTTP client; containers do.
- Domain features never import screen features.
- A backend service never imports a router; a router never touches the DB model directly.
- A feature that uses another feature imports what it needs explicitly. If the project
  gives features a public entry point (`index.js`), go through it; if not, import the
  specific file and keep cross-feature imports few and visible.

## Sharing code between features

Default to keeping code local; extraction is a decision, not a reflex. When a second
feature needs something, read [references/sharing-code.md](references/sharing-code.md)
before moving it. Prefer duplication over a wrong abstraction, and never move code to
`utils/` for hypothetical reuse.

## Naming

- Match the project's existing case and style for directories and files. Never introduce a
  second style.
- Defaults when the project has none:
  - Frontend feature folders: camelCase (`focusSession/`). Components: PascalCase folder +
    file + barrel (`Board/Board.js`, `Board/index.js`). Hooks: `useThing.js`, one per
    file, default export. Role files: lowercase (`handlers.js`, `helpers.js`,
    `queries.js`, `constants.js`). Route files: kebab-case (`pages/focus-session.js`).
  - Backend feature folders: camelCase (`focusSessions/`). Role files:
    `<feature>.<role>.ts` (`tasks.router.ts`, `tasks.service.ts`). Domain types: singular
    PascalCase (`Task.ts`). URL prefixes: kebab-case (`/focus-sessions`).
- Name features after the domain or the user-facing flow, never after a technical concern.
- Name functions after what they do: `canEditTask`, `readTasks`, `createAddTaskHandler`,
  not `taskUtils`.
- Name factories `create<Thing>` (`createAddTaskHandler`, `createValidationMiddleware`);
  name event props `on<Event>`.
- Prefer named constants over magic strings for statuses, limits, and ids
  (`IN_PROGRESS_COLUMN_ID`, `HTTP_STATUS.NOT_FOUND`).
- Avoid catch-all names: `misc/`, `stuff/`, `general/`, `helpers2/`, `utils-new/`, and a
  bare `shared/` or `common/` at the root. `features/common/` is allowed **only** with the
  meaning defined above; document it in the project's architecture file.

A vague name is an invitation to dump unrelated code. If you cannot name a folder
precisely, the grouping is probably wrong.

## Anti-patterns

Flag these when you see them. Fix them only if the task calls for it.

- A global `utils/` whose files are named after domain entities, or `utils/` importing
  from `features/`
- Every component in one top-level `components/` directory by default
- `lib/` used as a synonym for `utils/`
- A new top-level folder created to hold a single file
- A helper moved to shared code after its first reuse without evaluation
- A feature reaching into another feature's internals when a public entry point exists
- Domain logic living in route/page files, or business rules living in a backend router
- A presentational component calling the HTTP client or a data hook
- A UI primitive (button, input, card) built inside the app instead of the design system
- Hard-coded colors, spacing, radii, or font sizes instead of tokens
- `getServerSideProps` fetching the app's own API routes over HTTP
- A backend router talking to the DB model directly, or a service returning raw ORM
  documents
- `process.env` read outside the config module
- The same function copy-pasted twice inside one project

## Report

When the placement was a judgment call, tell the user in one line where the file went and
why (for example: "Kept `reorderTasks` in `features/tasks/helpers.js` because it takes a
`Task`").

## Notes & edge cases

- **Feature-based project**: follow the workflow above.

- **Layered project** (no features directory; everything under `components/`, `hooks/`,
  `utils/` or `routes/`, `services/`, `repositories/`): follow the layout that exists. Do
  not start a parallel `features/` structure unprompted, because a half-migrated project
  is worse than a consistently layered one. Keep the layered naming (`tweetsService.js`),
  mention the option to the user, and let them decide.

- **Refactoring**: only when the user explicitly asks. Then:

  1. Map current files to their owning features and share the plan before moving anything. A
     layered backend maps file-for-file: `routes/tweetsRouter.js` →
     `features/tweets/tweets.router.js`, `services/tweetsService.js` →
     `features/tweets/tweets.service.js`, and so on.
  2. Migrate one feature at a time.
  3. Move files without changing behavior. Keep structural changes separate from logic
     changes so the diff stays reviewable.
  4. Update imports, then run the linter, type checker, and tests after each feature.
  5. Leave truly generic code where it is; move only code with a domain owner.
  6. Report anything ambiguous instead of guessing its owner.
