# Index Update — Reference

Regenerate `_index.md` and `_backlinks.md`. Covers ALL content in `wiki/` (KB articles + workspace content).

Triggered by `/compile`, `/rebuild`, and `/index`.

## _index.md Format

Read `entity_types` from `_meta/wiki.config.yaml`. Generate one section per entity type using its `label`, plus a Workspaces section at the end.

```
# Wiki Index

## <entity_types[0].label>
- [[<entity_types[0].dir>/<name>|<Title>]] — <one-line summary>

## <entity_types[1].label>
- [[<entity_types[1].dir>/<name>|<Title>]] — <one-line summary>

... (one section per configured entity type)

## Workspaces
### <workspace-name>
- [[workspaces/<workspace-name>/<file>|<Title>]] — <summary or title>
```

For the default config, sections are: Concepts, People, Tools, Sources, Workspaces.

Sorted alphabetically within each section. For workspace files without a `summary` frontmatter field, use just the title.

## _backlinks.md Format

```
# Backlinks

## [[<type>/<name>]]
Linked from:
- [[<type>/<article>]]
- [[workspaces/<workspace>/<file>]]
```

For each article in `wiki/`, scan ALL other files (KB + workspaces) for wikilinks pointing to it. Include cross-zone references.

## Scan Scope

When regenerating, scan ALL `.md` files in `wiki/` recursively. Skip:
- `_index.md` and `_backlinks.md` themselves
- `_log.md` (activity log — not indexed)
- Files in `wiki/.obsidian/`
- Non-`.md` files
