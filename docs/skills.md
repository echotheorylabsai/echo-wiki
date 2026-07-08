# Skills

Echo Wiki uses [Agent Skills](https://agentskills.io) to manage the wiki pipeline. Skills are stored in `.claude/skills/` and work with any compatible agent.

All skills run a structure check (Step 0) before starting. If any required wiki paths are missing, the skill recreates them automatically. See `_meta/prompts/structure-check.md` for details.

All skills append an entry to `wiki/_log.md` after completing — a chronological, parseable record of every operation. The log is auto-created on first use and preserved across rebuilds.

## /ingest

**Fetch and clean source content into `raw/`.**

```
/ingest <url>           # Ingest a web URL
/ingest <file-path>     # Ingest a local file (md, pdf)
```

What it does:
1. Detects source type from URL pattern (blog, substack, github, paper, tweet)
2. Fetches content via Tavily or Firecrawl
3. Downloads images locally
4. Writes clean markdown with frontmatter to `raw/`
5. Validates the raw file with `hooks/validate.sh`
6. Appends entry to `wiki/_log.md`
7. Automatically triggers `/compile`

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

## /rebuild

**Wipe KB type directories and recompile from all remaining raw sources.**

```
/rebuild
```

Use this after manually deleting one or more raw source files. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

What it does:
1. Collects all remaining raw sources (`raw/**/*.md`)
2. If no sources found, aborts safely — KB directories are **not** wiped
3. Deletes all files in KB type directories (configured via `entity_types` — default: `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`)
4. **Preserves `wiki/workspaces/`, `wiki/.obsidian/`, and `wiki/_log.md`** — workspace content and activity log are never touched
5. Replays each source chronologically (`ingested` date, oldest first) using the compile workflow
6. Runs `hooks/reindex.sh` to regenerate `_index.md` and `_backlinks.md` (includes preserved workspace content)
7. Validates the rebuilt wiki with `hooks/validate.sh --all`
8. Appends rebuild summary to `wiki/_log.md`

**Removing a source from the wiki:**

```bash
# 1. Delete the raw source file
rm raw/substacks/outdated-article.md

# 2. Rebuild to reconcile
/rebuild
```

After rebuild, all articles unique to the deleted source are gone, and multi-source articles are rewritten without the deleted source's content. Workspace content is untouched.

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
3. If the answer is durable (multi-article synthesis, likely to recur), files it to `wiki/workspaces/<actor>/answers/` — validated and reindexed so it's browsable and backlinked in Obsidian
4. Appends entry to `wiki/_log.md`

Query answers never touch KB type directories or `raw/`: the KB stays a pure projection of `raw/`, and `/rebuild` can never destroy filed answers.
