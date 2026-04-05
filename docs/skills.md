# Skills

Echo Wiki uses [Agent Skills](https://agentskills.io) to manage the wiki pipeline. Skills are stored in `.skills/` and work with any compatible agent.

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
5. Automatically triggers `/compile`

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
2. Creates source-summary in `compiled/sources/`
3. Extracts concepts, people, and tools
4. Creates new articles or merges into existing ones (never overwrites)
5. Adds `[[wikilinks]]` between related articles
6. Regenerates `_index.md` and `_backlinks.md`

**Four compiled categories:**

| Type | Directory | Examples |
|---|---|---|
| Concepts | `compiled/concepts/` | Ideas, theories, patterns |
| People | `compiled/people/` | Researchers, authors, key figures |
| Tools | `compiled/tools/` | Software, platforms, frameworks |
| Sources | `compiled/sources/` | Summary of each raw source |

## /rebuild

**Wipe `compiled/` and recompile from all remaining raw sources.**

```
/rebuild
```

Use this after manually deleting one or more raw source files. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

What it does:
1. Collects all remaining raw sources (`raw/**/*.md`)
2. If no sources found, aborts safely — `compiled/` is **not** wiped
3. Deletes all files in `compiled/`
4. Replays each source chronologically (`ingested` date, oldest first) using the compile workflow
5. Regenerates `_index.md` and `_backlinks.md`

**Removing a source from the wiki:**

```bash
# 1. Delete the raw source file
rm raw/substacks/outdated-article.md

# 2. Rebuild to reconcile
/rebuild
```

After rebuild, all articles unique to the deleted source are gone, and multi-source articles are rewritten without the deleted source's content.

::: tip
`raw/` is append-only during normal operations (`/ingest` and `/compile` never modify existing raw files). Only delete raw files as a deliberate manual action before running `/rebuild`. Since `compiled/` is fully derived from `raw/`, you can undo a rebuild with `git checkout compiled/`.
:::

## /lint

**Run semantic validation checks on the wiki.**

```
/lint                    # Lint entire wiki
/lint compiled/concepts/ # Lint specific directory
```

Produces a report at `output/reports/lint-<date>.md` with 7 checks:

1. **Frontmatter validation** — required fields, valid enums, type-specific fields
2. **Broken wikilinks** — every `[[link]]` must resolve to a real file
3. **Orphaned articles** — no inbound links
4. **Contradictory claims** — conflicting facts across related articles
5. **Stale content** — past decay rate threshold
6. **Missing concepts** — topics mentioned in 3+ articles without their own article
7. **Duplicate detection** — same entity under different names
