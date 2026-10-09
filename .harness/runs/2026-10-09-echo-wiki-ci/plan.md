# Plan — 2026-10-09-echo-wiki-ci

## Goal
Add a GitHub Actions CI workflow so every pull request and every push to `main` runs echo-wiki's own checks.

## Outcome
- New `.github/workflows/ci.yml` runs on `pull_request` and on `push` to `main`; `deploy-docs.yml` is untouched.
- Jobs: hook test suite (`bash tests/run-tests.sh`) on `ubuntu-latest` and `macos-latest`, the macOS run under Bash 3.2;
  `./hooks/validate.sh --all` on the repository's shipped wiki skeleton; `npm ci && npm run docs:build`.
- Actions pinned to a major version, `permissions: contents: read`, superseded runs on the same branch cancelled.
- `docs/validation.md` (the page that already describes the tests) gains one short paragraph about CI.
- The workflow runs on this task's own PR and every job passes.

## Acceptance checks

### C1 — ci.yml triggers, permissions, concurrency and action pins
Expected: triggers are `pull_request` plus `push` to `main`; permissions are exactly `contents: read`; superseded runs per branch are cancelled; every `uses:` is pinned to `@v<major>`.
```sh
ruby -ryaml -e 'w = YAML.load_file(".github/workflows/ci.yml"); on = w["on"] || w[true]; c = w["concurrency"] || {}; uses = w["jobs"].values.flat_map { |j| (j["steps"] || []).map { |s| s["uses"] }.compact }; ok = on.key?("pull_request") && on.dig("push", "branches") == ["main"] && w["permissions"] == {"contents" => "read"} && c["cancel-in-progress"] == true && c["group"].to_s =~ /github\.(head_)?ref/ && !uses.empty? && uses.all? { |u| u =~ /@v\d+\z/ }; abort("ci.yml shape check failed") unless ok'
```

### C2 — ci.yml defines the three required jobs
Expected: one job runs `bash tests/run-tests.sh` over a matrix containing `ubuntu-latest` and `macos-latest`; one runs `./hooks/validate.sh --all`; one runs `npm ci` and `npm run docs:build`.
```sh
ruby -ryaml -e 'jobs = YAML.load_file(".github/workflows/ci.yml")["jobs"].values; runs = ->(j) { (j["steps"] || []).map { |s| s["run"].to_s }.join("\n") }; t = jobs.find { |j| runs.(j).include?("tests/run-tests.sh") }; os = t && Array(t.dig("strategy", "matrix", "os")); ok = t && os.include?("ubuntu-latest") && os.include?("macos-latest") && jobs.any? { |j| runs.(j).include?("./hooks/validate.sh --all") } && jobs.any? { |j| runs.(j).include?("npm ci") && runs.(j).include?("npm run docs:build") }; abort("ci.yml jobs check failed") unless ok'
```

### C3 — deploy-docs.yml is unchanged
Expected: no diff against `origin/main`.
```sh
git diff --quiet origin/main -- .github/workflows/deploy-docs.yml
```

### C4 — hook test suite passes locally
Expected: exit 0.
```sh
bash tests/run-tests.sh
```

### C5 — repository wiki skeleton validates
Expected: exit 0 (`OK: 0 files validated` today; the structure guard runs).
```sh
./hooks/validate.sh --all
```

### C6 — docs site builds
Expected: exit 0.
```sh
npm ci && npm run docs:build
```

### C7 — contributor docs describe the CI
Expected: `docs/validation.md` names the workflow file.
```sh
grep -q '\.github/workflows/ci\.yml' docs/validation.md
```

### C8 — CI runs on this task's PR and every job passes (observational)
Expected: `gh pr checks` lists every `ci.yml` job (tests on ubuntu-latest and macos-latest, validate, docs build) as pass, and the macOS test log prints `GNU bash, version 3.2`.

## Tier
M — two files of new config and docs in familiar code, plus one observational check (C8), which makes it M.

## Source
prompt

## Decisions
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Keep the `validate.sh --all` job though it validates 0 files today. [Why: its structure guard and config parsing protect the shipped skeleton every instance copies; cheap.] [Check: C5] [Cites: docs/validation.md:53]
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Run macOS tests with a PATH shim so `env bash` resolves to `/bin/bash` 3.2. [Why: hooks use `#!/usr/bin/env bash`; runners may put Homebrew Bash 5 first.] [Check: C8] [Cites: hooks/validate.sh:1]
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Document CI in `docs/validation.md` `## Tests`. [Why: that section already lists `run-tests.sh` and is where checks are described.] [Check: C7] [Cites: docs/validation.md:98]
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Leave `ruby tests/onboarding-test.rb` out of CI. [Why: request lists exactly three jobs; adding suites widens scope.] [Cites: docs/validation.md:104]

## Unknowns
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Whether Ruby is on PATH for both runners; the first PR run answers it. [Check: C8]
- 2026-10-09 13:05 · claude-opus-5-5 · triage — How to record C8: `harness pr` refuses unless every check passes, but C8 needs the PR open. Ask user before PR. [Check: C8] [Cites: lean-harness/harness/commands/pr.py:48]

## Friction
- 2026-10-09 13:05 · claude-opus-5-5 · triage — Observational check that needs the PR deadlocks with `harness pr`'s all-checks-pass gate. [Cites: lean-harness/harness/gate.py:20]
