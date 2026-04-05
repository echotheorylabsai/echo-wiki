---
name: index
description: Scan wiki/ and regenerate _index.md and _backlinks.md to include all content
---

# Index

Scan all content in `wiki/` (KB articles + workspace content) and regenerate the master index and backlinks files. Non-destructive — only reads content and rewrites `_index.md` and `_backlinks.md`.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- No arguments required
- Example: `/index`

## When to Use

- After manually creating or modifying workspace content (notes, drafts, etc.)
- After any operation where `_index.md` may be out of sync with actual files
- As a standalone reindex without recompiling

## Context Loading

1. Read `_meta/wiki.config.yaml` — domain context
2. Read `_meta/schemas/frontmatter.yaml` — field definitions

## Steps

### Step 1: Scan Wiki Directory

Find all `.md` files recursively in `wiki/`. Exclude:
- `wiki/_index.md` (this is what we're regenerating)
- `wiki/_backlinks.md` (this is what we're regenerating)
- Any files in `wiki/.obsidian/`

### Step 2: Read Frontmatter

For each file found, read its YAML frontmatter. Extract:
- `title` (required — skip file with warning if missing)
- `type` (for KB articles: concept, person, tool, source-summary)
- `summary` (optional — use title if absent)
- All `[[wikilinks]]` in the file body

### Step 3: Regenerate _index.md

Follow the format defined in `_meta/prompts/index-update.md`:
- Group KB articles by type section (Concepts, People, Tools, Sources)
- Group workspace files under Workspaces section, sub-grouped by workspace name
- Sort entries alphabetically within each section
- One line per article: `- [[path|Title]] — summary`

### Step 4: Regenerate _backlinks.md

Follow the format defined in `_meta/prompts/index-update.md`:
- For each file in `wiki/`, find all other files that contain a `[[wikilink]]` pointing to it
- Include cross-zone references (workspace → KB, KB → workspace)
- Sort sections alphabetically

### Step 5: Report

Print summary:

```
Index updated. X KB articles, Y workspace files indexed.
```

## Important Rules

- This skill is non-destructive — it only writes `_index.md` and `_backlinks.md`
- Never modify any article content or frontmatter
- Include ALL files in `wiki/` regardless of zone (KB or workspace)
- For workspace files without `summary`, use the title as the index entry
