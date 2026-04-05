# `/rebuild` Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/rebuild` skill that wipes `compiled/` and replays all remaining raw sources, enabling clean reconciliation after manual source deletion.

**Architecture:** New skill file (`.skills/rebuild/SKILL.md`) plus documentation updates to 4 files. Zero changes to existing skill logic — rebuild reuses `/compile` steps verbatim. The skill is a markdown instruction set executed by LLMs, not application code.

**Tech Stack:** Markdown, YAML frontmatter, Agent Skills standard

**Spec:** `docs/superpowers/specs/2026-04-04-rebuild-skill-design.md`

---

### Task 1: Create the rebuild skill definition

**Files:**
- Create: `.skills/rebuild/SKILL.md`

This is the core deliverable. The skill file defines the full `/rebuild` workflow that LLM agents follow.

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p .skills/rebuild
```

- [ ] **Step 2: Write `.skills/rebuild/SKILL.md`**

Create the file with the following complete content:

````markdown
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

Delete all files inside `compiled/`:
- All articles in `compiled/concepts/`, `compiled/people/`, `compiled/tools/`, `compiled/sources/`
- `compiled/_index.md`
- `compiled/_backlinks.md`

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
2. Execute the compile workflow from `.skills/compile/SKILL.md` — specifically Steps 1 through 5 (Read and Analyze, Create Source Summary, Extract and Classify Entities, Create or Merge Articles, Add Wikilinks)
3. If a source has invalid or missing frontmatter, skip it and log a warning
4. If compile logic fails for a source, log the error and continue with remaining sources

**Important:** Each source builds on the output of previous sources. Articles created by earlier sources will be merged into by later sources — this mirrors how the wiki would have been built incrementally.

### Step 7: Regenerate Index and Backlinks

After all sources have been processed, run compile Step 6 (Update Index and Backlinks):
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
````

- [ ] **Step 3: Verify file exists and content is correct**

```bash
cat .skills/rebuild/SKILL.md | head -5
```

Expected output:
```
---
name: rebuild
description: Wipe compiled/ and recompile the entire wiki from all remaining raw sources
---
```

- [ ] **Step 4: Commit**

```bash
git add .skills/rebuild/SKILL.md
git commit -m "feat: add /rebuild skill definition

New skill that wipes compiled/ and replays all raw sources chronologically.
Enables clean reconciliation after manual source deletion.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Update CLAUDE.md — add rebuild skill and clarify raw/ rule

**Files:**
- Modify: `CLAUDE.md`

Two changes: add `/rebuild` to the Skills table, and update the `raw/` rule to clarify that users can manually delete sources before rebuilding.

- [ ] **Step 1: Add `/rebuild` to the Skills table**

In `CLAUDE.md`, find the Skills section and add the rebuild entry after `/lint`:

Before:
```markdown
## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `compiled/`
- `/lint [scope]` — Semantic validation, report to `output/reports/`
```

After:
```markdown
## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `compiled/`
- `/rebuild` — Wipe `compiled/` and recompile from all remaining raw sources
- `/lint [scope]` — Semantic validation, report to `output/reports/`
```

- [ ] **Step 2: Update the raw/ rule**

In `CLAUDE.md`, find rule 2 and update it:

Before:
```markdown
2. **`raw/` is append-only.** Never modify or delete ingested sources.
```

After:
```markdown
2. **`raw/` is append-only during normal operation.** Do not modify or delete sources as part of `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`.
```

- [ ] **Step 3: Verify changes**

```bash
grep -n "rebuild" CLAUDE.md
```

Expected: Two matches — one in Skills section, one in Rules section.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add /rebuild skill to CLAUDE.md and clarify raw/ rule

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Update AGENTS.md — add rebuild skill and clarify raw/ rule

**Files:**
- Modify: `AGENTS.md`

Mirror the same two changes made to `CLAUDE.md`.

- [ ] **Step 1: Add rebuild to the skill list**

In `AGENTS.md`, find the Skills section and add rebuild after compile:

