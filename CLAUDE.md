# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for wiki configuration.

## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `compiled/`
- `/rebuild` — Wipe `compiled/` and recompile from all remaining raw sources
- `/lint [scope]` — Semantic validation, report to `output/reports/`

## Rules

1. **`compiled/` is LLM-only.** Write via `/compile` or `/rebuild` only. Never edit directly.
2. **`raw/` is append-only during normal operation.** Do not modify or delete sources as part of `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`.
3. **Frontmatter required** on all files. Schema: `_meta/schemas/frontmatter.yaml`
4. **Wikilinks** for all cross-references: `[[concepts/name|Display Name]]`
5. **Tags** must match domains defined in `_meta/wiki.config.yaml`
6. **Filenames** are kebab-case, max 60 characters, `.md` extension.

## Progressive Context Loading

Load incrementally — never load the entire wiki at once:

| Level | Load | When |
|---|---|---|
| L0 | `compiled/_index.md` | Always start here |
| L1 | `compiled/_backlinks.md` | Resolving cross-references |
| L2 | Specific `compiled/<type>/<article>.md` | Working on specific topics |
| L3 | Specific `raw/<category>/<source>.md` | During ingest/compile only |

## Handling Queries

No skill needed. When the user asks a question:
1. Read `compiled/_index.md` to find relevant articles
2. Read those specific articles
3. Synthesize an answer from wiki content
4. Optionally save result to `output/reports/`

## Validation

- **Pre-commit hook** runs automatically — validates frontmatter and wikilinks
- **`/lint`** for deeper semantic checks (contradictions, staleness, orphans)
- **`./hooks/token-count.sh`** to check wiki size anytime
