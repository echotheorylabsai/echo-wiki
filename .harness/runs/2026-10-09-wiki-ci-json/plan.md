# Plan — 2026-10-09-wiki-ci-json

## Goal

Make echo-wiki's CI prove that `./hooks/validate.sh --all --json` prints valid JSON, so empty or
garbled output fails the `validate` job even when the script's exit status is 0.

## Outcome

The `validate` job in `.github/workflows/ci.yml` gains one step that runs
`./hooks/validate.sh --all --json`, saves its output, and parses it with the runner's preinstalled
Ruby (`json` is in its standard library); the step fails on empty, garbled, or wrongly shaped output. No other job, no
`deploy-docs.yml`, no new action or dependency changes. CI passes on this task's PR.

## Acceptance checks

### C1 — the new CI step passes on the real `--json` output
Expected: a `validate` step whose `run` contains `validate.sh --all --json` exists and, run the way
GitHub runs it (`bash -e`), exits 0.
```sh
ruby -ryaml -rtmpdir -e 's=YAML.load_file(".github/workflows/ci.yml")["jobs"]["validate"]["steps"].map{|x|x["run"].to_s}.find{|r|r.include?("./hooks/validate.sh --all --json")} or abort("no --json step"); ENV["RUNNER_TEMP"]=Dir.mktmpdir; exit(system("bash","-e","-c",s) ? 0 : 1)'
```

### C2 — the new CI step fails on empty, garbled and wrongly shaped output
Expected: with `./hooks/validate.sh --all --json` swapped for a fake that prints nothing, prints
broken JSON, or prints `null`, the step exits non-zero every time.
```sh
ruby -ryaml -rtmpdir -e 's=YAML.load_file(".github/workflows/ci.yml")["jobs"]["validate"]["steps"].map{|x|x["run"].to_s}.find{|r|r.include?("./hooks/validate.sh --all --json")} or abort("no --json step"); fakes=["printf \"\"", "echo \"{garbled\"", "echo null"]; ok=fakes.all?{|f| ENV["RUNNER_TEMP"]=Dir.mktmpdir; t=s.sub("./hooks/validate.sh --all --json", f); t!=s && !system("bash","-e","-c",t, out: File::NULL, err: File::NULL)}; exit(ok ? 0 : 1)'
```

### C3 — other jobs, workflow settings and existing validate steps are unchanged; no new action
Expected: compared with the merge-base, every top-level key and every job except `validate` is
identical, the old `validate` steps all remain, and the `validate` job uses the same actions.
```sh
ruby -ryaml -e 'b=`git merge-base HEAD origin/main`.strip; abort("no base") if b.empty?; o=YAML.load(`git show #{b}:.github/workflows/ci.yml`); n=YAML.load_file(".github/workflows/ci.yml"); u=->(j){j["steps"].map{|x|x["uses"]}.compact}; ok=o.reject{|k,_|k=="jobs"}==n.reject{|k,_|k=="jobs"} && o["jobs"].keys==n["jobs"].keys && o["jobs"].all?{|k,v| k=="validate" || v==n["jobs"][k]} && u[o["jobs"]["validate"]]==u[n["jobs"]["validate"]] && (o["jobs"]["validate"]["steps"]-n["jobs"]["validate"]["steps"]).empty?; exit(ok ? 0 : 1)'
```

### C4 — only `ci.yml` and the task folder changed (so `deploy-docs.yml` and dependencies are untouched)
Expected: no file outside `.github/workflows/ci.yml` and `.harness/` differs from the merge-base.
```sh
test -z "$(git diff --name-only $(git merge-base HEAD origin/main) | grep -v -e '^\.github/workflows/ci\.yml$' -e '^\.harness/')"
```

### C5 — CI passes on this task's own PR (observational)
Expected: `gh pr checks` on the task's PR shows every check passing, including `Validate wiki skeleton`.

## Tier

M — one-file change, but the request requires an observed check (CI on the PR), which rules out S.

## Source

prompt

## Milestones

### M1 — Add the JSON-parse step to the `validate` job
Checks: C1, C2, C3, C4
2026-10-09 · claude-opus-5-5 · build — Added step "Check --json output is valid JSON" (validate.sh to file, Ruby parse + shape check) in .github/workflows/ci.yml.

After the existing `Validate wiki and raw content` step in `.github/workflows/ci.yml`, add one step
(no `shell:`, no `uses:`) whose `run` is two commands:
1. `./hooks/validate.sh --all --json > "$RUNNER_TEMP/validate.json"` on its own line, verbatim.
2. `ruby -rjson` reads that file; it fails with a message unless the parse succeeds and yields a Hash
   with an Integer `files_validated` and an Array `violations` (shape from `hooks/validate.sh:18-19`).
Use `$RUNNER_TEMP`, not `${{ runner.temp }}`, so C1/C2 run the identical text locally.

### M2 — Prove it on the PR
Checks: C5

Push, open the PR via `harness pr`, wait for the final run (earlier runs may show cancelled), and
record `gh pr checks` as C5.

## Decisions

- 2026-10-09 · claude-opus-5-5 · triage — Parser is Ruby's bundled `json`; output goes to a file, not a pipe. Why: hooks already need Ruby; `bash -e` has no pipefail. Check: C1, C2
- 2026-10-09 · claude-opus-5-5 · triage — Step also checks the shape (`files_validated` integer, `violations` list). Why: `null` or `42` is valid JSON but not the documented output. Check: C2

- 2026-10-09 · claude-opus-5-5 · plan — Step uses GitHub's default shell, not `shell: bash`. Why: C1/C2 replay it with `bash -e`; pipefail would diverge. Check: C1, C2
- 2026-10-09 · claude-opus-5-5 · verify — PASS: C1–C4 pass; step fails on empty, garbled, null, array, wrong keys, string count, trailing junk. [Why: mutation-tested locally]
- 2026-10-09 · claude-opus-5-5 · verify — C2 non-vacuous: no-parse and parse-only variants fail it; Hash-only check would slip through. [Why: in-memory step mutations]

## Unknowns

- 2026-10-09 · claude-opus-5-5 · research — None open; parser, shape and shell all confirmed from code. Cites: tests/run-tests.sh:149
- 2026-10-09 · claude-opus-5-5 · verify — Local check used Ruby 2.6/json 2.1; runner Ruby is newer, unverified until C5. [Why: JSON.parse("null") semantics stable since json 2.0]
- 2026-10-09 · claude-opus-5-5 · verify — C1 saw 0 files validated locally; real content path untested by C1. [Why: repo has no wiki/raw sources yet]

## Friction
