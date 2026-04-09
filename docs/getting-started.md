# Getting Started

## Prerequisites

- An LLM agent that supports [Agent Skills](https://agentskills.io) (Claude Code, Codex CLI, Gemini CLI, etc.)
- [Obsidian](https://obsidian.md) for browsing the wiki
- (Optional) [Firecrawl](https://firecrawl.dev) API key for advanced web scraping

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/echotheorylabsai/echo-wiki.git my-wiki
cd my-wiki
```

### 2. Set up environment

```bash
cp .env.example .env
# Edit .env — add your API keys
```

### 3. Configure your domain

Edit `_meta/wiki.config.yaml` — set your wiki name, domains, and entity types:

```yaml
wiki:
  name: "My Research Wiki"
  description: "Knowledge base for..."

domains:
  - name: "topic-1"
    label: "First Topic"
  - name: "topic-2"
    label: "Second Topic"

entity_types:                    # What kinds of articles to create
  - name: concept
    dir: concepts
    label: Concepts
    description: "Ideas, theories, patterns, methodologies"
  - name: person
    dir: people
    label: People
    description: "Researchers, authors, key figures"
  - name: tool
    dir: tools
    label: Tools
    description: "Software, platforms, frameworks"
  - name: source-summary
    dir: sources
    label: Sources
    description: "Summaries of ingested raw sources"
```

The defaults above work for most use cases. For domain-specific wikis (finance, health, etc.), customize `entity_types` — see [Configuration](/configuration).

### 4. Install hooks

```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit
```

### 5. Open in Obsidian

Open Obsidian → File → Open folder as vault → select the **`wiki/`** directory (not the repo root).

The vault comes pre-configured with:
- Wikilinks enabled
- Graph view color groups for default entity types (concepts=blue, people=green, tools=orange, sources=gray, workspaces=purple)
- Frontmatter display
- A default `workspaces/my-notes/` directory for your personal notes

### 6. Ingest your first source

```
/ingest https://example.com/article
```

The agent will fetch the content, save it to `raw/`, then compile it into wiki articles in `wiki/`.

## Directory Structure

```
my-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only, backend)
├── wiki/                      # Obsidian vault (user-facing)
│   ├── concepts/              # KB: default entity type directories
│   ├── people/                #     (configurable via entity_types)
│   ├── tools/
│   ├── sources/
│   ├── workspaces/            # Your notes + agent workspaces
│   │   └── my-notes/          # Default human workspace
│   ├── _index.md              # Master index
│   └── _backlinks.md          # Cross-reference map
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # pre-commit.sh, token-count.sh
├── .claude/skills/            # Agent Skills (ingest, compile, rebuild, lint, index)
├── docs/                      # VitePress documentation site
├── .env.example               # API key template
├── CLAUDE.md                  # Claude Code instructions
└── README.md
```

## What's Next?

- [Configure your domains](/configuration) for your specific use case
- [Learn about the skills](/skills) — ingest, compile, rebuild, lint, and index
- [Set up validation](/validation) — pre-commit hooks and semantic linting
- Create notes in `wiki/workspaces/my-notes/` and run `/index` to include them
