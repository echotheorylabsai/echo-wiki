# Obsidian Integration

Echo Wiki is designed to be browsed in [Obsidian](https://obsidian.md) as a local vault.

## Setup

1. Install Obsidian from [obsidian.md](https://obsidian.md)
2. Open Obsidian → File → Open folder as vault
3. Select your echo-wiki directory

The vault comes pre-configured in `.obsidian/`:

## Pre-configured Settings

- **Wikilinks enabled** — `[[concept-name|Display Name]]` links work out of the box
- **Shortest path linking** — `[[concepts/mcp-protocol]]` resolves via suffix matching
- **Frontmatter display** — YAML metadata visible in reading view

## Graph View

The graph view is color-coded by article type:

| Type | Color | Query |
|---|---|---|
| Concepts | Blue | `path:compiled/concepts` |
| People | Green | `path:compiled/people` |
| Tools | Orange | `path:compiled/tools` |
| Sources | Gray | `path:compiled/sources` |

Open graph view: Ctrl/Cmd + G

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
