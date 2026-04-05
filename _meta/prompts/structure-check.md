# Structure Check — Reference

Verify wiki directory structure is intact. Run as Step 0 of every skill before any other work.

Referenced by: `/compile`, `/rebuild`, `/lint`, `/index`, `/ingest`

## Required Paths

| Path | Type | Recovery |
|---|---|---|
| `wiki/` | directory | Create it |
| `wiki/concepts/` | directory | Create it |
| `wiki/people/` | directory | Create it |
| `wiki/tools/` | directory | Create it |
| `wiki/sources/` | directory | Create it |
| `wiki/workspaces/` | directory | Create with `my-notes/.gitkeep` inside |
| `wiki/_index.md` | file | Create scaffold with section headers |
| `wiki/_backlinks.md` | file | Create with `# Backlinks` header |

## Behavior

For each required path:
1. Check if it exists
2. If missing, recreate it silently (see Recovery column)
3. Continue to the skill's main workflow

## _index.md Scaffold

If `wiki/_index.md` must be recreated:

```
# Wiki Index

## Concepts

## People

## Tools

## Sources

## Workspaces
```

## Important

- Never abort or error on missing structure — always self-heal
- Log a brief note if any path was recreated (e.g., "Recreated missing wiki/concepts/ directory")
- This check is idempotent — running it multiple times is safe
