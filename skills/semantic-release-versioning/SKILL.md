---
name: semantic-release-versioning
description: >
  Add semantic-release versioning to a GitHub repo — Conventional Commit PR titles,
  tag-only releases in 0.x, version stamped into the build and shown in the app. Use when
  the user asks to add versioning, releases, semantic-release, version tags or a version
  label to a project. Not for packages published to npm.
---

# Semantic Release Versioning

**Outcome:** every push to `main` runs semantic-release, which reads the Conventional
Commits since the last `v*` tag and creates the `vX.Y.Z` tag plus a GitHub release with
notes. Nothing is committed back to `main`, no file holds the version: **the git tag is
the source of truth**. The build stamps the version from `git describe` and the app shows
it.

## Hard rules (never violate)

1. If the package is **published to npm**, this tag-only setup is not enough (needs
   `@semantic-release/npm`): stop and ask.
2. Never add `@semantic-release/npm`, `/changelog` or `/git`: they publish or commit back
   to `main`, which this pattern avoids.
3. Run semantic-release via `npx`, never as a devDependency.
4. Don't run the squash-merge `gh api` setting unasked: offer it, it needs admin.
5. Merge into existing `AGENTS.md` / `CLAUDE.md`, never overwrite.

## Phase 0 — Survey before writing anything

- Default branch, merge strategy (squash-merge is expected, so the PR title becomes the
  commit), existing workflows (is there a deploy workflow to extend?), build tool,
  existing tags (`git ls-remote --tags origin`), `AGENTS.md` / `CLAUDE.md`, README
  structure, docs language.
- If the package is **published to npm**, this tag-only setup is not enough (needs
  `@semantic-release/npm`): stop and ask.
- Settle with the user (or take the defaults): start in **0.x** (default) or at 1.0; where
  the version shows (dev-only `?dev` badge vs always-visible small label); language
  allowed for commit summaries (e.g. English only).

## Phase 1 — `.releaserc.json`

```json
{
  "branches": ["main"],
  "tagFormat": "v${version}",
  "plugins": [
    [
      "@semantic-release/commit-analyzer",
      {
        "preset": "conventionalcommits",
        "releaseRules": [{ "breaking": true, "release": "minor" }]
      }
    ],
    ["@semantic-release/release-notes-generator", { "preset": "conventionalcommits" }],
    "@semantic-release/github"
  ]
}
```

- The `releaseRules` line keeps the project in 0.x: breaking changes bump the minor.
  Starting at ≥1.0: drop it.
- Never add `@semantic-release/npm`, `/changelog` or `/git`: they publish or commit back
  to `main`, which this pattern avoids.

## Phase 2 — Release step in CI

Extend the existing deploy workflow (a new `.github/workflows/release.yml` with the same
trigger, permissions and step only if there is none).

```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: write # semantic-release pushes the version tag and the GitHub release (main only)
  issues: write # semantic-release comments on released issues and PRs
  # ...keep the workflow's existing permissions (deployments, pull-requests)

jobs:
  deploy:
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # the build reads its version from the latest v* tag

      # ...install / test steps, if any

      # Versioning (0.x until we call it 1.0): fix -> patch, feat -> minor, see AGENTS.md and .releaserc.json.
      # Runs before the build so production ships the new version. No commit is pushed back to main.
      # Also on a manual run from main (Actions > Deploy > Run workflow), the way to recover when
      # GitHub drops the push event of a merge: it then tags and deploys what was missed.
      - name: Release
        if: (github.event_name == 'push' || github.event_name == 'workflow_dispatch') && github.ref == 'refs/heads/main'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # First run only: mark where versioning starts, or semantic-release would open at 1.0.0.
          if [ -z "$(git tag -l 'v[0-9]*')" ]; then
            git tag v0.1.0 <SHA> # main before versioning (PR #<N>)
            git push origin v0.1.0
          fi
          npx -y -p semantic-release@<X> -p conventional-changelog-conventionalcommits@<Y> semantic-release

      # ...build and deploy steps come AFTER Release
```

- `<SHA>`: current `origin/main` HEAD when writing the PR; `<N>`: the last PR merged into
  it. Skip the bootstrap block if `v*` tags already exist, or if starting at 1.0.
- Pin `<X>`/`<Y>` to the current latest (`npm view semantic-release version`,
  `npm view conventional-changelog-conventionalcommits version`), and each `uses:` action
  in both workflows to its latest major
  (`gh api repos/<owner>/<action>/releases/latest --jq .tag_name`).
- Run via `npx`, never as a devDependency: package.json and the lockfile stay untouched,
  and it works in repos without a package.json.
- `fetch-depth: 0` is required: with a shallow checkout `git describe` finds no tag.

## Phase 3 — PR title check

`.github/workflows/pr-title.yml`:

```yaml
# PRs are squash-merged, so the PR title becomes the commit on main that semantic-release reads.
# It must follow Conventional Commits (see AGENTS.md).
name: PR title

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]

permissions:
  pull-requests: read

jobs:
  conventional:
    runs-on: ubuntu-latest
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            perf
            refactor
            style
            docs
            test
            build
            ci
            chore
            revert
          requireScope: false
```

