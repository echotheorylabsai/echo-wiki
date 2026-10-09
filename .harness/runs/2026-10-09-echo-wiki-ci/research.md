# Research — 2026-10-09-echo-wiki-ci

## Areas the task touches

### 1. Existing workflow (pattern to mirror, must stay unchanged)
- `.github/workflows/deploy-docs.yml:3-9` — triggers on push to `main` (docs paths) and `workflow_dispatch`.
- `.github/workflows/deploy-docs.yml:25,30` — `actions/checkout@v4`, `actions/setup-node@v4` (major pins); `node-version: 20`, `cache: npm` at `:32-33`.
- `.github/workflows/deploy-docs.yml:16-18` — its concurrency group is `pages`; a new workflow must use its own group.

### 2. Hook test suite (job 1)
- Entry: `bash tests/run-tests.sh` (`tests/run-tests.sh:5`); claims Bash 3.2 compatibility (`:6`).
- Computes `REPO` from its own path (`:10`), so it runs from any working directory.
- Calls hooks directly, e.g. `"$REPO/hooks/validate.sh"` (`:103`), `"$REPO/hooks/reindex.sh"` (`:49`); every hook starts `#!/usr/bin/env bash` (`hooks/validate.sh:1`), so the Bash used is whichever `bash` is first on `PATH`.
- Needs `ruby` (`:77`, `:88`, `:149`, `:210`), `git` (`:843-844` sets a local user for its throwaway repo), `mktemp`, `diff`, `sed`.
- Exit status: `[ "$FAIL" -eq 0 ]` at `:976`; summary line `N passed, M failed` at `:975`.
- Locally (`/bin/bash` is the only `bash` on PATH, i.e. 3.2): 100 passed, 0 failed (triage dry run).

### 3. Wiki validation (job 2)
- `./hooks/validate.sh --all` checks every `.md` under `wiki/` and `raw/` (`docs/validation.md:11`); a structure guard always runs first (`docs/validation.md:53`).
- Repo ships only the empty skeleton: tracked `wiki/` and `raw/` files are `.gitkeep`, `_index.md`, `_backlinks.md`, `.obsidian/*`. Local result: `OK: 0 files validated`.
- This checkout has the pre-commit hook installed; commits print `Pre-commit validation passed`, so the repo already expects `validate.sh` to pass on every commit.

### 4. Docs build (job 3)
- `package.json:7` — `docs:build` = `vitepress build docs`; lockfile present (`package-lock.json`), so `npm ci` works. Local build passes (vitepress 1.6.4).
- Docs require Node 18+ (`docs/getting-started.md:16`); deploy uses 20.

### 5. Contributor docs (where checks are described)
- `docs/validation.md:98-109` `## Tests` — lists `bash tests/run-tests.sh` and `ruby tests/onboarding-test.rb`. One CI paragraph goes here.
- `docs/getting-started.md:10-16` — prerequisites table (Bash 3.2+, Ruby 2.6+, Node 18+); no change needed.

### 6. Harness PR gate (affects C8)
- `lean-harness/harness/commands/pr.py:48-50` — `harness pr` refuses unless every final check, observational ones included, has a pass at the current code tree.
- `lean-harness/harness/gate.py:28-32` — a check with no recorded attempt fails.
- So C8 cannot be observed before `harness pr`, and `harness pr` cannot run before C8 passes.

## Runner facts relied on
- `actions/checkout`, `actions/setup-node` major `v4` as in deploy-docs.
- macOS runners may put a newer Homebrew Bash ahead of `/bin/bash`; a PATH shim (`ln -s /bin/bash <dir>/bash`, prepend via `$GITHUB_PATH`) forces 3.2, and a `bash --version` step proves it.
- Ruby availability on both runners is unconfirmed until the first run (logged as Unknown).

## Project commands
| Purpose | Command |
|---|---|
| Hook tests | `bash tests/run-tests.sh` |
| Wiki validation | `./hooks/validate.sh --all` |
| Docs build | `npm ci && npm run docs:build` |
