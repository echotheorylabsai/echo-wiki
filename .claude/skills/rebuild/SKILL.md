---
name: rebuild
description: Stage and validate a complete KB replacement from all remaining raw sources
---

# Rebuild

Build a complete replacement for the `wiki/` KB type directories and replay all raw sources in chronological order. Use this after manually deleting raw source files to reconcile the wiki — removes all traces of deleted sources from compiled output without risking the live KB if the replacement is invalid.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

If `.rebuild-state` or `.rebuild-lock` exists when `/rebuild` starts, stop: it may belong to a live rebuild or ordinary writer. Do not run recovery automatically and never delete either path by hand. Only after an operator verifies the transaction is abandoned may they run `./hooks/rebuild-transaction.sh recover --force`, which restores the previous complete `wiki/` directory after an interrupted commit or clears an abandoned prepare.

## Input

- No arguments. Always rebuilds the entire wiki from all current raw sources.
- Example: `/rebuild`

## When to Use

After manually deleting one or more raw source files from `raw/`. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

## Context Loading

| Level | Load | When |
|---|---|---|
| L0 | `wiki/_index.md` | After running reindex.sh (Step 5) |
| L1 | `wiki/_backlinks.md` | During Step 7 |
| L2 | Specific `wiki/<type>/<article>.md` | During merge checks in Step 6 |
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
- **Do NOT delete or modify anything in `wiki/`.**
- Stop here.

### Step 3b: Preflight Every Raw Source

Validate every collected raw source before deleting any KB file. Run `./hooks/validate.sh` with all collected raw paths in one invocation so frontmatter, source types, filenames, and citable headings are checked consistently.

If any raw source fails validation, stop without modifying `wiki/`. Report every violation and migrate or repair the raw inputs before retrying `/rebuild`.

### Step 4: Create an Isolated Staging Root

Build the complete replacement in a staging root before deleting any live KB file. Acquire an exclusive rebuild lock before snapshotting by running:

```bash
STAGE="$(./hooks/rebuild-transaction.sh prepare)" || stop
ECHO_WIKI_REBUILD_TOKEN="$(sed -n 's/^rebuild://p' .rebuild-lock/owner)" || stop
export ECHO_WIKI_REBUILD_TOKEN
```

The command atomically acquires `.rebuild-lock`, records a checksum manifest of `_meta/`, `raw/`, and the complete live `wiki/`, copies them into `.rebuild-state/stage/`, then empties only the staged configured KB directories and generated indexes. Treat `STAGE` as `<staging-root>`. Keep `ECHO_WIKI_REBUILD_TOKEN` private and exported through commit or abort; no replay step may write to the live repository. On any failure before commit, run `./hooks/rebuild-transaction.sh abort`, then unset the token.

### Step 5: Create Empty Index Scaffold

Run `./hooks/reindex.sh` against staging. With the staged KB type directories empty, it produces the scaffold and backlinks for the preserved workspace content. Never hand-write the scaffold; if the script fails, remove staging, leave the live wiki unchanged, and report its error output verbatim.

### Step 6: Replay Each Source

Sort the collected raw sources by their `ingested` frontmatter field (ascending — oldest first). If `ingested` dates are missing or identical, fall back to alphabetical file path ordering.

For each raw source, in sorted order:
1. Read the raw source file
2. Execute the compile workflow from `.claude/skills/compile/SKILL.md` — specifically the steps named: **Read and Analyze Raw Source**, **Create Source Summary**, **Extract and Classify Entities**, **Create or Merge Articles**, **Add Wikilinks** (all steps before "Update Index and Backlinks")
3. The preflight guarantees valid raw structure; do not skip a source for a known validation error during replay
4. Any source replay failure aborts the staged rebuild: report the source and error, remove staging, and leave the live wiki unchanged

**Important:** Each source builds on the output of previous sources. Articles created by earlier sources will be merged into by later sources — this mirrors how the wiki would have been built incrementally.

### Step 7: Regenerate Index and Backlinks

After all sources have been processed, run `./hooks/reindex.sh` against staging. It scans all staged `wiki/` content, including the preserved workspace copy. If the script fails, remove staging, leave the live wiki unchanged, and report its error output verbatim.

### Step 7b: Validate the Rebuilt Wiki

Validate the staging root with `./hooks/validate.sh --all` before replacing live files. This validation intentionally includes preserved workspaces, so it detects context evidence that cites a deleted raw source and workspace links to articles that replay did not recreate.

If staging or validation fails, remove the staging root and leave the live wiki unchanged. Report each affected preserved workspace file and its missing source or article. Do not automatically delete derived notes: regenerate an obsolete context pack with `/context`, regenerate `maintenance-queue.md` with `/maintain`, update a gap through `/query`, or ask the user to explicitly remove an artifact that is no longer useful before retrying.

### Step 7c: Commit the Validated Replacement

Only after staging validation prints `OK`, run:

```bash
./hooks/rebuild-transaction.sh commit
unset ECHO_WIKI_REBUILD_TOKEN
```

The commit helper performs these ordered checks and writes:

1. Revalidates staging and verifies that its workspace, `.obsidian`, and existing log content match the initial preserved-content manifest.
2. Recompute and compare the snapshot manifest immediately before commit. If live `_meta/`, `raw/`, or `wiki/` changed during replay, abort without modifying live files.
3. Write and fsync a recovery marker before the first directory rename.
4. Move the old complete `wiki/` to the transaction backup, then replace the entire `wiki/` directory as one unit with the validated staged directory. This prevents a mixed set of old and new KB directories.
5. Validate the installed wiki, restoring the complete backup on failure. Retain the backup and recovery marker until this validation succeeds, then clear the transaction and release the lock.

An interruption can briefly leave `wiki/` absent, but cannot produce a mixed wiki. The next `/rebuild` invocation must run recovery as described in Prerequisites; recovery always prefers and restores the previous complete backup.

### Step 8: Report Results

Print a summary:

```
Rebuild complete. X sources processed, Y articles created.
```

After printing the summary, append an entry to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD] rebuild
Sources processed: <X>
Articles created: <Y>
```

Because `commit` releases the rebuild lock after the validated directory replacement, acquire and release a normal writer lock around this final append:

```bash
ECHO_WIKI_WRITER_TOKEN="$(./hooks/rebuild-transaction.sh writer-acquire)" || stop
export ECHO_WIKI_WRITER_TOKEN
# append the log entry
./hooks/rebuild-transaction.sh writer-release
unset ECHO_WIKI_WRITER_TOKEN
```

## Error Handling

| Scenario | Behavior |
|---|---|
| No raw sources exist | Abort with message. Do NOT wipe `wiki/`. |
| Any raw source fails preflight validation | Abort before modifying `wiki/`; report every violation. |
| Compile logic fails for a source | Abort and discard staging; never commit an incomplete replay. |
| Preserved workspace dependency is obsolete | Abort before modifying live files; report the artifact and required explicit remediation. |
| Snapshot changed during replay | Abort before modifying live files; retry from a fresh snapshot. |
| Replacement fails or is interrupted | Run the transaction helper's recovery command; restore the complete live backup. |

## Important Rules

- **NEVER touch `raw/` files** — rebuild only reads raw sources, never modifies or deletes them.
- **Only the user deletes raw files** — this is always a deliberate manual action before running `/rebuild`.
- **Use the transaction helper for prepare, commit, abort, and recovery** — never move live rebuild paths manually.
- **Reuse compile logic exactly** — do not implement alternative article creation or merging logic.
- **Process sources chronologically** — sorting by `ingested` date ensures consistent, reproducible output.
