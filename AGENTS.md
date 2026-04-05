# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.claude/skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `wiki/`
- `rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `lint` — Semantic validation, report to `output/reports/`

## Key Rules

- KB type directories (`wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) are LLM-maintained only — never edit manually
- `wiki/workspaces/` is for actor-created content (human or agent) — skills never modify workspace content
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Use `[[wikilinks]]` for cross-references between articles; use plain strings for `sources:` field
- Load context progressively: `wiki/_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
