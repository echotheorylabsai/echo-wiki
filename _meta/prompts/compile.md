# Compile — Reference

Transform raw source documents into structured wiki articles in `wiki/`.

## Input
- Path to raw source(s), or "all" for full recompile

## Steps
1. Run Step 0: Verify Wiki Structure (see `_meta/prompts/structure-check.md`)
2. Read `_meta/wiki.config.yaml` and `_meta/schemas/frontmatter.yaml`
3. Read `wiki/_index.md` (understand existing wiki state)
4. Read the target raw source(s)
5. For each source:
   a. Create source-summary in `wiki/sources/`
   b. Extract concepts, people, tools from content
   c. For each entity: check if article exists in `wiki/`
      - Exists → read article, merge new information (never overwrite)
      - New → create article with full frontmatter
   d. Add `[[wikilinks]]` between related articles
6. Regenerate `wiki/_index.md` and `wiki/_backlinks.md` per `_meta/prompts/index-update.md`

## Merge Rules
- Add new information in appropriate sections
- Update `last_updated` date
- Add new source to `sources:` list (plain string path, not wikilink)
- Add new `related:` wikilinks
- NEVER remove or overwrite existing content

## Compiled Type Mapping

Read `entity_types` from `_meta/wiki.config.yaml`. Each entry maps `name` → `wiki/<dir>/`.

Default mapping (ships with framework):

| type | directory | description |
|---|---|---|
| concept | wiki/concepts/ | Ideas, theories, patterns, methodologies, principles |
| person | wiki/people/ | Researchers, authors, founders, key figures |
| tool | wiki/tools/ | Software, platforms, frameworks, products, services |
| source-summary | wiki/sources/ | Summaries of ingested raw sources |

Custom wikis may have different types — always read from config, never assume these defaults.
