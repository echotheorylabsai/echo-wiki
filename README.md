# Echo Wiki

A generic, LLM-maintained knowledge base system. Ingest sources, compile a structured wiki, browse in Obsidian. Works with any domain — AI research, finance, healthcare, marketing, or anything else.

> **[Read the docs](https://echotheorylabsai.github.io/echo-wiki/)** for full setup guide, configuration reference, and usage examples.

## How It Works

```
  URLs / Files / PDFs
         |
         v
  +--------------+
  |   /ingest    |  Fetch + clean source -> raw/
  +--------------+
         |
         v
  +--------------+
  |   /compile   |  Extract entities, build articles -> wiki/
  +--------------+
         |
         v
  +--------------+
  |  /rebuild    |  Wipe KB dirs, replay all sources (after deletion)
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

> `/rebuild` is only needed after manually deleting raw source files. Normal workflow is `/ingest` → `/compile`.

**The LLM writes all wiki content.** You provide sources, the LLM maintains `wiki/`. You never edit KB articles directly — just read them in Obsidian. You can create your own notes and drafts in `wiki/workspaces/`.

```
raw/                          wiki/ (Obsidian vault)
├── blogs/                    ├── _index.md        <- Master index
│   └── source-article.md    ├── _backlinks.md    <- Cross-reference map
├── papers/                   ├── concepts/        <- Default entity types
├── people/                   │   └── topic.md
├── substacks/                ├── people/          <- (configurable via
├── github/                   │   └── person.md
└── media/                    ├── tools/           <-  entity_types in config)
                              │   └── tool.md
                              ├── sources/         <- Source summaries
                              │   └── summary.md
                              └── workspaces/      <- Actor workspaces
                                  └── my-notes/    <- Your notes
```

## Quick Start

```bash
# 1. Clone
git clone <repo-url> my-wiki && cd my-wiki

# 2. Set up environment
cp .env.example .env
# Edit .env — add your API keys

# 3. Configure your domain
# Edit _meta/wiki.config.yaml — set name, description, domains

# 4. Install hooks
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit

# 5. Open in Obsidian
# File > Open folder as vault > select the wiki/ directory

# 6. Ingest your first source
/ingest https://example.com/article
```

## Configuration

All customization lives in one file: `_meta/wiki.config.yaml`

```yaml
wiki:
  name: "My Wiki"
  description: "What this wiki is about"

domains:
  - name: "topic"
    label: "Topic Label"

entity_types:                  # What kinds of articles to create
  - name: concept              # (defaults shown — customize for your domain)
    dir: concepts
    label: Concepts
    description: "Ideas, theories, patterns"
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

vault:
  dir: wiki
  default_workspace: my-notes

defaults:
  decay_rate: medium    # fast | medium | slow
  confidence: medium    # high | medium | speculative
```

See `.env.example` for required API keys.

## Core Operations

| Command | What it does |
|---|---|
| `/ingest <url>` | Fetch URL, save clean markdown to `raw/` |
| `/ingest <path>` | Import local file (md, pdf) to `raw/` |
| `/compile <path>` | Compile raw source into wiki articles |
| `/compile all` | Recompile entire wiki |
| `/rebuild` | Wipe KB dirs, recompile from all remaining raw sources |
| `/index` | Rescan `wiki/` and update `_index.md` and `_backlinks.md` |
| `/lint` | Run semantic checks, produce report |
| `/lint all` | Lint entire wiki |

## Workspaces

Users and agents can create content alongside KB articles in `wiki/workspaces/`:

```
wiki/workspaces/
├── my-notes/              <- Default human workspace (ships with template)
│   ├── research-log.md
│   └── todo.md
├── content-creator/       <- Agent workspace (created on demand)
│   └── drafts/
└── social-media/          <- Agent workspace
    └── drafts/
```

- **Zero registration** — just create a directory under `workspaces/`
- **Agents and humans are peers** — same structure, same rules
- **Cross-zone wikilinks** — workspace notes can link to KB articles and vice versa
- **Rebuild-safe** — `/rebuild` never touches `workspaces/`
- Run `/index` after creating workspace content to update the master index

## Data Flow

```
                    /ingest
                       |
    URL -----> [Tavily/Firecrawl] -----> raw/<category>/<source>.md
    File ----> [copy + frontmatter] --/        |
                                               |
                    /compile                   |
                       |                       |
    raw source --------+                       |
         |                                     |
         v                                     |
    Extract: concepts, people, tools           |
         |                                     |
         v                                     |
    For each entity:                           |
      exists? --> MERGE (add info, keep old)   |
      new?    --> CREATE (full frontmatter)     |
         |                                     |
         v                                     |
    Update _index.md + _backlinks.md           |
         |                                     |
         v                                     |
    wiki/ <-- ready for Obsidian               |
                                               |
                    /rebuild                    |
                       |                       |
    [delete raw] --> wipe KB dirs --> replay all sources chronologically
                     (workspaces preserved)
```

## Validation

**Pre-commit hook (automatic):**
- Structure integrity — protected paths must exist
- KB articles: frontmatter, required fields, type enum, wikilinks, sources
- Workspace files: frontmatter, title, created

**Semantic lint (`/lint`, on-demand):**
- Contradictory claims across articles
- Stale content past decay thresholds
- Orphaned articles (no inbound links)
- Missing concepts (referenced but no article)
- Duplicate concepts under different names

**Token count (post-commit, informational):**
```bash
./hooks/token-count.sh    # Run manually anytime
# Also runs after each commit (never blocks)
```

## Directory Structure

```
echo-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only, backend)
├── wiki/                      # Obsidian vault (user-facing)
│   ├── concepts/              # KB: default entity type directories
│   ├── people/                #     (configurable via entity_types in config)
│   ├── tools/
│   ├── sources/
│   ├── workspaces/            # Actor workspaces (human + agent)
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

## Provider Support

Echo Wiki uses the [Agent Skills](https://agentskills.io) open standard. Works with:

- **Claude Code** — via CLAUDE.md + .claude/skills/
- **Codex CLI** — via AGENTS.md + .claude/skills/
- **Gemini CLI** — via GEMINI.md + .claude/skills/
- **Any Agent Skills-compatible agent**

## License

MIT
