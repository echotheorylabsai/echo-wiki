# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.claude/skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `wiki/`
- `rebuild` — Stage, validate, and replace the KB projection from all remaining raw sources
- `index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `lint` — Semantic validation, report to `output/reports/`
- `query` — Answer from the wiki with cited wikilinks; file durable answers into the asking actor's workspace
- `context` — Create a concise, evidence-backed context pack for a product area or component
- `maintain` — Refresh generated indexes and produce a safe, prioritized maintenance queue

## Key Rules

- KB type directories (defined by `entity_types` in `_meta/wiki.config.yaml` — default: `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) are LLM-maintained only — never edit manually
- `wiki/workspaces/` is for actor-created content (human or agent) — skills never modify another actor's workspace content, except the system-managed `knowledge-maintenance/` workspace used by `/context`, `/query`, and `/maintain`
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Run `./hooks/validate.sh` on written files (skills specify when); run `./hooks/reindex.sh` instead of hand-writing `_index.md`/`_backlinks.md`
- Use `[[wikilinks]]` for cross-references between articles; use plain strings for `sources:` field
- Load context progressively: `wiki/_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
