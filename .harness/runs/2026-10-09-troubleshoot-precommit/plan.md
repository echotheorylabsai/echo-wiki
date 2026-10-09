# Plan — 2026-10-09-troubleshoot-precommit

## Goal

Add a `docs/troubleshooting.md` entry for commits blocked by the pre-commit hook, derived only from
`hooks/pre-commit.sh` and its install instructions, and put the page's `##` sections in alphabetical
order, keeping "Which rules apply to a file" first and "After fixing" last.

## Outcome

A reader whose commit is blocked learns what the hook checks (the whole staged snapshot, via
`validate.sh --all`), what its failure output looks like, and how to fix, stage and commit again,
without being told to skip the hook. Every existing table, message and fact is unchanged; no other
page changes.

## Acceptance checks

### C1 — New section exists and covers the hook's real behaviour
Expected: a `## Commit blocked by the pre-commit hook` section naming the script, both failure messages, the success line and `git add`.
```sh
awk '/^## Commit blocked by the pre-commit hook$/{f=1;print;next} /^## /{f=0} f' docs/troubleshooting.md > /tmp/c1-section.md && grep -q 'hooks/pre-commit.sh' /tmp/c1-section.md && grep -q 'Pre-commit validation failed:' /tmp/c1-section.md && grep -q 'could not materialize the staged snapshot' /tmp/c1-section.md && grep -q 'Pre-commit validation passed' /tmp/c1-section.md && grep -q 'git add' /tmp/c1-section.md && grep -q 'validate.sh --all' /tmp/c1-section.md
```

### C2 — Sections are in the requested order
Expected: first `##` is "Which rules apply to a file", last is "After fixing", the rest are sorted alphabetically (case-insensitive).
```sh
grep '^## ' docs/troubleshooting.md > /tmp/c2-all.txt && test "$(head -n 1 /tmp/c2-all.txt)" = '## Which rules apply to a file' && test "$(tail -n 1 /tmp/c2-all.txt)" = '## After fixing' && sed '1d;$d' /tmp/c2-all.txt > /tmp/c2-mid.txt && LC_ALL=C sort -f /tmp/c2-mid.txt | diff /tmp/c2-mid.txt - && test "$(wc -l < /tmp/c2-all.txt | tr -d ' ')" = 14
```

### C3 — Every existing line is kept
Expected: no line of the base-branch page is missing from the new page.
```sh
git show "$(git merge-base HEAD origin/main)":docs/troubleshooting.md | sort > /tmp/c3-old.txt && sort docs/troubleshooting.md > /tmp/c3-new.txt && test -z "$(comm -23 /tmp/c3-old.txt /tmp/c3-new.txt)"
```

### C4 — No other page changed
Expected: outside the task folder, only `docs/troubleshooting.md` differs from the merge base.
```sh
test -z "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- . ':!.harness' ':!docs/troubleshooting.md')"
```

### C5 — The new section's prose never recommends skipping the hook
Expected: `no-verify` appears only inside the verbatim output sample (fenced code), never in prose.
```sh
awk '/^## Commit blocked by the pre-commit hook$/{f=1;next} /^## /{f=0} f' docs/troubleshooting.md | awk '/^```/{c=!c;next} !c' | grep -c 'no-verify' | grep -qx 0
```

### C6 — Docs site still builds
Expected: VitePress build exits 0.
```sh
npm ci && npm run docs:build
```

## Tier

S — one file: add one section and reorder the existing sections.

## Source

prompt

## Decisions

- 2026-10-09 · claude-opus-5-5 · triage — Heading "Commit blocked by the pre-commit hook"; sorts after "Broken wikilinks". [Why: request leaves the name open; avoid a leading "The".] [Check: C1, C2]
- 2026-10-09 · claude-opus-5-5 · triage — Output sample keeps the hook's literal `--no-verify` line; prose never offers it. [Why: show real output yet not recommend skipping.] [Check: C5] [Cites: hooks/pre-commit.sh:26]
- 2026-10-09 · claude-opus-5-5 · triage — Alphabetical means case-insensitive by heading text (`LC_ALL=C sort -f`). [Why: request does not define collation.] [Check: C2]
- 2026-10-09 · claude-opus-5-5 · build — C2 heading count corrected 13→14: base page has 13 `##` headings, plus the new one. [Why: triage miscounted.] [Check: C2]

## Friction

- 2026-10-09 · claude-opus-5-5 · build — Running the hook in a throwaway clone needed approval; sample derived from reading the script. [Cites: hooks/pre-commit.sh:21-27]
- 2026-10-09 · claude-opus-5-5 · build — Later confirmed: a blocked commit in this worktree printed the sample's exact format. Test file removed afterwards.
- 2026-10-09 · claude-opus-5-5 · build — Could not delete /tmp/precommit-spike (outside workspace); left for manual cleanup.
