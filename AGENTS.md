# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `lint` — Semantic validation, report to `output/reports/`

## Key Rules

- `compiled/` is LLM-maintained only — never edit manually
- `raw/` is append-only — never modify or delete
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Use `[[wikilinks]]` for all cross-references
- Load context progressively: `_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
