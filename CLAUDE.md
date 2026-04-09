# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for wiki configuration.

## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `wiki/`
- `/rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `/index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `/lint [scope]` — Semantic validation, report to `output/reports/`

## Rules

1. **KB type directories are LLM-only.** Write to KB directories (defined by `entity_types` in `_meta/wiki.config.yaml` — default: `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) via `/compile` or `/rebuild` only. Never edit directly.
2. **`raw/` is append-only during normal operation.** Do not modify or delete sources as part of `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`.
3. **Workspaces are actor-managed.** `wiki/workspaces/<name>/` directories are owned by their creator (human or agent). Skills never modify workspace content.
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

No skill needed. When the user asks a question:
1. Read `wiki/_index.md` to find relevant articles
2. Read those specific articles
3. Synthesize an answer from wiki content
4. Optionally save result to `output/reports/`

## Validation

- **Pre-commit hook** runs automatically — validates frontmatter, wikilinks, and structure integrity
- **`/lint`** for deeper semantic checks (contradictions, staleness, orphans)
- **`./hooks/token-count.sh`** to check wiki size anytime
