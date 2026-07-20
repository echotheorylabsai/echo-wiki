# Skills

Echo Wiki uses [Agent Skills](https://agentskills.io) to manage the wiki pipeline. Skills are stored in `.claude/skills/` and work with any compatible agent.

All skills run a structure check (Step 0) before starting. If any required wiki paths are missing, the skill recreates them automatically. See `_meta/prompts/structure-check.md` for details.

All skills append an entry to `wiki/_log.md` after completing — a chronological, parseable record of every operation. The log is auto-created on first use and preserved across rebuilds.

## Keeping Content Fresh

Echo Wiki is command-driven, not a background synchronizer. `/ingest` updates the KB pipeline for a new source, but context packs, durable answers, knowledge gaps, and the maintenance queue are derived artifacts that refresh only when their respective skills run. See [Keeping Content Fresh](/keeping-fresh) for the change-to-next-step guide, including the deliberate workflow for replacing a source.

## /ingest

**Fetch and clean source content into `raw/`.**

```
/ingest <url>           # Ingest a web URL
/ingest <file-path>     # Ingest a local file (md, pdf)
```

What it does:
1. Detects source type from URL pattern (blog, substack, github, paper, tweet)
2. Fetches content via Tavily or Firecrawl
3. Preserves source headings or adds `## Content` when the cleaned body has no heading, ensuring every new raw source has a stable evidence anchor
4. Downloads images locally
5. Writes clean markdown with frontmatter to `raw/`
6. Validates the raw file with `hooks/validate.sh`
7. Appends entry to `wiki/_log.md`
8. Automatically triggers `/compile`

**Source type detection:**

| URL Pattern | Type | Directory |
|---|---|---|
| `*.substack.com/*` | substack | `raw/substacks/` |
| `github.com/*` | github | `raw/github/` |
| `twitter.com/*`, `x.com/*` | tweet | `raw/people/` |
| `arxiv.org/*`, `*.pdf` | paper | `raw/papers/` |
| Other URLs | blog | `raw/blogs/` |
| Podcasts / videos | — | User must specify type |

## /compile

**Compile raw sources into structured wiki articles.**

```
/compile raw/blogs/article.md    # Compile a specific source
/compile all                      # Recompile entire wiki
```

What it does:
1. Reads raw source(s)
2. Creates source-summary in `wiki/sources/`
3. Extracts entities based on configured `entity_types` (default: concepts, people, tools)
4. Creates new articles or merges into existing ones (never overwrites)
5. Adds `[[wikilinks]]` between related articles
6. Runs `hooks/reindex.sh` to regenerate `_index.md` and `_backlinks.md` deterministically (includes workspace content)
7. Validates written articles with `hooks/validate.sh`, fixing violations before finishing
8. Appends entry to `wiki/_log.md`

**KB entity types** (configurable in `_meta/wiki.config.yaml`):

| Type | Directory | Examples |
|---|---|---|
| Concepts | `wiki/concepts/` | Ideas, theories, patterns |
| People | `wiki/people/` | Researchers, authors, key figures |
| Tools | `wiki/tools/` | Software, platforms, frameworks |
| Sources | `wiki/sources/` | Summary of each raw source |

These are the defaults. Custom wikis can define different entity types — see [Configuration](/configuration#entity-types).

`/compile` stops without writing KB content when a legacy raw source has no visible heading. Because skills treat `raw/` as append-only, migrate that source deliberately by adding `## Content` before its body, then retry compilation.

## /rebuild

**Stage and validate a complete KB replacement from all remaining raw sources.**

```
/rebuild
```

Use this after manually deleting one or more raw source files. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

What it does:
1. Collects all remaining raw sources (`raw/**/*.md`)
2. If no sources found, aborts safely — KB directories are **not** wiped
3. Validates every collected raw source and aborts without modifying `wiki/` if any source cannot be replayed
4. Acquires an exclusive rebuild lock and creates a checksummed, isolated staging wiki with empty configured KB type directories and byte-for-byte copies of preserved content
5. Replays each source chronologically (`ingested` date, oldest first) using the compile workflow; any replay failure aborts and discards staging
6. Runs `hooks/reindex.sh` and `hooks/validate.sh --all` against staging, including preserved workspace dependencies
7. If staging fails, leaves the live wiki unchanged and reports obsolete context, queue, gap, or workspace dependencies for explicit remediation
8. After a final snapshot comparison, journal-swaps the complete `wiki/` directory and retains the old version until post-install validation succeeds
9. **Never modifies `wiki/workspaces/`, `wiki/.obsidian/`, or existing `wiki/_log.md` content**, then appends the rebuild summary

**Removing a source from the wiki:**

```bash
# 1. Delete the raw source file
rm raw/substacks/outdated-article.md

# 2. Rebuild to reconcile
/rebuild
```

After rebuild, all articles unique to the deleted source are gone, and multi-source articles are rewritten without the deleted source's content. Workspace content is untouched.

If a preserved workspace artifact still cites the deleted source or links to an article that is no longer produced, staging validation aborts before live files change. Regenerate that derived artifact with `/context`, `/query`, or `/maintain`, or explicitly remove it if it is obsolete, then retry.

The rebuild transaction helper detects concurrent changes before commit. If the process is interrupted during the directory swap, the next `/rebuild` restores the previous complete wiki from its recovery marker before starting again.

::: tip
`raw/` is append-only during normal operations (`/ingest` and `/compile` never modify existing raw files). Only delete raw files as a deliberate manual action before running `/rebuild`.
:::

## /index

**Rescan `wiki/` and update `_index.md` and `_backlinks.md`.**

```
/index
```

Use this after manually creating or modifying workspace content (notes, drafts, etc.) to update the master index.

What it does:
1. Runs `hooks/reindex.sh`, which scans all `.md` files in `wiki/` (KB articles + workspace content)
2. `_index.md` is regenerated with entries grouped by type and workspace
3. `_backlinks.md` is regenerated with cross-zone references and explicit `_No inbound links._` orphan markers
4. Appends entry to `wiki/_log.md`

This is a non-destructive, fully deterministic operation — no LLM writes the two index files, so they cannot drift or silently drop entries.

## /lint

**Run semantic validation checks on the wiki.**

```
/lint                    # Lint entire wiki
/lint all                # Lint entire wiki (explicit)
/lint wiki/concepts/     # Lint specific directory
/lint --domain llm       # Lint articles tagged with a specific domain
```

Produces a report at `output/reports/lint-<date>.md` and appends a summary to `wiki/_log.md`. Runs 7 checks:

1. **Deterministic validation** — runs `hooks/validate.sh --all` (full schema, enums, dates, tags vs domains, source paths, filenames, wikilinks); violations become Critical Issues
2. **Orphaned articles** — collected from `_backlinks.md`'s explicit `_No inbound links._` markers
3. **Contradictory claims** — conflicting facts across related KB articles
4. **Stale content** — past decay rate threshold (KB articles only)
5. **Missing concepts** — topics mentioned in 3+ articles without their own article
6. **Duplicate detection** — same entity under different names
7. **Source fidelity (sampled)** — re-reads cited raw sources for a sample of articles and flags claims not traceable to any cited source

## /query

**Answer questions from the wiki, with citations — and keep the good answers.**

```
/query <question>
```

What it does:
1. Navigates progressively: `_index.md` → relevant articles (raw sources only as a last resort)
2. Synthesizes an answer citing every article used with `[[wikilinks]]`
3. If the answer is durable (multi-article synthesis, likely to recur), resolves a trusted actor workspace and files it under `answers/` with collision-safe naming, evidence validation, and reindexing
4. When evidence is insufficient or low-confidence, creates or updates a shared gap note in `wiki/workspaces/knowledge-maintenance/gaps/`
5. Appends entry to `wiki/_log.md`

Query answers never touch KB type directories or `raw/`: the KB stays a pure projection of `raw/`, and `/rebuild` can never destroy filed answers.

An unanswered engineering question becomes a durable gap note rather than a guessed answer. The note records the question, sources searched, missing evidence, and a suggested next primary source to ingest. Repeated questions update the same note so maintenance can prioritize what real users and agents need next.

For example, if “How are authentication tokens rotated?” is unsupported, `/query` creates one gap note for that question and recommends ingesting the primary authentication RFC, ADR, code document, or tracking issue. Asking again updates the same note instead of creating a duplicate.

## /context

**Create or refresh concise, evidence-backed working context for a product area or component.**

```
/context authentication
```

What it does:
1. Loads the index, relevant articles, and cited raw sources progressively
2. Writes a rebuild-safe context pack to `wiki/workspaces/knowledge-maintenance/context/`, preserving distinct product areas when their slugs collide
3. Summarizes purpose, current architecture, constraints, decisions, open questions, and recommended next reading
4. Adds `Evidence: raw/<path>.md#<exact heading>` after factual paragraphs
5. Validates and reindexes the pack

Context packs are a focused Markdown view for coding work, not a separate graph or a replacement for source-backed KB articles.

## /maintain

**Refresh generated indexes and create a safe, prioritized maintenance queue.**

```
/maintain
```

What it does:
1. Runs `reindex.sh`, deterministic validation, and the existing `/lint all` workflow
2. Reads shared knowledge gaps from `wiki/workspaces/knowledge-maintenance/gaps/`
3. Writes `wiki/workspaces/knowledge-maintenance/maintenance-queue.md`, ordered by broken evidence, contradictions/staleness, recurring gaps, then orphan/duplicate candidates
4. Validates and reindexes the generated queue

`/maintain` is safe autopilot. It refreshes generated indexes, writes the daily lint report and maintenance queue, and appends to `_log.md`; it never changes `raw/`, KB articles, context packs, or ordinary workspaces.
