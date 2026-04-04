# Index Update — Reference

Regenerate `_index.md` and `_backlinks.md`. Triggered by compile, not standalone.

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
```

Sorted alphabetically within each section.

## _backlinks.md Format

```
# Backlinks

## [[<type>/<name>]]
Linked from:
- [[<type>/<article>]]
- [[<type>/<article>]]
```

For each article in `compiled/`, list every article that contains a wikilink to it.
