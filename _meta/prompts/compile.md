# Compile — Reference

Transform raw source documents into structured wiki articles in `compiled/`.

## Input
- Path to raw source(s), or "all" for full recompile

## Steps
1. Read `_meta/wiki.config.yaml` and `_meta/schemas/frontmatter.yaml`
2. Read `compiled/_index.md` (understand existing wiki state)
3. Read the target raw source(s)
4. For each source:
   a. Create source-summary in `compiled/sources/`
   b. Extract concepts, people, tools from content
   c. For each entity: check if article exists in `compiled/`
      - Exists → read article, merge new information (never overwrite)
      - New → create article with full frontmatter
   d. Add `[[wikilinks]]` between related articles
5. Regenerate `compiled/_index.md` (sorted by type, then alphabetical)
6. Regenerate `compiled/_backlinks.md` (for each article, list all inbound links)

## Merge Rules
- Add new information in appropriate sections
- Update `last_updated` date
- Add new source to `sources:` list
- Add new `related:` wikilinks
- NEVER remove or overwrite existing content

## Compiled Type Mapping
| type | directory |
|---|---|
| concept | compiled/concepts/ |
| person | compiled/people/ |
| tool | compiled/tools/ |
| source-summary | compiled/sources/ |
