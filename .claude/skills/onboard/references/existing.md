---
title: Onboarding a repository with existing artifacts
---

# Existing artifacts

1. Read repository instructions and inventory paths before sampling content. Exclude secrets, dependency/build directories, and unrelated data. Inspect enough relevant documents to propose domains and a first import; do not read or ingest everything.
2. Present a small inventory: **path/link, area, source status/authority, proposed action**. Actions are import a snapshot, keep as a link, or defer pending clarification/export. Originals remain in place. HTML/media/cloud links need a trustworthy text export or available extraction tool; there is no general converter or sync service.
3. Check path collisions. Existing `wiki/`, `raw/`, or `_meta/` are not automatically Echo Wiki. If they are unrelated, stop before installation and recommend a separate destination repo that imports selected snapshots. A deliberate migration is separate user-authorized work. Do not rename directories or change `vault.dir` as a workaround.
4. Preview with `ruby .claude/skills/onboard/scripts/bootstrap.rb --check /path/to/existing-repo` from the upstream checkout. Inspect preserved instruction/ignore files, existing hook managers and `core.hooksPath`; propose integration edits without replacing project rules. Resolve conflicts before `--apply`.
5. Apply the same script with `--apply`, then use the shared finish reference linked from SKILL.md. Import only the selected initial source. Record its original path/URL and version/date in the new raw snapshot body so later revisions can be distinguished. Existing paths, Git history/remotes, and artifacts must remain intact.
