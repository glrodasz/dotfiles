# Config and commands

Load this when adding an env var or config value, or creating or changing the Makefile
or its setup/dev targets.

Every project, frontend or backend, has two fixed entry points: a root `Makefile` for
running it and one config module for reading its environment.

## Makefile

A fresh clone reaches a running app with `make setup && make dev`, and CI calls the same
targets.

```make
.PHONY: help setup dev test lint typecheck build

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-10s %s\n", $$1, $$2}'

setup: ## Check Node, install deps, create .env, start the database
	@node -v | grep -q "^v$$(sed 's/^v//' .nvmrc)" || { echo "Node $$(cat .nvmrc) required (run: nvm use)"; exit 1; }
	npm ci
	@[ -f .env ] || cp .env.example .env
	npm run start:database

dev: ## Start the app in watch mode
	npm run dev

test: ## Run the unit tests
	npm test

lint: ## Lint the code
	npm run lint

typecheck: ## Type-check without emitting
	npm run typecheck

build: ## Build for production
	npm run build
```

- Targets delegate to `package.json` scripts. The scripts stay the source of truth; the
  Makefile adds no build logic of its own.
- `setup` is idempotent: a second run changes nothing and never overwrites an existing
  `.env`.
- `setup` uses the package manager's frozen install (`npm ci`,
  `pnpm install --frozen-lockfile`, `yarn install --immutable`).
- Include only targets the project can run: no `start:database` without a database, and
  no Node check when `.nvmrc` holds an alias like `lts/*`.
- Recipes are indented with tabs.
- A repository holding several apps (`web/`, `api/`) gets a root Makefile that calls each
  app's own: `$(MAKE) -C api setup`.
- The README's getting-started section is `make setup` and `make dev`.
- A project that already uses another task runner (`just`, Taskfile, Turborepo) keeps it,
  with the same target names, instead of gaining a Makefile.

## Config module

One module is the only reader of `process.env`: `src/config.ts` on the backend,
`config/server.js` and `config/client.js` on a Next.js frontend (split because the
browser bundle only receives `NEXT_PUBLIC_*` values). The module:

1. Declares every key in one schema: its type, whether it is required, and its default.
2. Parses on load. Numbers become numbers, booleans become booleans, enums are checked,
   so a bad value never turns into `NaN` or a `"false"` string that reads as true.
3. Fails fast. A missing or invalid key throws once, at startup (or `next build`), listing
   every problem, before a port opens or a request is served.
4. Exports a frozen, typed object with camelCase names (`config.port`,
   `config.databaseUrl`). Nothing else imports `process.env`.

- Defaults only for values that are safe in every environment (port, log level, limits).
  Credentials and external-service URLs have no default; their local values live in
  `.env.example`. A production deploy missing `DATABASE_URL` then fails at startup instead
  of connecting to localhost.
- `.env.example` is committed and lists exactly the keys the schema declares, with
  working local values and no real secrets. `.env` is gitignored.
- A change that needs a new value adds it to the schema and to `.env.example` in the same
  commit.
- Validate with the schema library the project already uses for request input (zod in
  this skill's examples). With none, write the checks by hand in the same file rather
  than adding a dependency only for config.

Code for each side is in `backend-node.md` and `frontend-nextjs.md`.
