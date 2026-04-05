# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `compiled/`
- `rebuild` — Wipe `compiled/` and recompile from all remaining raw sources
- `lint` — Semantic validation, report to `output/reports/`

## Key Rules

- `compiled/` is LLM-maintained only — never edit manually
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Use `[[wikilinks]]` for all cross-references
- Load context progressively: `_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
