# Index Update — Reference

Regenerate `_index.md` and `_backlinks.md`. Covers ALL content in `wiki/` (KB articles + workspace content).

Triggered by `/compile`, `/rebuild`, and `/index`.

## _index.md Format

```
# Wiki Index

## Concepts
- [[concepts/<name>|<Title>]] — <one-line summary>

## People
- [[people/<name>|<Title>]] — <one-line summary>

## Tools
- [[tools/<name>|<Title>]] — <one-line summary>

## Sources
- [[sources/<name>|<Title>]] — <one-line summary>

## Workspaces
### <workspace-name>
- [[workspaces/<workspace-name>/<file>|<Title>]] — <summary or title>
```

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
- Files in `wiki/.obsidian/`
- Non-`.md` files
