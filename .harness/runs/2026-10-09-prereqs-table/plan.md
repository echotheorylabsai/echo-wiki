## Goal

Rewrite the "Prerequisites" section of `docs/getting-started.md` as a three-column Markdown table (Tool, Needed for, Required?) without changing any facts or any other section.

## Outcome

- The section holds one table with header `| Tool | Needed for | Required? |` and one row each for: coding agent, Git, Bash, Ruby, symlink support, Obsidian, source extraction tools, Node.js.
- The old paragraph (Node.js only for the docs site; no API keys) is folded into the rows plus at most one short sentence after the table.
- Every fact stays as it is on main, including #15's minimum versions; no other version numbers; the rest of the file and every other file are untouched.

## Acceptance checks

### C1 — Prerequisites section has the three-column table header
Expected: the exact header row is present inside the section.
```sh
sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' docs/getting-started.md | grep -qxF '| Tool | Needed for | Required? |'
```

### C2 — Table has exactly eight data rows
Expected: 10 table lines (header + separator + 8 rows).
```sh
test "$(sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' docs/getting-started.md | grep -c '^|')" -eq 10
```

### C3 — One row per original item, named in the Tool column
Expected: each item appears in the first column of some row.
```sh
for t in 'coding agent' 'Git' 'Bash' 'Ruby' 'symlink' 'Obsidian' 'extraction' 'Node.js'; do sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' docs/getting-started.md | grep '^|' | cut -d'|' -f2 | grep -qiF "$t" || { echo "missing: $t"; exit 1; }; done
```

### C4 — Original facts preserved
Expected: every key phrase from today's bullets and paragraph is still in the section.
```sh
for p in 'local file and command access' 'standard YAML library' 'no gems required' 'wiki/' 'local Markdown' 'URL/PDF/media' "agent's available tools" 'documentation site' 'API keys'; do sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' docs/getting-started.md | grep -qF "$p" || { echo "missing: $p"; exit 1; }; done
```

### C5 — No version numbers beyond those on main
Expected: the section's numbers equal the merge base's Prerequisites numbers (Bash 3.2, Ruby 2.6, Node.js 18), no more, no fewer.
```sh
git show "$(git merge-base HEAD origin/main)":docs/getting-started.md | sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' | grep -o '[0-9][0-9.]*' | sort -u > "${TMPDIR:-/tmp}/gs-main-nums.txt" && sed -n '/^## Prerequisites$/,/^## Get the Onboarding Skill$/p' docs/getting-started.md | grep -o '[0-9][0-9.]*' | sort -u | cmp -s - "${TMPDIR:-/tmp}/gs-main-nums.txt"
```

### C6 — Rest of getting-started.md unchanged
Expected: the file minus the Prerequisites section matches the merge base with `origin/main` byte for byte.
```sh
git show "$(git merge-base HEAD origin/main)":docs/getting-started.md | sed '/^## Prerequisites$/,/^## Get the Onboarding Skill$/d' > "${TMPDIR:-/tmp}/gs-main-rest.md" && sed '/^## Prerequisites$/,/^## Get the Onboarding Skill$/d' docs/getting-started.md | cmp -s - "${TMPDIR:-/tmp}/gs-main-rest.md"
```

### C7 — No other project file changed
Expected: no diff against the merge base with `origin/main` outside the doc and the task folder.
```sh
git diff --quiet "$(git merge-base HEAD origin/main)" -- . ':(exclude)docs/getting-started.md' ':(exclude).harness'
```

## Tier

S — one section of one docs page rewritten as a table.

## Source

prompt

## Decisions

- 2026-10-09 12:41 · claude-opus-5-5 · triage — Pinned C6/C7 base to 33ed7fc, not `main`. Why: local `main` is stale; 33ed7fc equals HEAD and origin/main. Check: C6, C7
- 2026-10-09 12:42 · claude-opus-5-5 · build — C6/C7 base now `git merge-base HEAD origin/main`. Why: rebase pulled #14 (vitepress config), so fixed 33ed7fc flagged upstream changes. Check: C6, C7
- 2026-10-09 13:20 · claude-opus-5-5 · build — C5 now allows exactly main's version numbers; versions sit in Tool cells. Why: #15 merged them; user said keep them. Check: C5, goal

## Unknowns

- 2026-10-09 12:41 · claude-opus-5-5 · triage — Page never says what Git/Bash/Ruby/symlinks are for; default "Needed for": "Setting up and running a wiki". Cites: docs/getting-started.md:8
- 2026-10-09 12:41 · claude-opus-5-5 · triage — "Required?" keeps original nuance (Yes / Optional / Only when needed / Only for the docs site), not Yes/No. Cites: docs/getting-started.md:9
