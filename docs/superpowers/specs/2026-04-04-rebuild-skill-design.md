# Design: `/rebuild` Skill

**Date:** 2026-04-04
**Status:** Approved
**Scope:** New skill — no changes to existing skill logic

## Problem

Echo Wiki's `compiled/` directory is fully derived from `raw/` sources, but there is no way to reconcile `compiled/` after a raw source is deleted. The compile skill only appends and merges — it never removes articles or rewrites them without a deleted source's content. If a user deletes a raw file, compiled articles retain stale references and content from the removed source.

## Decision Summary

| Decision | Choice | Rationale |
|---|---|---|
| Recompile strategy | Rewrite articles from remaining sources only | Cleanest — no stale content leaks through |
| Command surface | New `/rebuild` command (separate from `/compile`) | Makes destructive nature explicit; zero risk to existing `/compile` behavior |
| Backup mechanism | None — git is the safety net | `compiled/` is derived state; `git checkout` recovers it |
| Rebuild approach | Sequential replay (wipe + compile each source) | Simplest; reuses 100% of existing compile logic |

## `/rebuild` Skill Specification

### Command

```
/rebuild
```

No arguments. Always rebuilds the entire wiki from all current raw sources.

### Skill File

`.skills/rebuild/SKILL.md`

### Workflow

```
/rebuild
  1. Read _meta/wiki.config.yaml + _meta/schemas/frontmatter.yaml
  2. Glob raw/**/*.md → collect all existing source files
  3. If no sources found → abort with message: "No raw sources found. Nothing to rebuild."
  4. Delete all files in compiled/ (articles, _index.md, _backlinks.md)
  5. Create empty _index.md scaffold (# Wiki Index with empty sections)
  6. For each raw source (sorted by ingested date, oldest first):
     └─ Run compile logic (Steps 1–5 from .skills/compile/SKILL.md)
  7. Regenerate _index.md + _backlinks.md (compile Step 6)
  8. Report: "Rebuild complete. X sources processed, Y articles created."
```

### Step 6 Detail: Chronological Ordering

Sources are sorted by the `ingested` frontmatter field (ascending). This means:
- Earlier sources create articles first
- Later sources merge into existing articles
- The result mirrors how the wiki would have been built incrementally

If `ingested` dates are missing or identical, fall back to alphabetical file path ordering.

### Context Loading

Same progressive loading as `/compile`:

| Level | Load | When |
|---|---|---|
| L0 | `compiled/_index.md` | After creating empty scaffold (Step 5) |
| L1 | `compiled/_backlinks.md` | During Step 7 |
| L2 | Specific `compiled/<type>/<article>.md` | During merge checks in Step 6 |
| L3 | Specific `raw/<category>/<source>.md` | Reading each source in Step 6 |

## Files Changed

### Created
- `.skills/rebuild/SKILL.md` — skill definition

### Updated (documentation only)
- `CLAUDE.md` — add `/rebuild` to Skills table
- `AGENTS.md` — add `/rebuild` to skill list
- `GEMINI.md` — add `/rebuild` to skill list
- `README.md` — add `/rebuild` to Core Operations table and Data Flow diagram

### Unchanged
- `.skills/compile/SKILL.md` — no changes
- `.skills/ingest/SKILL.md` — no changes
- `.skills/lint/SKILL.md` — no changes
- `hooks/pre-commit.sh` — no changes
- `_meta/schemas/frontmatter.yaml` — no changes
- `_meta/wiki.config.yaml` — no changes

## `raw/` Rule Clarification

The existing rule:
> `raw/` is append-only. Never modify or delete ingested sources.

Updated to:
> `raw/` is append-only during normal operation. Do not modify or delete sources as part of `/ingest` or `/compile`. To intentionally remove a source from the wiki, delete the raw file manually, then run `/rebuild` to reconcile.

Key constraints preserved:
- `/ingest` never modifies existing raw files
- `/compile` never touches raw files
- `/rebuild` never touches raw files — it only reads what's there
- Only the **user** deletes raw files, as a deliberate manual action

## Error Handling

- **No raw sources exist:** Abort with message, do not wipe `compiled/`.
- **A raw source has invalid/missing frontmatter:** Skip it, log a warning in the rebuild report, continue with remaining sources.
- **Compile logic fails for a source:** Log the error, continue with remaining sources. Report partial rebuild at the end.

## Testing

After rebuild, the user should:
1. Run `/lint` to validate the rebuilt wiki
2. Check `compiled/_index.md` to verify expected articles exist
3. Confirm removed sources' content no longer appears in compiled articles
