---
name: onboard
description: Use when setting up an Echo Wiki knowledge base in a fresh Git repository or a repository with existing documents and artifacts, or resuming incomplete onboarding, or enabling Codex discovery for an existing Echo Wiki instance.
---

# Onboard

Create a usable Echo Wiki instance while preserving the customer's repository and source artifacts. This skill initializes the runtime; it is not an upgrade or bulk migration tool. Requires local file/command access, Git, Bash, Ruby and filesystem symlink support; extraction tools depend on the source.

## Route first

Resolve an explicit destination repository root and a clean upstream Echo Wiki checkout (the directory containing this skill). If no destination is supplied, ask; never assume the upstream checkout is the customer's instance. Clone/initialize a destination only when requested. A downloaded SKILL.md alone is insufficient: retain its sibling references, scripts, and upstream runtime files.

Inspect the destination's instructions, Git status, hooks configuration, and top-level files before writes. Classify by actual content, not whether it has commits. Read only the matching reference:

- **Fresh:** no company artifacts; ordinary README/license/instruction files may exist. Read [fresh.md](references/fresh.md).
- **Existing artifacts:** documents, code, media, or an existing wiki are present. Read [existing.md](references/existing.md).
- **Codex discovery only:** when the request is only to enable Codex on an existing instance, follow the link-only procedure below and stop; do not resume full onboarding.
- **Already Echo Wiki:** inspect the configuration and runtime first. Preserve existing knowledge and settings; skip installation and use [finish.md](references/finish.md) to resume only unfinished steps. Do not reset defaults or import the same source again.

## Link Codex only

From the complete current upstream checkout, run `ruby .claude/skills/onboard/scripts/link-codex-skills.rb --check <destination>`, review the planned links, then run `--apply` within the user's authorization. The helper preserves the installed `.claude/skills/` definitions and unrelated Codex skills, rejects conflicts before writing, and owns its writer lock. Do not take another writer lock around it.

Verify all nine relative links resolve to their canonical skill folders, check Git visibility, and inspect the diff to confirm only the requested links were added. Confirm discovery in Codex's skill picker/list from the destination repository; restart the session if needed. If Codex is unavailable, report “links verified; native Codex discovery pending.” Do not configure, edit instructions, reindex, ingest or compile for this route. Commit/push only when requested. Stop after reporting these checks; skip the shared finish workflow.

## Shared boundaries

- Use the standard repository-root `raw/`, `wiki/`, `_meta/`, and `hooks/` layout. `vault.dir` does not relocate the runtime. Do not invent a nested installation or automatically repurpose colliding folders.
- Existing artifacts are source material, not permission to change the repository. Keep originals in place. Treat draft/approved/implemented status and source authority explicitly; ask when a consequential distinction cannot be established.
- Show the proposed paths, configuration, integration edits, and first source before applying. Existing user authorization covers that scope; ask only for missing decisions or additional changes.
- Use `scripts/bootstrap.rb --check <target>` before `--apply`. It creates an allowlisted runtime scaffold and relative `.agents/skills/` links to the canonical `.claude/skills/` definitions, preserves existing instruction/ignore files and unrelated Codex skills, and never installs hooks, imports artifacts, or commits. Run it with Ruby from the upstream checkout, not from an installed customer instance.
- Use one onboarding writer. Existing writer/rebuild locks are blockers; never remove them to get past a check. An interrupted partial installation needs inspection, not blind deletion or retry.

## When blocked

Stop the affected writes. Report the exact conflicting path or missing capability, why it prevents completion, what has already changed, and a recommended action with alternatives. Resume after the user resolves the dependency. Examples: choose a separate repo for an occupied `wiki/`; identify the approved roadmap; export an inaccessible cloud document as Markdown. Never claim onboarding succeeded while setup or evidence checks remain incomplete.

## Finish

After the selected mode's setup, read [finish.md](references/finish.md). Report installation, Codex discovery, instruction/hook integration, and first-source verification separately. Leave a small next-import list and the daily commands; no automatic commit, push, publication, or whole-repository ingestion.
