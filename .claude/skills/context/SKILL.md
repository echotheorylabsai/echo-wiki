---
name: context
description: Create or refresh a concise, evidence-backed working context pack for a product area or component
---

# Context

Create a short, source-backed working context pack for a product area or component. Context packs help developers and coding agents start from the current architecture, constraints, decisions, and open questions instead of loading a broad slice of the wiki.

## Input

- One product area or component name
- Example: `/context authentication`

Before Step 0 or any write, run `./hooks/repository-roots.sh || stop`, then `ECHO_WIKI_WRITER_TOKEN="$(./hooks/rebuild-transaction.sh writer-acquire)" || stop`, then `export ECHO_WIKI_WRITER_TOKEN`. If either command reports a redirected root or active lock, stop without modifying files. Keep this token until every write and the activity-log append finish; run `./hooks/rebuild-transaction.sh writer-release`, then `unset ECHO_WIKI_WRITER_TOKEN`, on completion or after handling an error.

## Context Loading

1. Read `_meta/wiki.config.yaml` and `_meta/prompts/evidence-rules.md`
2. Run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`
3. Read `wiki/_index.md` and the existing context pack, if present
4. Read only relevant KB articles, then their cited raw sources when needed to support a factual claim

## Steps

### Step 1: Prepare the System Workspace

Run `./hooks/workspace-paths.sh system` before creating or writing anything under the system workspace. It creates only real directories physically contained within `wiki/workspaces/` and rejects symlinks. This is a system-managed workspace: only `/context` may create or refresh files in its `context/` directory.

### Step 2: Establish Evidence

Identify the product area from KB articles and raw sources. If the available evidence does not identify the area or its architecture, report the gap and stop. Do not create a speculative context pack.

### Step 3: Create or Refresh the Pack

Build a kebab-case base slug from the exact product-area input. Normalize product-area identity by trimming leading/trailing whitespace, collapsing internal whitespace, and comparing case-insensitively while preserving punctuation. Check the unsuffixed filename and then numeric suffixes in order. Compare normalized product-area identity before overwriting a candidate by reading its `area` field (for a legacy pack without `area`, use its exact title minus the ` Context` suffix). Update only a match; otherwise use the first unused numeric suffix. Truncate the base so the complete filename remains at most 60 characters.

Write the selected collision-safe path under `wiki/workspaces/knowledge-maintenance/context/`:

Serialize the product-area input into YAML safely: escape double quotes and backslashes, and fold or reject line breaks before inserting it into a quoted frontmatter value.

```yaml
---
title: "<Product Area> Context"
area: "<exact Product Area input>"
created: <today YYYY-MM-DD>
author: "knowledge-maintenance"
summary: "Current engineering context for <Product Area>."
related: [<relevant existing wikilinks>]
---
```

Use this exact section order:

```markdown
## Purpose

<What this area is responsible for.>

Evidence: raw/<path>.md#<exact heading>

## Current Architecture

<Current components and interactions.>

Evidence: raw/<path>.md#<exact heading>

## Constraints

<Non-negotiable technical or product constraints.>

Evidence: raw/<path>.md#<exact heading>

## Decisions

<Links to applicable decisions and their current rationale.>

Evidence: raw/<path>.md#<exact heading>

## Open Questions

Open question: <Unresolved item that needs evidence.>

## Read Next

- [[<existing article path>|<Title>]]
```

Follow `_meta/prompts/evidence-rules.md`. Keep the pack concise, use only existing wikilinks, preserve still-supported content from a prior pack, and replace claims that no longer have evidence with `Open question:` entries.

### Step 4: Validate and Index

Run `./hooks/validate.sh wiki/workspaces/knowledge-maintenance/context/<file>.md`, then `./hooks/reindex.sh`. Fix every validation error before finishing.

### Step 5: Log

Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD] context | <Product Area>
Context pack: wiki/workspaces/knowledge-maintenance/context/<file>.md
Articles read: <count>
```

## Important Rules

- Context packs are derived working context, not a separate knowledge graph or a replacement for KB articles.
- Never write to KB type directories, `raw/`, or another actor's workspace.
- Do not include unsourced facts. Use `Inference:` or `Open question:` when evidence is absent.
