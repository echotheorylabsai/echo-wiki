# Structure Check — Reference

Verify wiki directory structure is intact. Run as Step 0 of every skill before any other work.

Referenced by: `/compile`, `/rebuild`, `/lint`, `/index`, `/ingest`

## Required Paths

Read `entity_types` from `_meta/wiki.config.yaml` to determine KB directories.

| Path | Type | Recovery |
|---|---|---|
| `wiki/` | directory | Create it |
| `wiki/<entity_types[].dir>/` | directory (one per configured type) | Create it |
| `wiki/workspaces/` | directory | Create with `my-notes/.gitkeep` inside |
| `wiki/_index.md` | file | Create scaffold with section headers from config |
| `wiki/_backlinks.md` | file | Create with `# Backlinks` header |

For the default config, KB directories are: `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`.

**Note:** `wiki/_log.md` is not required — it is created automatically by the first skill invocation. If present, it must be preserved (never deleted by any skill or rebuild).

## Behavior

For each required path:
1. Check if it exists
2. If missing, recreate it silently (see Recovery column)
3. Continue to the skill's main workflow

## _index.md Scaffold

If `wiki/_index.md` must be recreated, generate section headers from `entity_types[].label` in config, plus Workspaces:

```
# Wiki Index

## <entity_types[0].label>

## <entity_types[1].label>

... (one per configured entity type)

## Workspaces
```

For the default config, this produces: Concepts, People, Tools, Sources, Workspaces.

## Important

- Never abort or error on missing structure — always self-heal
- Log a brief note if any path was recreated (e.g., "Recreated missing wiki/concepts/ directory")
- This check is idempotent — running it multiple times is safe
