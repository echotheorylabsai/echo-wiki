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

Edit `_meta/wiki.config.yaml` — set your wiki name, description, and knowledge domains:

```yaml
wiki:
  name: "My Research Wiki"
  description: "Knowledge base for..."

domains:
  - name: "topic-1"
    label: "First Topic"
  - name: "topic-2"
    label: "Second Topic"
    decay_rate_override: fast  # optional
```

See [Configuration](/configuration) for full reference.

### 4. Install hooks

```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit
```

### 5. Open in Obsidian

Open Obsidian → File → Open folder as vault → select your wiki directory.

The vault comes pre-configured with:
- Wikilinks enabled
- Graph view color groups (concepts=blue, people=green, tools=orange, sources=gray)
- Frontmatter display

### 6. Ingest your first source

```
/ingest https://example.com/article
```

The agent will fetch the content, save it to `raw/`, then compile it into wiki articles in `compiled/`.

## Directory Structure

```
my-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only)
├── compiled/                  # LLM-maintained wiki (read-only for humans)
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # pre-commit.sh, token-count.sh
├── .skills/                   # Agent Skills (ingest, compile, rebuild, lint)
├── .obsidian/                 # Vault config (graph colors, wikilinks)
├── .env.example               # API key template
├── CLAUDE.md                  # Claude Code instructions
└── README.md
```

## What's Next?

- [Configure your domains](/configuration) for your specific use case
- [Learn about the skills](/skills) — ingest, compile, rebuild, and lint
- [Set up validation](/validation) — pre-commit hooks and semantic linting
