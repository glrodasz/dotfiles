# Backend: Node.js (TypeScript) feature modules

Load this when adding or changing endpoints, routers, services, persistence, validation, error handling, config, or backend tests in an Express or Fastify service.

Reference implementations: `cero-api/typescript-express` and `cero-api/typescript-fastify` (feature folders, ESM, Mongoose) for structure; the `twittr` course project for the layers added on demand (validation middleware, error pipeline, testable server). Follow the project's own docs where they exist.

## Contents

- [Feature layout](#feature-layout)
- [Roles](#roles)
- [Layers on demand](#layers-on-demand)
- [Infrastructure](#infrastructure)
- [Composition: app vs server](#composition-app-vs-server)
- [Errors and responses](#errors-and-responses)
- [Cross-feature use](#cross-feature-use)
- [Testing](#testing)
- [Tooling and deploy](#tooling-and-deploy)
- [Mapping a layered project](#mapping-a-layered-project)

## Feature layout

Start with three files per feature. Add the others only when their trigger applies.

```text
src/
├── features/
│   ├── tasks/
│   │   ├── Task.ts                  always: domain types + domain constants
│   │   ├── tasks.router.ts          always: HTTP
│   │   ├── tasks.service.ts         always: business operations
│   │   ├── tasks.schema.ts          on demand: request validation
│   │   ├── tasks.repository.ts      on demand: persistence
│   │   ├── tasks.service.test.ts
│   │   └── tasks.router.test.ts
│   ├── focusSessions/
│   └── common/                      cross-feature domain pieces, only if any
├── lib/                             db.ts, logger.ts
├── utils/                           httpStatus.ts, isEmpty.ts (domain-free)
├── errors/                          (on demand) typed domain errors: NotFoundError, ConflictError
├── middlewares/                     errorHandlers.ts, notFound.ts, createValidationMiddleware.ts
├── config.ts
├── app.ts
└── server.ts
```

Naming:

- Feature folder: camelCase plural (`focusSessions/`). URL prefix: kebab-case (`/focus-sessions`).
- Role files: `<feature>.<role>.ts`. Entity file: singular PascalCase (`FocusSession.ts`).
- ESM with `"type": "module"` and `moduleResolution: NodeNext`: relative imports end in `.js` (`./tasks.service.js`). Use `import type` for types.
- IDs and fields are typed through the entity: `Task["id"]`, `Omit<Task, "id">`.

## Roles

### `<Entity>.ts` — the contract

Domain types and domain constants only. No framework, no ORM.

```ts
export type TaskStatus = "in-progress" | "pending" | "completed";
export const ACTIVE_TASK_STATUSES: TaskStatus[] = ["in-progress", "pending"];

export type Task = {
  id: string;
  description: string;
  priority: number;
  status: TaskStatus;
  focusSessionId: string | null;
};
```

This file is the API contract the frontend mirrors. Change it deliberately and update the consumer in the same change. When several implementations of the same API exist, keep their entity files identical.

### `<feature>.router.ts` — HTTP only

Owns routes, reading `params`/`query`/`body`, calling the validator, calling the service, mapping results to status codes. No business rules, no DB access.

The feature mounts itself, so `app.ts` only lists features:

```ts
// Express
const tasksRouter: Router = Router();
tasksRouter.get("/:id", async (req, res: Response<Task | ErrorResponse>, next) => {
  try {
    const task = await tasksService.getTask(req.params.id);
    if (!task) return res.status(HTTP_STATUS.NOT_FOUND).json({ message: "Task not found" });
    res.status(HTTP_STATUS.OK).json(task);
  } catch (error) {
    next(error);
  }
});
export default (app: Application) => { app.use("/tasks", tasksRouter); };

// Fastify
export default async function tasksRouter(app: FastifyInstance) { app.get("/:id", ...) }
// app.ts: app.register(tasksRouter, { prefix: "/tasks" })
```

- Every handler either responds or forwards the error (`next(error)` in Express; throw in Fastify and let `setErrorHandler` answer). Don't catch-and-reply per route in Fastify; it bypasses the global handler.
- Order specific routes before parameterized ones (`/active` before `/:id`).
- Type responses: `Response<Task[] | ErrorResponse>`.

### `<feature>.service.ts` — business operations

An object of async functions named by intent. Returns domain types, never ORM documents. Returns `null` for "not found" (the router maps it to 404). An operation that is not allowed in the current state throws a typed domain error (`ConflictError`), which the error pipeline maps to 409; never overload `null` with two meanings.

```ts
const toTask = (task: TaskDocument): Task => ({
  id: task.id, description: task.description, priority: task.priority,
  status: task.status, focusSessionId: task.focusSessionId,
});

export const tasksService = {
  getTask: async (id: Task["id"]): Promise<Task | null> => {
    if (!isValidObjectId(id)) return null;
    const task = await TaskModel.findById(id).exec();
    return task ? toTask(task) : null;
  },
};
```

- **Business rules live here**, not in the router: priority limits, reordering, "only one active session", status transitions.
- Limits that are configuration (`MAXIMUM_IN_PRIORITY_TASKS`) come from `config.ts`; limits that are domain facts go in `<Entity>.ts`.
- While there is no repository, the ORM schema, model, and `toX()` mapper live at the top of the service, private to it.

## Layers on demand

Add a layer when its trigger applies, not before. Each addition keeps the same naming.

| Add | When | What moves there |
|---|---|---|
| `<feature>.schema.ts` + `createValidationMiddleware` | Input validation is more than one or two field checks, or the same shape is checked in several routes | Request schemas per route: `createTaskSchema`, `taskIdSchema`, `updateTaskSchema` |
| `<feature>.repository.ts` | The service mixes business logic with non-trivial queries, a second store appears, or you need to unit-test business logic without the ORM | ORM schema, model, mapper, and data-access functions; the service calls the repository |
| `<feature>.helpers.ts` | Pure domain functions in the service grow beyond a few lines | Pure business functions, unit-tested alone |
| `<feature>.controller.ts` | Rarely. Only if route handlers become large enough that the route table is hard to read | Handler functions; the router keeps the route table |

Validation conventions (from `twittr`):

- One middleware factory, shared across features in `src/middlewares/`: `createValidationMiddleware({ body: schema })` / `({ params: schema })`, which forwards a 400 on failure.
- Use the project's validation library. If there is none, prefer one that infers TypeScript types from the schema (so the handler's `req.body` type comes from the schema, not a hand-written type guard). Don't keep both a schema and a duplicate type guard.
- Schemas are composed from small reusable pieces and exported per route. The course project (plain JS) does it with Joi:
  `const idSchema = joi.number(); const tweetIdSchema = { tweetId: idSchema.required() }`.
  In TypeScript, the same idea with a type-inferring library:
  `const taskIdSchema = z.object({ id: z.string() }); export type CreateTaskBody = z.infer<typeof createTaskSchema>`.

## Infrastructure

| File | Owns |
|---|---|
| `src/config.ts` | The only reader of `process.env`. Exports a typed `as const` object with defaults for local dev. `.env.example` lists exactly the keys `config.ts` reads. |
| `src/lib/db.ts` | DB connection (`connectDatabase()`), called from `server.ts`. No credentials inline; they come from `config`. |
| `src/lib/logger.ts` | One logger (framework logger in Fastify; `debug` namespaces like `app:server`, `app:database` or a pino instance in Express). No bare `console.log` in features. |
| `src/middlewares/` | Error pipeline, not-found, validation factory, cache headers. Generic: never imports a feature. |
| `src/utils/httpStatus.ts` | `HTTP_STATUS` constants. Domain-free, so it lives in `utils/` where middlewares and features can both import it. (cero-api currently keeps it in `src/features/common/constants.ts`; move it when middlewares need it.) |
| `src/errors/` | Typed errors carrying an HTTP status (`NotFoundError`, `ConflictError`, `ValidationError`); thrown by services, translated by `wrapErrors`/`errorHandler`. |

Middleware factories take their config-driven switches as defaulted parameters so tests can flip them: `createCacheMiddleware(seconds, isActive = !config.dev)`, `withErrorStack(error, stack, isStackShown = config.dev)`.

## Composition: app vs server

Split as soon as there is a test:

```ts
// app.ts — builds the app, no side effects
export const createApp = () => {
  const app = express();
  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json());
  tasksRouter(app);
  focusSessionsRouter(app);
  app.use(notFoundHandler);
  app.use(logErrors, wrapErrors, errorHandler);
  return app;
};

// server.ts — side effects only
await connectDatabase();
createApp().listen(config.port, () => logger(`Listening on ${config.port}`));
```

Importing `app.ts` must never connect to a DB or open a port.

## Errors and responses

- Resources are returned bare (no envelope). Errors are `{ message: string }` (or the error library's payload, consistently).
- Status codes through constants (`HTTP_STATUS.OK`, `.CREATED`, `.BAD_REQUEST`, `.NOT_FOUND`, `.INTERNAL_SERVER_ERROR`). 201 for creation; 404 when the service returns `null`.
- Error pipeline (Express), in `src/middlewares/errorHandlers.ts`:
  1. `notFoundHandler` — unmatched route → 404.
  2. `logErrors` — log once, with request context.
  3. `wrapErrors` — convert unknown errors into the HTTP error type (e.g. `boom.badImplementation(err)`). **`return next(...)`** so `next` is called once.
  4. `errorHandler` — respond with the status and payload; include the stack only in development.
- Signals: `null` = not found (router → 404); typed `ConflictError` = invalid state (pipeline → 409); validation failure = 400 from the middleware. If a project prefers throwing `NotFoundError` instead of returning `null`, do that everywhere — one convention per project.
- Never trust input in queries: validate ids (`isValidObjectId`) before using them; never build a `RegExp` from request input.

## Cross-feature use

- A router may call another feature's service (`tasks.router` asking `focusSessionsService.getActiveSession()`), and an entity file may reference another's type with `import type`.
- Services should not import each other in both directions. If two services need each other, move the orchestration into the router (simple cases) or into a service of the feature that owns the flow.
- If the project gives features an `index.ts`, import through it; otherwise import the specific file.

## Testing

Same style as the frontend, so the whole stack reads alike:

- Co-located `*.test.ts` next to the file under test.
- `describe('[ features / tasks / tasksService ]')` → `describe('#getTask')` → `it('should …')`; Arrange / Act / Assert markers; `result` / `expected`.
- Mock the layer directly below: router tests mock the service; service tests mock the repository (or the model while there is no repository).
- Router tests run through a minimal app via supertest, mounting only the router under test:

```ts
export const testServer = (mount: (app: Application) => void) => {
  const app = express();
  app.use(express.json());
  mount(app);
  return supertest(app);
};
```

- Integration tests against a real DB (docker-compose or an in-memory server) are separate from the unit run.
- Required scripts: `test`, `typecheck` (`tsc --noEmit`), `lint`.

## Tooling and deploy

- `package.json` scripts: `dev` (`tsx watch --env-file=.env src/server.ts`), `build` (`tsc` with `outDir: dist`), `start` (`node dist/server.js`), `typecheck`, `lint`, `test`, plus database helpers (`start:database`, `stop:database`).
- `tsconfig`: `strict`, `module`/`moduleResolution: NodeNext`, explicit `rootDir: src` and `outDir: dist`.
- Lint/format config must match the code actually in the repo and be installed and run in CI; dead config is worse than none.
- Dockerfile: multi-stage (deps → build → slim runtime), Node version equal to `.nvmrc`/`engines`, the package manager's own frozen-install flag (`yarn install --immutable` for Yarn Berry), `NODE_ENV=production`, `CMD ["node", "dist/server.js"]`. Platform config (`fly.toml`) next to it.

## Mapping a layered project

A layered backend (`routes/`, `services/`, `repositories/`, `utils/schemas/`) maps file-for-file when the user asks to migrate:

| Layered | Feature-based |
|---|---|
| `routes/tweetsRouter.js` | `features/tweets/tweets.router.js` |
| `services/tweetsService.js` | `features/tweets/tweets.service.js` |
| `repositories/tweetsRepository.js` | `features/tweets/tweets.repository.js` |
| `utils/schemas/tweetsSchema.js` | `features/tweets/tweets.schema.js` |
| `utils/middlewares/*` | `middlewares/*` |
| `lib/connect.js`, `config/index.js` | `lib/db.js`, `config.js` (unchanged role) |

Until then, keep adding code in the layered style the project already uses.
