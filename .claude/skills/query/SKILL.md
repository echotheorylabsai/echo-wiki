---
name: query
description: Answer questions from the wiki with cited wikilinks; file durable answers into the asking actor's workspace
---

# Query

Answer a question by navigating the wiki, citing every article used with `[[wikilinks]]`. If the answer is durable, file it into the invoking actor's own workspace so the synthesis work compounds instead of evaporating — without ever touching the KB provenance chain (`wiki/<kb-dirs>` is compiled from `raw/` only).

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- A question, plus optionally the actor name to file durable answers under
- Example: `/query what do we know about context engineering?`

## Steps

### Step 1: Locate Relevant Articles (progressive loading)

1. Read `wiki/_index.md` (L0) — identify candidate articles by title and summary
2. Read `wiki/_backlinks.md` (L1) only if you need to follow cross-references
3. Read the specific candidate articles (L2)
4. Only if an article is insufficient AND cites a raw source, read that raw file (L3)

Never load the entire wiki.

### Step 2: Synthesize the Answer

- Answer from wiki content only; cite every article used with `[[wikilinks]]`
- If the wiki cannot answer, say so explicitly — do not fill the gap from outside knowledge. Suggest sources to `/ingest` instead.

### Step 3: Decide Durability

File the answer into the workspace when it is likely to be asked again or required synthesizing 2+ articles. Skip filing for trivial lookups answered by reading a single article.

> The durability heuristic above is deliberately user-tunable — edit this step to change when answers get filed.

### Step 4: File Durable Answers (workspace write-back)

Write to `wiki/workspaces/<actor>/answers/<kebab-case-question-slug>.md`. Default actor: the invoking agent's workspace name, or the config's `default_workspace` for a human session.

```yaml
---
title: "<The question>"
created: <today YYYY-MM-DD>
author: "<actor>"
summary: "<one-line answer>"
related: ["[[<cited article path>]]"]
---

<The synthesized answer, with [[wikilinks]] to every cited article.>
```

Then:
1. Run `./hooks/validate.sh wiki/workspaces/<actor>/answers/<file>.md` and fix any violations
2. Run `./hooks/reindex.sh` so the answer is indexed and backlinked

### Step 5: Append to Activity Log

Append an entry to `wiki/_log.md`. If the file doesn't exist, create it with a `# Activity Log` header first.

```markdown
## [YYYY-MM-DD] query | <question>
Answer: <workspace path, or "not filed">
Articles read: <count>
```

## Important Rules

- **Never write KB type directories or `raw/` from /query.** A query answer is derived content, not a source — filing it into the KB would create self-referential provenance and be destroyed by `/rebuild`.
- **New external knowledge goes through /ingest.** If the user supplies new facts mid-query, suggest ingesting a proper source — do not fold them into the answer file as if the wiki already knew them.
- **Write only to the invoking actor's own workspace** — never another actor's.
- Progressive loading discipline applies: L0 → L2 by default; raw (L3) as a last resort.
