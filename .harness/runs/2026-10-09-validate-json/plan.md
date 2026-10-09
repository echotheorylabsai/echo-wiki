# Plan — 2026-10-09-validate-json

## Goal

Add a `--json` flag to `hooks/validate.sh` that combines with `--all`, `--staged`, explicit paths or no
mode, and prints exactly one JSON object on stdout: `{"files_validated": N, "violations": [{"file": …,
"message": …}, …]}`. Exit codes stay 0 (clean) / 1 (violations). Output without `--json` is
byte-for-byte unchanged. Stays Bash 3.2 compatible with no new runtime dependency. Tests go in
`tests/run-tests.sh`; the flag is documented wherever users read `validate.sh` usage.

## Outcome

A tool or agent can run `./hooks/validate.sh --json [--all|--staged|<paths>]` and parse stdout as JSON
to get the validated-file count and every violation as a separate file/message pair, with quotes and
backslashes correctly escaped. Human output, exit codes and existing tests are unaffected.

## Acceptance checks

All checks run the validator with `/bin/bash` (Bash 3.2 on macOS) and parse JSON with Ruby, which the
validator already requires; the parser is used only by the checks, never by `validate.sh --json`.

### C1 — Full test suite passes
Expected: `tests/run-tests.sh` exits 0 with zero failures.
```sh
bash tests/run-tests.sh
```

### C2 — Output without --json is byte-for-byte unchanged
Expected: on both fixtures, for no args, `--all`, `--staged` and an explicit path list (including a missing path), stdout, stderr and exit code match the base branch's `validate.sh` exactly.
```sh
repo=$PWD; t=$(mktemp -d) && git show "$(git merge-base origin/main HEAD)":hooks/validate.sh > "$t/old.sh" || exit 1; rc=0
for fx in populated invalid; do
  cp -R "tests/fixtures/$fx" "$t/$fx" && (cd "$t/$fx" && git init -q && git add -A) || exit 1
  paths="$(cd "$t/$fx" && find wiki raw -type f -name '*.md' | sort | tr '\n' ' ') missing.md"
  for args in "" "--all" "--staged" "$paths"; do
    for v in old new; do
      if [ "$v" = old ]; then s="$t/old.sh"; else s="$repo/hooks/validate.sh"; fi
      (cd "$t/$fx" && ECHO_WIKI_ROOT="$t/$fx" /bin/bash "$s" $args > "$t/$v.out" 2> "$t/$v.err"; echo $? > "$t/$v.rc")
    done
    cmp -s "$t/old.out" "$t/new.out" && cmp -s "$t/old.err" "$t/new.err" && cmp -s "$t/old.rc" "$t/new.rc" || { echo "differs: $fx [$args]"; rc=1; }
  done
done; exit $rc
```

### C3 — Clean run prints one JSON object, flag in any position
Expected: on the populated fixture, `--json`, `--all --json` and `--json --all` each exit 0 and stdout parses (whole) as exactly `{"files_validated": 12, "violations": []}`.
```sh
repo=$PWD; t=$(mktemp -d) && cp -R tests/fixtures/populated "$t/fx" || exit 1
for args in "--json" "--all --json" "--json --all"; do
  out=$(cd "$t/fx" && ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" $args 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || { echo "rc=$rc for [$args]"; exit 1; }
  printf '%s' "$out" | ruby -rjson -e 'exit(JSON.parse(STDIN.read) == {"files_validated" => 12, "violations" => []} ? 0 : 1)' || { echo "bad json for [$args]: $out"; exit 1; }
done
```

### C4 — Violations JSON matches text output; explicit paths with trailing --json
Expected: on the invalid fixture, `--json --all` exits 1 and its violations, rendered as `<file>: <message>`, equal the text-mode violation lines in order; `bad-date.md bad-tag.md --json` exits 1, reports `files_validated` 2 and violations for both files.
```sh
repo=$PWD; t=$(mktemp -d) && cp -R tests/fixtures/invalid "$t/fx" && cd "$t/fx" || exit 1
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" --all > "$t/text" 2>/dev/null; [ $? -eq 1 ] || { echo "text rc"; exit 1; }
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" --json --all > "$t/json" 2>/dev/null; [ $? -eq 1 ] || { echo "json rc"; exit 1; }
ruby -rjson -e 'd = JSON.parse(File.read(ARGV[0])); lines = File.readlines(ARGV[1], chomp: true)[0...-1]
  got = d["violations"].map { |v| "#{v["file"]}: #{v["message"]}" }
  abort "violations differ from text output" unless !got.empty? && got == lines && d["files_validated"].is_a?(Integer)' "$t/json" "$t/text" || exit 1
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" wiki/concepts/bad-date.md wiki/concepts/bad-tag.md --json > "$t/two" 2>/dev/null; [ $? -eq 1 ] || { echo "paths rc"; exit 1; }
ruby -rjson -e 'd = JSON.parse(File.read(ARGV[0])); files = d["violations"].map { |v| v["file"] }
  abort "paths json wrong: #{d}" unless d["files_validated"] == 2 && (["wiki/concepts/bad-date.md", "wiki/concepts/bad-tag.md"] - files).empty?' "$t/two"
```

