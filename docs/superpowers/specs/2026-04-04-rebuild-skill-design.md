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

## End-to-End Test Plan

### Test Environment

**Clone a fresh test instance** — never test on the real wiki (`echo-theory-labs-wiki`).

```bash
# 1. Clone the echo-wiki template into a test directory
cp -r /Users/shubh/Desktop/src/echo-wiki /tmp/echo-wiki-test
cd /tmp/echo-wiki-test
git init

# 2. Copy real raw sources from echo-theory-labs-wiki as test data
cp -r /Users/shubh/Desktop/src/echo-theory-labs-wiki/raw/* /tmp/echo-wiki-test/raw/

# 3. Copy the wiki config (domains, source types) so compile has context
cp /Users/shubh/Desktop/src/echo-theory-labs-wiki/_meta/wiki.config.yaml /tmp/echo-wiki-test/_meta/wiki.config.yaml
```

**Test data available (from echo-theory-labs-wiki):**

| Raw sources (4) | Key compiled outputs expected |
|---|---|
| `raw/blogs/demystifying-evals-for-ai-agents.md` | concepts: agent-evaluation, agent-harness; tools: harbor-eval, swe-bench |
| `raw/papers/agent-harness-engineering-guide.md` | concepts: harness-engineering, context-engineering |
| `raw/github/awesome-harness-engineering.md` | tools: openclaw; people: mario-zechner |
| `raw/substacks/how-to-build-custom-agent-framework-pi.md` | tools: pi-framework; people: nader-dabit |

Notable: `compiled/concepts/agent-harness.md` draws from 3+ sources — ideal for testing partial source removal.

### Test Sequence

Run in a fresh Claude session against `/tmp/echo-wiki-test`. Each phase validates a specific capability.

#### Phase 1: Baseline — Verify existing operations still work

**Goal:** Confirm `/compile all` produces the expected wiki from raw sources (no regressions).

| Step | Command/Action | Expected Result |
|---|---|---|
| 1.1 | Verify `compiled/` is empty (template state) | Only empty `_index.md` scaffold |
| 1.2 | `/compile all` | Processes all 4 raw sources |
| 1.3 | Check `compiled/_index.md` | Lists ~14 articles across concepts, people, tools, sources |
| 1.4 | `/lint` | No critical issues (broken links, missing frontmatter) |
| 1.5 | Spot-check `compiled/concepts/agent-harness.md` | Has `sources:` referencing multiple raw files |

**Pass criteria:** Compile and lint work identically to how they work today. No regressions.

#### Phase 2: Rebuild on unchanged sources — Idempotency test

**Goal:** `/rebuild` on the same sources produces an equivalent wiki.

| Step | Command/Action | Expected Result |
|---|---|---|
| 2.1 | Record article count and `_index.md` content | Baseline snapshot |
| 2.2 | `/rebuild` | Wipes `compiled/`, replays all 4 sources |
| 2.3 | Compare `_index.md` to baseline | Same articles present (order may differ) |
| 2.4 | `/lint` | No critical issues |
| 2.5 | Spot-check 2-3 articles | Content covers same entities and claims |

**Pass criteria:** Rebuild produces a structurally equivalent wiki. Content may be worded differently (LLM non-determinism) but the same entities, sources, and cross-references exist.

#### Phase 3: Source removal + rebuild — Core feature test

**Goal:** Removing a source and rebuilding produces a clean wiki without the removed source's content.

| Step | Command/Action | Expected Result |
|---|---|---|
| 3.1 | `rm raw/substacks/how-to-build-custom-agent-framework-pi.md` | Source deleted |
| 3.2 | `/rebuild` | Processes 3 remaining sources |
| 3.3 | Check `compiled/_index.md` | No `pi-framework` tool, no `nader-dabit` person, no pi source-summary |
| 3.4 | Grep all `compiled/` for "pi-framework" or "Nader Dabit" | Zero matches — content fully removed |
| 3.5 | Check `compiled/concepts/agent-harness.md` sources | No reference to deleted raw file |
| 3.6 | `/lint` | No broken wikilinks, no orphans referencing removed content |

**Pass criteria:** Articles unique to the removed source are gone. Multi-source articles are rewritten without the removed source's contributions. No dangling references.

#### Phase 4: Multi-source article handling — Partial removal test

**Goal:** An article that drew from multiple sources retains content from remaining sources only.

| Step | Command/Action | Expected Result |
|---|---|---|
| 4.1 | Starting from Phase 3 state (3 sources remain) | Pi substack already removed |
| 4.2 | `rm raw/blogs/demystifying-evals-for-ai-agents.md` | Second source deleted |
| 4.3 | `/rebuild` | Processes 2 remaining sources |
| 4.4 | Check if `agent-harness` concept still exists | Yes — still sourced from `agent-harness-engineering-guide.md` |
| 4.5 | Check `agent-harness.md` sources | Only references remaining raw files |
| 4.6 | Check if `harbor-eval` tool still exists | No — it was only sourced from the deleted blog |
| 4.7 | `/lint` | No critical issues |

**Pass criteria:** Multi-source articles survive partial removal. Single-source articles from deleted sources are gone.

#### Phase 5: Edge case — Rebuild with no sources

**Goal:** `/rebuild` handles empty `raw/` gracefully.

| Step | Command/Action | Expected Result |
|---|---|---|
| 5.1 | Delete all remaining raw sources | `raw/` contains only `.gitkeep` files |
| 5.2 | `/rebuild` | Aborts with "No raw sources found. Nothing to rebuild." |
| 5.3 | Check `compiled/` | **Unchanged** from Phase 4 — not wiped |

**Pass criteria:** Rebuild aborts safely. Does not wipe compiled/ when there's nothing to rebuild from.

#### Phase 6: Regression — Compile still works after rebuild exists

**Goal:** Adding the rebuild skill doesn't break incremental compile.

| Step | Command/Action | Expected Result |
|---|---|---|
| 6.1 | Reset test instance to clean state with all 4 raw sources | Fresh start |
| 6.2 | `/compile raw/blogs/demystifying-evals-for-ai-agents.md` | Single source compiled |
| 6.3 | `/compile raw/papers/agent-harness-engineering-guide.md` | Merges into existing articles |
| 6.4 | Check `agent-harness.md` | Has sources from both raw files |
| 6.5 | `/lint` | No critical issues for compiled articles |

**Pass criteria:** Incremental compile behavior is identical to pre-rebuild behavior.

### Test Execution

The test should be run by spawning a new Claude session in the test directory:

```bash
cd /tmp/echo-wiki-test
claude
```

Then executing each phase sequentially, verifying pass criteria before moving to the next phase. A test report should be saved to `output/reports/rebuild-test-<YYYY-MM-DD>.md` in the test instance.
