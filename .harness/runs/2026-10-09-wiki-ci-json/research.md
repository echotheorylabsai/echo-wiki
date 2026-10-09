# Research — 2026-10-09-wiki-ci-json

## Areas touched

### CI workflow — `.github/workflows/ci.yml`
- Triggers: every `pull_request`, and `push` to `main` (`.github/workflows/ci.yml:3-6`).
- `cancel-in-progress: true` per head ref (`.github/workflows/ci.yml:11-13`): a quick second push cancels the first run.
- `validate` job: ubuntu-latest, checkout, then `./hooks/validate.sh --all` (`.github/workflows/ci.yml:43-51`). This is the only job to change.
- Steps set no `shell:`, so GitHub runs them as `bash -e {0}` — no pipefail. Write the output to a file, not a pipe.
- Other jobs (`tests` at `:16-41`, `docs` at `:53-70`) and `deploy-docs.yml` stay untouched.

### `--json` producer — `hooks/validate.sh`
- `--json` may be combined with any mode (`hooks/validate.sh:11`); parsed at `:29-38`.
- Documented shape: `{"files_validated":N,"violations":[{"file","message"},...]}` (`hooks/validate.sh:18-19`).
- Emitted by one awk `printf` at `hooks/validate.sh:649-671`; exit 1 when violations exist, else 0.
- `NOTE:` lines go to stderr (`hooks/validate.sh:643`), so stdout holds only the JSON.

### Existing tests — `tests/run-tests.sh`
- Already parse `--json` stdout with `ruby -rjson` (`tests/run-tests.sh:139-181`, wired at `:941-943`).
- So Ruby's bundled `json` is the established parser here; the `tests` job prints `ruby --version` on ubuntu-latest without installing it (`.github/workflows/ci.yml:35-38`), proving Ruby is preinstalled.

## Project commands
- Validate: `./hooks/validate.sh --all [--json]`.
- Hook tests: `bash tests/run-tests.sh` (CI `tests` job).
- Acceptance: `harness check --all` runs C1–C4 locally; C5 is read from `gh pr checks`.

## Design for the new step
1. `./hooks/validate.sh --all --json > "$RUNNER_TEMP/validate.json"` on its own line (C2 swaps exactly this text).
2. `ruby -rjson -e '…' "$RUNNER_TEMP/validate.json"`: parse; require a Hash with an Integer `files_validated` and an Array `violations`; else exit non-zero with a message.
3. Use `$RUNNER_TEMP`, never `${{ runner.temp }}`, so the local check runs the same text.