Before:
```markdown
Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `lint` — Semantic validation, report to `output/reports/`
```

After:
```markdown
Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `rebuild` — Wipe `compiled/` and recompile from all remaining raw sources
- `lint` — Semantic validation, report to `output/reports/`
```

- [ ] **Step 2: Update the raw/ rule**

In `AGENTS.md`, find the raw/ rule and update it:

Before:
```markdown
- `raw/` is append-only — never modify or delete
```

After:
```markdown
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add /rebuild skill to AGENTS.md and clarify raw/ rule

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Update GEMINI.md — add rebuild skill and clarify raw/ rule

**Files:**
- Modify: `GEMINI.md`

Identical changes to AGENTS.md (they share the same structure).

- [ ] **Step 1: Add rebuild to the skill list**

In `GEMINI.md`, add rebuild after compile in the Skills section:

Before:
```markdown
Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `lint` — Semantic validation, report to `output/reports/`
```

After:
```markdown
Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `rebuild` — Wipe `compiled/` and recompile from all remaining raw sources
- `lint` — Semantic validation, report to `output/reports/`
```

- [ ] **Step 2: Update the raw/ rule**

In `GEMINI.md`, update the raw/ rule:

Before:
```markdown
- `raw/` is append-only — never modify or delete
```

After:
```markdown
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
```

- [ ] **Step 3: Commit**

```bash
git add GEMINI.md
git commit -m "docs: add /rebuild skill to GEMINI.md and clarify raw/ rule

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Update README.md — add rebuild to Core Operations and Data Flow

**Files:**
- Modify: `README.md`

Three changes: add `/rebuild` to the How It Works diagram, the Core Operations table, and the Data Flow diagram.

- [ ] **Step 1: Add rebuild to the How It Works diagram**

In `README.md`, find the How It Works ASCII diagram and add rebuild as an alternative path:

Before:
```
  +--------------+
  |   /compile   |  Extract entities, build articles -> compiled/
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

After:
```
  +--------------+
  |   /compile   |  Extract entities, build articles -> compiled/
  +--------------+
         |
         v
  +--------------+
  |  /rebuild    |  Wipe compiled/, replay all sources (after deletion)
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

- [ ] **Step 2: Add rebuild to the Core Operations table**

Find the Core Operations table and add `/rebuild` between `/compile all` and `/lint`:

Before:
```markdown
| `/compile all` | Recompile entire wiki |
| `/lint` | Run semantic checks, produce report |
```

After:
```markdown
| `/compile all` | Recompile entire wiki |
| `/rebuild` | Wipe `compiled/`, recompile from all remaining raw sources |
| `/lint` | Run semantic checks, produce report |
```

- [ ] **Step 3: Add rebuild to the Data Flow diagram**

Find the Data Flow diagram and add a rebuild annotation. After the `/compile` section, before the final `compiled/` output:

Before:
```
    Update _index.md + _backlinks.md           |
         |                                     |
         v                                     |
    compiled/ <-- ready for Obsidian
```

After:
```
    Update _index.md + _backlinks.md           |
         |                                     |
         v                                     |
    compiled/ <-- ready for Obsidian           |
                                               |
                    /rebuild                    |
                       |                       |
    [delete raw] --> wipe compiled/ --> replay all sources chronologically
```

- [ ] **Step 4: Add rebuild to the `.skills/` line in Directory Structure**

Find the Directory Structure section and update the `.skills/` line:

Before:
```
├── .skills/                   # Agent Skills (ingest, compile, lint)
```

