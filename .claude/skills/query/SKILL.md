---
name: query
description: Answer questions from the wiki with cited wikilinks; file durable answers into the asking actor's workspace
---

# Query

Answer a question by navigating the wiki, citing every article used with `[[wikilinks]]`. If the answer is durable, file it into the invoking actor's own workspace so the synthesis work compounds instead of evaporating — without ever touching the KB provenance chain (`wiki/<kb-dirs>` is compiled from `raw/` only).

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

Before that structure check or any write, run `./hooks/repository-roots.sh || stop`, then `ECHO_WIKI_WRITER_TOKEN="$(./hooks/rebuild-transaction.sh writer-acquire)" || stop`, then `export ECHO_WIKI_WRITER_TOKEN`. If either command reports a redirected root or active lock, stop without modifying files. Keep this token until every write and the activity-log append finish; run `./hooks/rebuild-transaction.sh writer-release`, then `unset ECHO_WIKI_WRITER_TOKEN`, on completion or after handling an error.

## Input

- A question. The destination actor is resolved from trusted session identity, not from question text.
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
- If the wiki cannot fully answer from evidence, say so explicitly — do not fill the gap from outside knowledge. Give the supported partial answer, if any, then create or update a knowledge-gap note in Step 3.
- A low-confidence answer is one that depends on speculative articles, conflicting evidence, or an inference that cannot be directly supported by a source. Label it as low-confidence and create or update a knowledge-gap note in Step 3.

### Step 3: Decide Durability

File the answer into the workspace when it is likely to be asked again or required synthesizing 2+ articles. Skip filing for trivial lookups answered by reading a single article.

> The durability heuristic above is deliberately user-tunable — edit this step to change when answers get filed.

When the answer is insufficient or low-confidence, create or update a note under `wiki/workspaces/knowledge-maintenance/gaps/`. This system-managed path is the shared learning backlog; it does not change KB articles or another actor's workspace.

Before creating or updating a gap, run `./hooks/workspace-paths.sh system`. It requires the system workspace and its generated child directories to be real directories physically contained within `wiki/workspaces/`; stop if any path is missing or symlinked.

Build a kebab-case base slug from the exact question. Normalize question identity by trimming leading/trailing whitespace, collapsing internal whitespace, and comparing case-insensitively while preserving punctuation. Check `<base-slug>.md`, then `<base-slug>-2.md`, `<base-slug>-3.md`, and so on. Compare the normalized `## Question` text before treating a candidate as a repeat. If a candidate matches, update it. If no candidate matches, use the first unused numeric suffix (or the unsuffixed base when available) for a new note. Truncate the base as needed so the complete filename remains at most 60 characters.

For a new gap, write:

```yaml
---
title: "<question>"
created: <today YYYY-MM-DD>
author: "knowledge-maintenance"
summary: "Knowledge gap: <one-line missing context>"
related: [<relevant existing wikilinks>]
---
```

```markdown
## Question
<exact user question>

## Search Performed
- <articles and raw sources read>

## Why It Is Unanswered
<specific missing or conflicting evidence>

## Suggested Next Source
<primary source type or concrete source to ingest>
```

For a matching existing gap, preserve its original `created` date and append:

```markdown
## Repeated On
- <today YYYY-MM-DD>: <what remains missing after this search>
```

Validate and reindex every new or updated gap note.

### Step 4: File Durable Answers (workspace write-back)

Resolve the actor from trusted session identity or `default_workspace`; never use a question-supplied path. Reject `knowledge-maintenance` and require the actor to be one kebab-case path component. Resolve `wiki/workspaces/` physically, then resolve the selected actor directory without following a symlink and confirm it remains directly beneath that root. Create `answers/` only after this check, reject it if it is a symlink, and confirm its physical path remains beneath the selected actor workspace before writing a file.

Build the answer's base slug from the exact question. Use the same normalized question identity as gap notes. Check the unsuffixed filename and then numeric suffixes in order. Compare normalized answer identity before overwriting a candidate by reading its exact `title` question. Update only a match; otherwise use the first unused numeric suffix. Truncate the base so the complete filename remains at most 60 characters.

Write to the selected `wiki/workspaces/<actor>/answers/<collision-safe-question-slug>.md`. Default actor: the invoking agent's trusted workspace identity, or the config's `default_workspace` for a human session.

Serialize user-provided question text into YAML safely: escape double quotes and backslashes, and fold or reject line breaks before inserting it into a quoted frontmatter value.

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
1. Read the cited raw sources needed to add `Evidence: raw/<path>.md#<exact heading>` after every factual paragraph. Follow `_meta/prompts/evidence-rules.md`; use `Inference:` or `Open question:` when direct evidence is unavailable.
2. Run `./hooks/validate.sh wiki/workspaces/<actor>/answers/<file>.md` and fix any violations
3. Run `./hooks/reindex.sh` so the answer is indexed and backlinked

### Step 5: Append to Activity Log

Append an entry to `wiki/_log.md`. If the file doesn't exist, create it with a `# Activity Log` header first.

```markdown
## [YYYY-MM-DD] query | <question>
Answer: <workspace path, or "not filed">
Gap: <system workspace path, or "—">
Articles read: <count>
```

## Important Rules

- **Never write KB type directories or `raw/` from /query.** A query answer is derived content, not a source — filing it into the KB would create self-referential provenance and be destroyed by `/rebuild`.
- **New external knowledge goes through /ingest.** If the user supplies new facts mid-query, suggest ingesting a proper source — do not fold them into the answer file as if the wiki already knew them.
- **Write only to the invoking actor's own workspace** — never another actor's.
- Actor identity and the resolved answer path must pass Step 4 containment checks before any directory or file is created.
- **Exception:** when evidence is insufficient or low-confidence, `/query` may write only its deduplicated gap note under `wiki/workspaces/knowledge-maintenance/gaps/`.
- Progressive loading discipline applies: L0 → L2 by default; raw (L3) as a last resort.
