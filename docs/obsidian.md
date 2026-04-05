# Obsidian Integration

Echo Wiki is designed to be browsed in [Obsidian](https://obsidian.md) as a local vault.

## Setup

1. Install Obsidian from [obsidian.md](https://obsidian.md)
2. Open Obsidian → File → Open folder as vault
3. Select the **`wiki/`** directory (not the repo root)

The vault comes pre-configured in `wiki/.obsidian/`:

## Pre-configured Settings

- **Wikilinks enabled** — `[[concept-name|Display Name]]` links work out of the box
- **Shortest path linking** — `[[concepts/mcp-protocol]]` resolves via suffix matching
- **Frontmatter display** — YAML metadata visible in reading view
- **Clean sidebar** — only KB articles and workspaces visible, no backend files

## Graph View

The graph view is color-coded by content type:

| Type | Color | Query |
|---|---|---|
| Concepts | Blue | `path:concepts` |
| People | Green | `path:people` |
| Tools | Orange | `path:tools` |
| Sources | Gray | `path:sources` |
| Workspaces | Purple | `path:workspaces` |

Open graph view: Ctrl/Cmd + G

## Workspaces

The `workspaces/` directory is where you (and agents) create content:

- **`my-notes/`** ships as the default human workspace
- Agents create their own workspace directories on demand (e.g., `workspaces/content-creator/`)
- Workspace content uses a light frontmatter schema (just `title`, `created`, `author`, `tags`)
- Run `/index` after creating workspace content to include it in the master index
- Workspace content is never touched by `/rebuild`

## Recommended Plugins

These are optional but enhance the experience:

- **Graph View** (built-in) — visualize article connections
- **Backlinks** (built-in) — see which articles link to the current one
- **Obsidian Git** — sync wiki changes via git
- **Dataview** — query articles by frontmatter fields

## Tips

- Use `_index.md` as your starting point — it lists all articles with summaries
- Click any `[[wikilink]]` to navigate between articles
- Use the backlinks panel (right sidebar) to discover connections
- The graph view shows the overall structure of your knowledge base
- Workspace notes can link to KB articles with `[[concepts/foo|Foo]]`