If the repo doesn't squash-merge with the PR title as commit title, tell the user; offer
(don't run unasked, needs admin):

```bash
gh api -X PATCH repos/OWNER/REPO -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
```

## Phase 4 — Stamp the version at build time

One function, same fallbacks everywhere, with `APP_VERSION` as the env override:

```js
// The version comes from the latest release tag that semantic-release created (v0.3.1 -> "0.3.1").
// Builds after that tag carry the distance and commit too ("0.3.1-4-gabc1234"); APP_VERSION overrides it.
function appVersion() {
  if (process.env.APP_VERSION) return process.env.APP_VERSION;
  const git = (cmd) => execSync(cmd, { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  try {
    return git('git describe --tags --match "v[0-9]*"').replace(/^v/, '');
  } catch {
    try {
      return `0.0.0-${git('git rev-parse --short HEAD')}`;
    } catch {
      return '0.0.0-dev';
    }
  }
}
```

Wire it to the stack:
- **Vite**: `define: { __APP_VERSION__: JSON.stringify(appVersion()) }` in
  `vite.config.ts`, `declare const __APP_VERSION__: string;` in a `globals.d.ts`, and
  `src/version.ts` exporting `VERSION`.
- **Static HTML + build script**: `<meta name="version" content="dev">` in the
  source page; the script replaces it in every generated page; the app reads
  `document.querySelector('meta[name="version"]').content`.
- **Next.js**: `env: { NEXT_PUBLIC_APP_VERSION: appVersion() }` in
  `next.config`.

## Phase 5 — Show it in the app

- Label shows the release part only: `v${VERSION.split('-')[0]}`; debug readouts (e.g.
  `?fps=1`) show the whole version.
- Hide it when the value is `dev` (unbuilt source).
- Small, monospace, `pointer-events:none`, `user-select:none`; either dev-only (`?dev`) or
  always visible next to the credit, per Phase 0.

## Phase 6 — `AGENTS.md` and `CLAUDE.md`

Merge into existing files, never overwrite. `CLAUDE.md` gets one line: `@AGENTS.md`.

`AGENTS.md` sections:
1. **Commits and PR titles: Conventional Commits**: the
   `<type>(optional scope): <short summary>` format; squash-merge note and the `PR title`
   check; summary language rule.
2. **Type table** with a project-specific "Use it for" column:
   | Type | Use it for | Version bump |
   |---|---|---|
   | `feat` | Something new for the user (project-specific examples) | minor (0.**x**.0) |
   | `fix` | A bug fix or a small polish of something that already exists | patch (0.0.**x**) |
   | `perf` | Faster or lighter, same behaviour | patch |
   | `refactor`, `style`, `docs`, `test`, `build`, `ci`, `chore` | Anything that does not change the product for the user | none |
3. **Examples**: 5–7 realistic titles drawn from the repo's own history.
4. **Versioning (0.x for now)**: semantic-release on every push to `main` (workflow +
   `.releaserc.json`), tag + release, nothing committed back; stays 0.x until the owner
   declares 1.0, breaking changes bump the minor, going to 1.0 is a deliberate
   `.releaserc.json` change (remove `releaseRules`, then merge a breaking change); manual
   Deploy run on `main` recovers a dropped push event; the git tag is the source of
   truth.
5. **Version in the app**: where it's stamped, the `0.3.0` / `0.3.0-2-gabc1234` formats,
   the env override, where it's read and shown.

## Phase 7 — README

- A **Versions** subsection next to deploy: one paragraph (semantic-release on push to
  `main`, Conventional Commits, tag + link to the repo's Releases page, bump rules, 0.x,
  where the version shows, pointer to `AGENTS.md`).
- Update the project tree (`.releaserc.json`, `AGENTS.md`, workflows line), the docs
  table, and a contributing line: PR titles follow Conventional Commits because they set
  the next version.
- Follow the README's existing conventions if the change touches diagrams.

## Phase 8 — Verify

- `.releaserc.json` parses; workflow YAML parses
  (`python3 -c 'import yaml,sys;yaml.safe_load(open(sys.argv[1]))' <file>`).
- Run the build locally: it prints/stamps `0.0.0-<sha>` (no tags yet) or the
  `APP_VERSION` override; open the page and check the label (hidden on `dev`).
- Bootstrap SHA exists on `main` (`git cat-file -e <SHA>`).

Fix any failing check and rerun them all before opening the PR. If one can't pass, stop
and list it in the report.

## Phase 9 — Open the PR

- Title: `feat: …` when the PR adds a visible version label (first release, 0.2.0,
  happens on merge); `ci: version with semantic-release` otherwise (no release until the
  next `feat`/`fix`).
- Body: what each file does, the bootstrap tag and SHA, the permissions change, the
  squash-merge setting if it's missing, and screenshots of the label.
- After merge, tell the user to check the Actions run and the Releases page.

## Report

```
## Versioning added

### Changes made
- <file>: <what it does, one line each>
- Bootstrap tag: v0.1.0 at <SHA> (or: skipped — <reason>)
- Pinned: semantic-release@<X>, conventional-changelog-conventionalcommits@<Y>

### Still needs human attention
- <squash-merge setting, failed checks, unstamped version — or "none">
- After merge: check the Actions run and the Releases page
```

## Notes & edge cases

- **No build step**: do the release only (Phases 1–3, 6–7), skip Phases 4–5, and say in
  the report that the version isn't stamped.
- **Cancelled runs**: a `cancel-in-progress` concurrency group is fine: the next run
  releases the commits a cancelled one missed.
- **Dropped push events**: GitHub sometimes drops the push event of a merge; a manual run
  of the workflow on `main` tags and deploys what was missed.
