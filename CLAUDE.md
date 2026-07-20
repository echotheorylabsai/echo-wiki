# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for wiki configuration.

## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `wiki/`
- `/rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `/index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `/lint [scope]` — Semantic validation, report to `output/reports/`
- `/query <question>` — Answer from the wiki with cited wikilinks; file durable answers into the asking actor's workspace
- `/context <product-area>` — Create a concise, evidence-backed context pack for a product area or component
- `/maintain` — Refresh generated indexes and produce a safe, prioritized maintenance queue

## Rules

1. **KB type directories are LLM-only.** Write to KB directories (defined by `entity_types` in `_meta/wiki.config.yaml` — default: `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) via `/compile` or `/rebuild` only. Never edit directly.
2. **`raw/` is append-only during normal operation.** Do not modify or delete sources as part of `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`.
3. **Workspaces are actor-managed.** `wiki/workspaces/<name>/` directories are owned by their creator (human or agent). Skills never modify another actor's workspace content, except system-managed files under `wiki/workspaces/knowledge-maintenance/` written by `/context`, `/query`, or `/maintain`.
4. **Frontmatter required** on all files. Schema: `_meta/schemas/frontmatter.yaml`. KB articles use full schema; workspace files use light schema.
5. **Wikilinks** for all cross-references between articles: `[[concepts/name|Display Name]]`
6. **Sources field** uses plain strings (not wikilinks): `sources: ["raw/blogs/foo.md"]`
7. **Tags** must match domains defined in `_meta/wiki.config.yaml`
8. **Filenames** are kebab-case, max 60 characters, `.md` extension.

## Progressive Context Loading

Load incrementally — never load the entire wiki at once:

| Level | Load | When |
|---|---|---|
| L0 | `wiki/_index.md` | Always start here |
| L1 | `wiki/_backlinks.md` | Resolving cross-references |
| L2 | Specific `wiki/<type>/<article>.md` | Working on specific topics |
| L3 | Specific `raw/<category>/<source>.md` | During ingest/compile only |

## Handling Queries

Use `/query` for questions the wiki should answer — it navigates progressively, cites articles with wikilinks, and files durable answers into the asking actor's workspace. For quick ad-hoc lookups: read `wiki/_index.md`, then the specific articles, and synthesize — never load the entire wiki.

## Validation

- **`./hooks/validate.sh [--all|--staged|<paths>]`** — deterministic schema enforcement (required fields, enums, dates, tags vs domains, source-path existence, filenames, wikilinks). The pre-commit hook runs it on staged files automatically.
- **`./hooks/reindex.sh`** — deterministically regenerates `_index.md` and `_backlinks.md`. Skills call it; never hand-write those two files.
- **`/lint`** for semantic checks (contradictions, staleness, duplicates, orphans, source fidelity)
- **`./hooks/token-count.sh`** to check wiki size anytime
