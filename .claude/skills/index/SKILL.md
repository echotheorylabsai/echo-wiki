---
name: index
description: Scan wiki/ and regenerate _index.md and _backlinks.md via the deterministic reindex script
---

# Index

Regenerate the master index and backlinks files by running the deterministic reindex script. Non-destructive — only `_index.md` and `_backlinks.md` are rewritten.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- No arguments required
- Example: `/index`

## When to Use

- After manually creating or modifying workspace content (notes, drafts, etc.)
- After any operation where `_index.md` may be out of sync with actual files
- As a standalone reindex without recompiling

## Steps

### Step 1: Run the Reindex Script

Run `./hooks/reindex.sh`. It scans all of `wiki/` (KB articles + workspace content), reads `entity_types` from `_meta/wiki.config.yaml`, and regenerates `wiki/_index.md` and `wiki/_backlinks.md` deterministically — including cross-zone backlinks and explicit `_No inbound links._` orphan markers.

**Never hand-write `_index.md` or `_backlinks.md`.** If the script fails, report its error output verbatim and stop.

### Step 2: Report

Relay the script's summary line, e.g.:

```
Index updated. X KB articles, Y workspace files indexed. Z orphan(s).
```

Also relay any stderr warnings (files skipped for missing titles, directories not in `entity_types` config) — these usually indicate content that needs fixing.

### Step 3: Append to Activity Log

Append an entry to `wiki/_log.md`. If the file doesn't exist, create it with a `# Activity Log` header first.

```markdown
## [YYYY-MM-DD] index
KB articles indexed: <X>
Workspace files indexed: <Y>
```

## Important Rules

- This skill is non-destructive — only `_index.md` and `_backlinks.md` are rewritten, and only by the script
- Never modify any article content or frontmatter
