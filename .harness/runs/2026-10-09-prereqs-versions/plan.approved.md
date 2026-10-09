# Plan — 2026-10-09-prereqs-versions

## Goal
Add repo-derived minimum versions for Git, Bash, Ruby and Node.js to the "Prerequisites" section of
`docs/getting-started.md`, inline where each tool is listed today, changing nothing else.

## Outcome
- Line 8 bullet reads: Git (any recent version), Bash 3.2 or later, Ruby 2.6 or later (standard YAML
  library; no gems required), and filesystem symlink support.
- Line 12 paragraph starts: "Node.js 18 or later is needed only to build …"; rest unchanged.
- Evidence: Bash 3.2 — `hooks/validate.sh:22`, `hooks/reindex.sh:23`, `tests/run-tests.sh:6`.
  Ruby 2.6 — `YAML.safe_load(..., permitted_classes:, aliases:)` keyword form (Psych 3.1 / Ruby 2.6),
  `hooks/validate.sh:80`. Node 18 — `package-lock.json:2393` (vite `^18.0.0 || >=20.0.0`),
  `package-lock.json:2141` (rollup `>=18.0.0`). Git — no version-gating usage found.

## Acceptance checks

### C1 — Git, Bash and Ruby versions on the existing bullet
Expected: the line-8 bullet names all three versions in place.
```sh
grep -qE '^- Git \(any recent version\), Bash 3\.2 or later, Ruby 2\.6 or later \(standard YAML library; no gems required\), and filesystem symlink support$' docs/getting-started.md
```

### C2 — Node.js version on its existing line
Expected: the Node.js paragraph states 18 or later; the rest of the sentence is unchanged.
```sh
grep -qF "Node.js 18 or later is needed only to build this project's documentation site. API keys are not required" docs/getting-started.md
```

### C3 — Only docs/getting-started.md changes
Expected: outside the task folder, the diff against origin/main touches exactly one file.
```sh
test "$(git diff origin/main --name-only -- . ':!.harness')" = "docs/getting-started.md"
```

### C4 — Changes stay inside the Prerequisites section
Expected: every diff hunk starts within lines 5–13 of the original file, and there is at least one hunk.
```sh
git diff origin/main -U0 -- docs/getting-started.md | awk '/^@@/{split($2,a,","); n=substr(a[1],2)+0; if (n<5||n>13) bad=1; c++} END{exit (bad||c==0)}'
```

### C5 — Section is still a bullet list
Expected: lines 7–10 are all still bullets.
```sh
test "$(sed -n '7,10p' docs/getting-started.md | grep -c '^- ')" = 4
```

## Tier
S — one-file, two-line docs edit.

## Source
prompt

## Decisions
- 2026-10-09 12:45 · claude-opus-5-5 · triage — Node.js minimum is 18, not CI's 20. [Why: dependency engines floor is 18; CI pin 20 is one tested version] [Check: C2] [Cites: package-lock.json:2393, .github/workflows/deploy-docs.yml:32]
- 2026-10-09 12:45 · claude-opus-5-5 · triage — Ruby minimum 2.6 from safe_load keyword args. [Why: permitted_classes:/aliases: keywords need Psych 3.1, bundled with Ruby 2.6] [Check: C1] [Cites: hooks/validate.sh:80]
- 2026-10-09 12:45 · claude-opus-5-5 · triage — Node.js stays in its paragraph, not promoted to a bullet. [Why: request says same line where listed today] [Check: C2]

## Unknowns

## Friction
- 2026-10-09 12:52 · claude-opus-5-5 · triage — Local `main` is stale (at #8); C3/C4 now diff against origin/main. [Why: stale main listed 20 unrelated files] [Check: C3]