### C5 — --staged combines with --json
Expected: in a git-initialised copy of the invalid fixture with everything staged, `--staged --json` exits 1 and its violations equal the `--staged` text-mode lines in order.
```sh
repo=$PWD; t=$(mktemp -d) && cp -R tests/fixtures/invalid "$t/fx" && cd "$t/fx" && git init -q && git add -A || exit 1
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" --staged > "$t/text" 2>/dev/null; [ $? -eq 1 ] || { echo "text rc"; exit 1; }
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" --staged --json > "$t/json" 2>/dev/null; [ $? -eq 1 ] || { echo "json rc"; exit 1; }
ruby -rjson -e 'd = JSON.parse(File.read(ARGV[0])); lines = File.readlines(ARGV[1], chomp: true)[0...-1]
  got = d["violations"].map { |v| "#{v["file"]}: #{v["message"]}" }
  abort "staged violations differ" unless !got.empty? && got == lines' "$t/json" "$t/text"
```

### C6 — Double quotes and backslashes are escaped in file and message
Expected: two workspace notes with `created: '20"26\x'`, one named `quote.md` and one named `q"\x.md`, produce JSON that parses and contains both exact file/message pairs; exit 1.
```sh
repo=$PWD; t=$(mktemp -d) && cp -R tests/fixtures/populated "$t/fx" && cd "$t/fx" || exit 1
cat > wiki/workspaces/my-notes/quote.md <<'EOF'
---
title: Quote check
created: '20"26\x'
---
# Note
EOF
cp wiki/workspaces/my-notes/quote.md 'wiki/workspaces/my-notes/q"\x.md' || exit 1
ECHO_WIKI_ROOT="$t/fx" /bin/bash "$repo/hooks/validate.sh" --json > "$t/json" 2>/dev/null; [ $? -eq 1 ] || { echo "rc"; exit 1; }
ruby -rjson -e 'd = JSON.parse(File.read(ARGV[0])); msg = %q(invalid date format in '"'"'created'"'"' (expected YYYY-MM-DD, got '"'"'20"26\x'"'"'))
  want = [{"file" => "wiki/workspaces/my-notes/quote.md", "message" => msg}, {"file" => %q(wiki/workspaces/my-notes/q"\x.md), "message" => msg}]
  abort "escaping wrong: #{d}" unless (want - d["violations"]).empty?' "$t/json"
```

### C7 — Bash 3.2 syntax and no new runtime dependency
Expected: `/bin/bash` is 3.2 and parses the script; lines added to `validate.sh` call no jq, python, perl, node or ruby and use no Bash 4-only features.
```sh
case "$(/bin/bash -c 'echo $BASH_VERSION')" in 3.2*) ;; *) echo "/bin/bash is not 3.2"; exit 1 ;; esac
/bin/bash -n hooks/validate.sh || exit 1
! git diff "$(git merge-base origin/main HEAD)" -- hooks/validate.sh | grep '^+[^+]' \
  | grep -nE '(^|[^A-Za-z_])(jq|python[0-9.]*|perl|node|ruby)([^A-Za-z_]|$)|declare -A|mapfile|readarray|\$\{[^}]*(,,|\^\^)'
```

### C8 — New --json tests exist in the repo's test runner and pass
Expected: `tests/run-tests.sh` prints at least three passing lines labelled `ok - validate --json: …`, one of which mentions `quote`.
```sh
out=$(bash tests/run-tests.sh 2>&1)
[ "$(printf '%s\n' "$out" | grep -c '^ok - validate --json: ')" -ge 3 ] && printf '%s\n' "$out" | grep -q '^ok - validate --json: .*quote'
```

### C9 — The flag is documented where users read validate.sh usage
Expected: `--json` appears in the script's usage header, `docs/validation.md`, `README.md` and `CLAUDE.md`.
```sh
for f in docs/validation.md README.md CLAUDE.md; do grep -qF -- '--json' "$f" || { echo "missing in $f"; exit 1; }; done
sed -n '1,25p' hooks/validate.sh | grep -qF -- '--json'
```

## Tier

M — a multi-file change to existing code: the validator, its test runner and several docs files.
C1–C9 are all runnable.

## Source

prompt

## Milestones

## Decisions

- 2026-10-09 10:40 · claude/opus-5.5 · triage — Tier M; stop after the plan phase for user review. [Why: request.md asks to review the plan before code.]
- 2026-10-09 10:40 · claude/opus-5.5 · triage — JSON escaping uses sed/awk only; no new `ruby` calls in `validate.sh`. [Why: "no new runtime dependency" in spirit; keeps --json pure shell.] [Check: C7]
- 2026-10-09 10:40 · claude/opus-5.5 · triage — Violations stored as separate file/message fields, text line rendered from them. [Why: messages contain ": ", so splitting text lines is unsafe.] [Cites: hooks/validate.sh:30]

## Unknowns

- 2026-10-09 10:40 · claude/opus-5.5 · triage — JSON key names unspecified; defaulted to `files_validated`, `violations[].file`, `violations[].message`. [Why: plain, self-describing names.] [Check: goal]
- 2026-10-09 10:40 · claude/opus-5.5 · triage — Structure problems use pseudo-file `structure`; JSON keeps it as the `file` value. [Why: mirrors text output.] [Cites: hooks/validate.sh:541]

## Friction
