# Plan — 2026-10-09-troubleshoot-questions

## Goal

In `docs/troubleshooting.md`, rewrite each failure-section `##` heading (all except "Which rules apply to
a file" and "After fixing") as the question a reader would ask on hitting that failure. Keep every
table, message, fact and section order unchanged; touch no other page; update any link to a renamed anchor.

## Outcome

A reader scanning the page sees eleven question headings, for example "Why does validation say a
required field is missing?", in the same order as before, with identical body content. The docs site
still builds, and no link anywhere points at an old heading anchor.

## Acceptance checks

### C1 — First and last headings kept; the eleven between are questions
Expected: the page has 13 `##` headings; the first is "Which rules apply to a file", the last is "After fixing", and the other 11 each end with `?`.
```sh
h=$(grep '^## ' docs/troubleshooting.md); test "$(printf '%s\n' "$h" | wc -l | tr -d ' ')" = 13 && test "$(printf '%s\n' "$h" | head -1)" = "## Which rules apply to a file" && test "$(printf '%s\n' "$h" | tail -1)" = "## After fixing" && test "$(printf '%s\n' "$h" | sed '1d;$d' | grep -c '?$')" = 11
```

### C2 — The request's example heading is used verbatim
Expected: the "Missing required fields" section is headed exactly as the request's example.
```sh
grep -qx '## Why does validation say a required field is missing?' docs/troubleshooting.md && ! grep -qx '## Missing required fields' docs/troubleshooting.md
```

### C3 — Only heading lines changed on the page
Expected: against the merge base with `origin/main`, the page diff removes 11 lines and adds 11 lines, all of them `## ` headings; nothing else (tables, messages, order) differs.
```sh
d=$(git diff -U0 "$(git merge-base HEAD origin/main)" -- docs/troubleshooting.md | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) '); test "$(printf '%s\n' "$d" | grep -c '^-## ')" = 11 && test "$(printf '%s\n' "$d" | grep -c '^+## ')" = 11 && test -z "$(printf '%s\n' "$d" | grep -vE '^[-+]## ')"
```

### C4 — No other project file changed
Expected: outside `.harness/`, the only path changed since the merge base with `origin/main` is `docs/troubleshooting.md`.
```sh
test "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- . ':(exclude).harness')" = "docs/troubleshooting.md"
```

### C5 — No link points at an old heading anchor
Expected: no tracked file outside `.harness/` contains a link fragment for any of the eleven old headings.
```sh
! git grep -nE '#(fix-frontmatter-shape-first|missing-required-fields|invalid-enum-values|invalid-dates|tags-not-in-config-domains|filenames-that-are-not-kebab-case|broken-wikilinks|source-paths-that-do-not-exist|evidence-locators|structure-errors|a-file-was-not-checked)\b' -- . ':(exclude).harness'
```

### C6 — Docs site builds
Expected: a clean install and `vitepress build docs` succeed, including the dead-link check.
```sh
npm ci --no-audit --no-fund && npm run docs:build
```

## Tier

S — the diff is eleven heading lines in one Markdown page. All checks are runnable.

## Source

prompt

## Decisions

- 2026-10-09 17:30 · claude/opus-5.5 · triage — No link updates needed: nothing in the repo links to any of the eleven old anchors. [Why: grep for `troubleshooting#` and the old slugs found no hits.] [Check: C5] [Cites: docs/.vitepress/config.mts:40]
