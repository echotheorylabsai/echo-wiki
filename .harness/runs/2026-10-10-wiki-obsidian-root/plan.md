## Goal

In `docs/obsidian.md`, under Setup, add a short note for people who open the repo root as the vault by mistake.

## Outcome

The Setup section tells readers that opening the repo root makes Obsidian create a `.obsidian/` folder there, that the folder is git-ignored so nothing breaks, and that they should close that vault and open `wiki/` instead. The three existing steps and everything else in the file are unchanged.

## Acceptance checks

### C1 — The note sits inside Setup and names the folder, the git-ignore and `wiki/`
Expected: exit 0; the note is between `## Setup` and `## Pre-configured Settings`.
```sh
awk '/^## Setup/{s=1;next} /^## Pre-configured Settings/{s=0} s' docs/obsidian.md | grep -q 'repo root' && awk '/^## Setup/{s=1;next} /^## Pre-configured Settings/{s=0} s' docs/obsidian.md | grep -q '`\.obsidian/`' && awk '/^## Setup/{s=1;next} /^## Pre-configured Settings/{s=0} s' docs/obsidian.md | grep -qi 'git-ignored' && awk '/^## Setup/{s=1;next} /^## Pre-configured Settings/{s=0} s' docs/obsidian.md | grep -qi 'open `wiki/`'
```

### C2 — Existing lines are untouched (additions only)
Expected: no line of `docs/obsidian.md` is removed or changed compared with the branch point.
```sh
! git diff "$(git merge-base HEAD origin/main)" -- docs/obsidian.md | grep -q '^-[^-]'
```

### C3 — Only `docs/obsidian.md` changes outside the task folder
Expected: the diff lists exactly `docs/obsidian.md`.
```sh
test "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- . ':!.harness' | tr '\n' ' ')" = "docs/obsidian.md "
```

## Tier

S — one paragraph added to one docs file.

## Source

prompt

## Decisions

2026-10-10 · claude-sonnet-5-5 · triage — Place the note right after the numbered steps, before "The vault comes pre-configured". [Why: it is under Setup and leaves steps 1-3 untouched] [Check: C1, C2]
