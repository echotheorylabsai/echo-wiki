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
  |   /compile   |  Extract entities, build articles -> compiled/
  +--------------+
         |
         v
  +--------------+
  |  /rebuild    |  Wipe compiled/, replay all sources (after deletion)
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

**The LLM writes all wiki content.** You provide sources, the LLM maintains `compiled/`. You never edit `compiled/` directly — just read it in Obsidian.

```
raw/                          compiled/
├── blogs/                    ├── _index.md        <- Master index
│   └── source-article.md    ├── _backlinks.md    <- Cross-reference map
├── papers/                   ├── concepts/        <- Ideas & theories
├── people/                   │   └── topic.md
├── substacks/                ├── people/          <- Key figures
├── github/                   │   └── person.md
└── media/                    ├── tools/           <- Software & platforms
                              │   └── tool.md
                              └── sources/         <- Source summaries
                                  └── summary.md
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
# File > Open folder as vault > select this directory

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
| `/rebuild` | Wipe `compiled/`, recompile from all remaining raw sources |
| `/lint` | Run semantic checks, produce report |
| `/lint all` | Lint entire wiki |

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
    compiled/ <-- ready for Obsidian           |
                                               |
                    /rebuild                    |
                       |                       |
    [delete raw] --> wipe compiled/ --> replay all sources chronologically
```

## Validation

**Pre-commit hook (automatic):**
- Frontmatter exists and has required fields
- `type` is a valid enum
- All `[[wikilinks]]` resolve to real files
- Every compiled article has `sources:`

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
├── raw/                       # Source documents (append-only)
├── compiled/                  # LLM-maintained wiki (read-only for humans)
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # pre-commit.sh, token-count.sh
├── .skills/                   # Agent Skills (ingest, compile, rebuild, lint)
├── docs/                      # VitePress documentation site
├── .obsidian/                 # Vault config (graph colors, wikilinks)
├── .env.example               # API key template
├── CLAUDE.md                  # Claude Code instructions
└── README.md
```

## Provider Support

Echo Wiki uses the [Agent Skills](https://agentskills.io) open standard. Works with:

- **Claude Code** — via CLAUDE.md + .skills/
- **Codex CLI** — via AGENTS.md + .skills/
- **Gemini CLI** — via GEMINI.md + .skills/
- **Any Agent Skills-compatible agent**

## License

MIT