After:
```
├── .skills/                   # Agent Skills (ingest, compile, rebuild, lint)
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add /rebuild to README — operations table, data flow, directory structure

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: End-to-end verification

**Files:**
- None modified — this is a verification task

Verify the implementation is complete and consistent before running the full test plan.

- [ ] **Step 1: Verify all files changed match the spec**

The spec lists these files:

| File | Expected change | Verify |
|---|---|---|
| `.skills/rebuild/SKILL.md` | Created | `cat .skills/rebuild/SKILL.md \| head -3` |
| `CLAUDE.md` | `/rebuild` in Skills + updated raw/ rule | `grep rebuild CLAUDE.md` |
| `AGENTS.md` | `rebuild` in skill list + updated raw/ rule | `grep rebuild AGENTS.md` |
| `GEMINI.md` | `rebuild` in skill list + updated raw/ rule | `grep rebuild GEMINI.md` |
| `README.md` | Core Operations + Data Flow + Directory Structure | `grep rebuild README.md` |

- [ ] **Step 2: Verify unchanged files were NOT modified**

```bash
git diff HEAD~5 -- .skills/compile/SKILL.md .skills/ingest/SKILL.md .skills/lint/SKILL.md hooks/pre-commit.sh _meta/schemas/frontmatter.yaml _meta/wiki.config.yaml
```

Expected: No output (no changes to these files).

- [ ] **Step 3: Run pre-commit hook to verify no validation issues**

```bash
git stash && git stash pop
```

Or trigger a dry-run if the hook supports it. The goal is to confirm the pre-commit hook passes with the new files.

- [ ] **Step 4: Review commit history**

```bash
git log --oneline -6
```

Expected: 5 new commits (one per task 1-5), all with clear messages.

---

### Task 7: Run end-to-end test plan

**Files:**
- Creates test instance at `/tmp/echo-wiki-test`
- Test report saved to `/tmp/echo-wiki-test/output/reports/rebuild-test-2026-04-04.md`

Follow the 6-phase test plan from the spec (`docs/superpowers/specs/2026-04-04-rebuild-skill-design.md`, lines 109-236). Run in a separate Claude session.

- [ ] **Step 1: Set up test environment**

```bash
cp -r /Users/shubh/Desktop/src/echo-wiki /tmp/echo-wiki-test
cd /tmp/echo-wiki-test
git init
cp -r /Users/shubh/Desktop/src/echo-theory-labs-wiki/raw/* /tmp/echo-wiki-test/raw/
cp /Users/shubh/Desktop/src/echo-theory-labs-wiki/_meta/wiki.config.yaml /tmp/echo-wiki-test/_meta/wiki.config.yaml
```

- [ ] **Step 2: Open a new Claude session in the test directory**

```bash
cd /tmp/echo-wiki-test
claude
```

- [ ] **Step 3: Execute Phase 1 — Baseline regression**

Run `/compile all`, then `/lint`. Verify compile processes all 4 raw sources, `_index.md` lists ~14 articles, and lint has no critical issues.

- [ ] **Step 4: Execute Phase 2 — Idempotency test**

Record article count. Run `/rebuild`. Compare `_index.md` — same articles should be present. Run `/lint` — no critical issues.

- [ ] **Step 5: Execute Phase 3 — Source removal + rebuild**

```bash
rm raw/substacks/how-to-build-custom-agent-framework-pi.md
```

Run `/rebuild`. Verify: 3 sources processed, no `pi-framework` tool, no `nader-dabit` person, no references to deleted source. Run `/lint`.

- [ ] **Step 6: Execute Phase 4 — Partial removal test**

```bash
rm raw/blogs/demystifying-evals-for-ai-agents.md
```

Run `/rebuild`. Verify: `agent-harness` concept still exists (sourced from remaining files), `harbor-eval` tool is gone (only sourced from deleted blog). Run `/lint`.

- [ ] **Step 7: Execute Phase 5 — Empty sources edge case**

Delete all remaining raw sources. Run `/rebuild`. Verify it aborts with "No raw sources found" and `compiled/` is unchanged from Phase 4.

- [ ] **Step 8: Execute Phase 6 — Compile regression**

Reset test instance. Run `/compile` on individual sources sequentially. Verify incremental compile still works correctly.

- [ ] **Step 9: Save test report**

Save results to `/tmp/echo-wiki-test/output/reports/rebuild-test-2026-04-04.md` with pass/fail status for each phase.
