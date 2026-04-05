---
name: rebuild
description: Wipe compiled/ and recompile the entire wiki from all remaining raw sources
---

# Rebuild

Wipe `compiled/` and replay all raw sources in chronological order. Use this after manually deleting raw source files to reconcile the wiki — removes all traces of deleted sources from compiled output.

## Input

- No arguments. Always rebuilds the entire wiki from all current raw sources.
- Example: `/rebuild`

## When to Use

After manually deleting one or more raw source files from `raw/`. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

## Context Loading

| Level | Load | When |
|---|---|---|
| L0 | `compiled/_index.md` | After creating empty scaffold (Step 5) |
| L1 | `compiled/_backlinks.md` | During Step 7 |
| L2 | Specific `compiled/<type>/<article>.md` | During merge checks in Step 6 |
| L3 | Specific `raw/<category>/<source>.md` | Reading each source in Step 6 |

## Steps

### Step 1: Load Configuration

Read both files:
- `_meta/wiki.config.yaml` — domain context, defaults
- `_meta/schemas/frontmatter.yaml` — required fields and enums

### Step 2: Collect Raw Sources

Glob `raw/**/*.md` to find all existing source files. Exclude any non-markdown files and `.gitkeep` files.

### Step 3: Abort If No Sources

If no raw source files were found in Step 2:
- Print: **"No raw sources found. Nothing to rebuild."**
- **Do NOT delete or modify anything in `compiled/`.**
- Stop here.

### Step 4: Wipe Compiled Directory

Delete all `.md` files recursively inside `compiled/` — this includes all articles, `_index.md`, and `_backlinks.md`.

Preserve the directory structure (empty folders are fine). Do NOT touch `raw/` or any other directory.

### Step 5: Create Empty Index Scaffold

Create a fresh `compiled/_index.md` with empty sections:

```markdown
# Wiki Index

## Concepts

## People

## Tools

## Sources
```

### Step 6: Replay Each Source

Sort the collected raw sources by their `ingested` frontmatter field (ascending — oldest first). If `ingested` dates are missing or identical, fall back to alphabetical file path ordering.

For each raw source, in sorted order:
1. Read the raw source file
2. Execute the compile workflow from `.skills/compile/SKILL.md` — specifically the steps named: **Read and Analyze Raw Source**, **Create Source Summary**, **Extract and Classify Entities**, **Create or Merge Articles**, **Add Wikilinks** (all steps before "Update Index and Backlinks")
3. If a source has invalid or missing frontmatter, skip it and log a warning
4. If compile logic fails for a source, log the error and continue with remaining sources

**Important:** Each source builds on the output of previous sources. Articles created by earlier sources will be merged into by later sources — this mirrors how the wiki would have been built incrementally.

### Step 7: Regenerate Index and Backlinks

After all sources have been processed, run the compile step named **Update Index and Backlinks**:
- Regenerate `compiled/_index.md` with all articles, sorted alphabetically within each section
- Regenerate `compiled/_backlinks.md` with complete cross-reference map

### Step 8: Report Results

Print a summary:

```
Rebuild complete. X sources processed, Y articles created.
```

If any sources were skipped due to errors, include:

```
Rebuild complete. X sources processed, Y articles created. Z sources skipped (see warnings above).
```

## Error Handling

| Scenario | Behavior |
|---|---|
| No raw sources exist | Abort with message. Do NOT wipe `compiled/`. |
| A raw source has invalid/missing frontmatter | Skip it, log a warning, continue with remaining sources. |
| Compile logic fails for a source | Log the error, continue with remaining sources. Report partial rebuild. |

## Important Rules

- **NEVER touch `raw/` files** — rebuild only reads raw sources, never modifies or deletes them.
- **Only the user deletes raw files** — this is always a deliberate manual action before running `/rebuild`.
- **Reuse compile logic exactly** — do not implement alternative article creation or merging logic.
- **Process sources chronologically** — sorting by `ingested` date ensures consistent, reproducible output.
