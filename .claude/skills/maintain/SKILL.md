---
name: maintain
description: Safely refresh indexes and produce a prioritized maintenance queue without changing factual knowledge
---

# Maintain

Run the routine, safe maintenance loop for Echo Wiki. Refresh generated indexes, collect deterministic and semantic issues, and write a concise queue that tells a human or agent what to improve next. Never edit factual KB or context-pack content.

## Input

- No arguments
- Example: `/maintain`

## Steps

### Step 0: Verify Structure

Before that structure check or any write, run `./hooks/repository-roots.sh || stop`, then `ECHO_WIKI_WRITER_TOKEN="$(./hooks/rebuild-transaction.sh writer-acquire)" || stop`, then `export ECHO_WIKI_WRITER_TOKEN`. If either command reports a redirected root or active lock, stop without modifying files. Keep this token until every write and the activity-log append finish; run `./hooks/rebuild-transaction.sh writer-release`, then `unset ECHO_WIKI_WRITER_TOKEN`, on completion or after handling an error.

Run the structure check in `_meta/prompts/structure-check.md`, then run `./hooks/workspace-paths.sh system`. It creates only real system directories physically contained within `wiki/workspaces/` and rejects symlinks.

### Step 1: Refresh Generated Indexes

Run `./hooks/reindex.sh`. If it fails, report its error output verbatim and stop.

### Step 2: Collect Deterministic Issues

Run `./hooks/validate.sh --all`. Capture every violation, but do not edit the offending factual files. Evidence-locator violations and any other deterministic validation failure belong in the first queue section.

### Step 3: Run Semantic Lint

Read `.claude/skills/lint/SKILL.md` and execute `/lint all`. Read the generated report at `output/reports/lint-<today YYYY-MM-DD>.md`.

### Step 4: Read Knowledge Gaps

Read all Markdown notes under `wiki/workspaces/knowledge-maintenance/gaps/`. Treat every note as open. Notes with more `## Repeated On` entries are higher priority than notes asked only once.

### Step 5: Write the Maintenance Queue

Write `wiki/workspaces/knowledge-maintenance/maintenance-queue.md` with valid light workspace frontmatter:

```yaml
---
title: "Knowledge Maintenance Queue"
created: <preserve existing date or use today YYYY-MM-DD>
author: "knowledge-maintenance"
summary: "Prioritized, non-destructive knowledge maintenance work."
---
```

Use this exact body structure:

```markdown
# Knowledge Maintenance Queue

## Fix First — Broken Evidence

- <affected target> — <validation reason>. Next: <one concrete repair action>.

## Review Next — Contradictions and Stale Content

- <affected target> — <lint finding>. Next: <one concrete review action>.

## Learn Next — Recurring Knowledge Gaps

- [[workspaces/knowledge-maintenance/gaps/<slug>|<question>]] — <number of occurrences and missing evidence>. Next: ingest <suggested primary source>.

## Improve Later — Orphans and Duplicates

- <affected target> — <lint finding>. Next: <one concrete link or merge review action>.
```

Use vault-relative `[[wikilinks]]` only for affected files under `wiki/`. Remove the `wiki/` prefix and `.md` suffix from the link target. Render `raw/` paths and structure-level targets as plain code-formatted paths, never as wikilinks.

Use `_None._` in every empty section. Include all deterministic validation failures in the first section, all contradiction/staleness findings in the second, all gap notes in the third ordered by recurrence, and orphan/duplicate suggestions in the fourth.

### Step 6: Validate, Reindex, and Log

Run `./hooks/validate.sh wiki/workspaces/knowledge-maintenance/maintenance-queue.md`, then `./hooks/reindex.sh`. Fix only queue-file validation errors. Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD] maintain
Validation issues: <count>
Lint issues: <count>
Knowledge gaps: <count>
Queue: wiki/workspaces/knowledge-maintenance/maintenance-queue.md
```

## Important Rules

- Never modify `raw/`, KB articles, context packs, or ordinary actor workspaces.
- Never resolve a contradiction, freshness issue, duplicate, or knowledge gap automatically.
- Apart from the `/lint` report in `output/reports/`, only `_index.md`, `_backlinks.md`, `maintenance-queue.md`, and `_log.md` may change during `/maintain`.
