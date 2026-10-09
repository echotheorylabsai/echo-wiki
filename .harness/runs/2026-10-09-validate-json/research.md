# Research — 2026-10-09-validate-json

## Validator: `hooks/validate.sh`

- Header usage comment lists the three modes and the text output contract. [Cites: hooks/validate.sh:6-20]
- `set -uo pipefail`, `LC_ALL=C`; root from `$ECHO_WIKI_ROOT` or git. [Cites: hooks/validate.sh:21-24]
- Every violation goes through `err()`, which appends the joined line `"$1: $2"` to `$ERR_FILE`. File and message are not stored separately. [Cites: hooks/validate.sh:27-32]
- Structure checks run before argument parsing and report with the pseudo-file `structure` (and real paths for symlinks). [Cites: hooks/validate.sh:539-572]
- Argument parsing: `MODE="${1:---all}"`; `--all` / `--staged` look only at `$1`; anything else treats **all** of `"$@"` as paths. So `--json` must be removed from the argument list before line 579, or it would be treated as a mode/path (spike confirmed: `--json: path not found`). [Cites: hooks/validate.sh:579-600]
- Explicit-path errors (`path not found`, symlink) are also `err()` calls, so they flow into JSON naturally. [Cites: hooks/validate.sh:591,594]
- `VALIDATED` counts files that reached a zone validator; skipped files print `NOTE:` to **stderr**. [Cites: hooks/validate.sh:604-630]
- Report: on errors, `cat $ERR_FILE`, then `Validation failed: N issue(s)`, exit 1; else `OK: N files validated`, exit 0. This block is the only place output is produced on stdout. [Cites: hooks/validate.sh:634-640]
- Messages can contain `"` and `\` from user data (e.g. `got '$v'` in `check_date`), and `: ` appears inside many messages. [Cites: hooks/validate.sh:139]
- Ruby already parses frontmatter and config; frontmatter values with control characters are rejected, but file **paths** are not checked for control characters. [Cites: hooks/validate.sh:405-419]

## Callers of validate.sh (must not change behaviour)

- `hooks/pre-commit.sh` runs `--all` on a materialized index and prefixes each output line. [Cites: hooks/pre-commit.sh:18-24]
- `hooks/rebuild-transaction.sh`, onboarding `bootstrap.rb` (`--all`), and skill docs (`--all`, explicit paths). [Cites: .claude/skills/onboard/scripts/bootstrap.rb:116]
- None pass `--json`; all rely on the text output, which stays unchanged.

## Tests: `tests/run-tests.sh`

- Plain Bash 3.2 runner; `ok`/`not_ok` print `ok - <label>`; `new_fixture` copies `tests/fixtures/<name>` to a temp dir. [Cites: tests/run-tests.sh:17-25]
- `run_validate <root> args…` sets `VOUT` (stdout+stderr merged) and `VRC`. [Cites: tests/run-tests.sh:100-105]
- Existing validate cases: populated `--all` = `OK: 12 files validated`; `expect_violation` per invalid fixture file. [Cites: tests/run-tests.sh:107-135]
- Tests already shell out to `ruby` (e.g. inline YAML edits), so parsing JSON with `ruby -rjson` in tests adds no new test dependency. [Cites: tests/run-tests.sh:76]
- Test functions are invoked from an explicit list at the bottom; new tests must be added there. [Cites: tests/run-tests.sh:847]
- Fixtures: `populated` (12 valid files, includes `wiki/workspaces/my-notes/`), `invalid` (48 violations under `--all`).
- Command: `bash tests/run-tests.sh` (97 passing today, from the triage spike).

## User-facing docs that show validate.sh usage

| File | Where | Change |
|---|---|---|
| `hooks/validate.sh` | header, lines 6-18 | add `--json` usage + output shape |
| `docs/validation.md` | usage block, lines 9-14 | add `--json` line + short "JSON output" section |
| `README.md` | line 216 | add `[--json]` to the usage bullet |
| `CLAUDE.md` | line 47 | add `[--json]` to the usage bullet |
| `docs/troubleshooting.md` | usage block, lines 20-24 | add one `--json` line |

Not changed: `AGENTS.md`/`GEMINI.md` (no flag list), skill docs and `onboard/references/finish.md` (they prescribe specific modes; tests grep exact skill strings, e.g. tests/run-tests.sh:251).

## Environment

- `/bin/bash` is 3.2 on this machine; `/usr/bin/awk` is BSD awk; Ruby 2.6 (system) — confirmed by spike output.
- Bash 3.2 pitfalls: `"${arr[@]}"` on empty array under `set -u` errors; `${v//\\/\\\\}` behaves differently from Bash 4+. Avoid both.
