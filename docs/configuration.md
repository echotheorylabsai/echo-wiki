# Configuration

All customization lives in a single file: `_meta/wiki.config.yaml`

## Full Schema

```yaml
wiki:
  name: "My Wiki"                     # Display name
  description: "Knowledge base for…"  # One-line purpose

domains:                              # Knowledge domains (used in frontmatter tags)
  - name: "topic"                     # Kebab-case identifier
    label: "Topic Label"              # Human-readable label
    decay_rate_override: fast          # Optional: overrides global default

entity_types:                         # KB article types and directories
  - name: concept                     # Frontmatter type value (kebab-case)
    dir: concepts                     # Directory under wiki/
    label: Concepts                   # Section header in _index.md
    description: "Ideas, theories, patterns, methodologies, principles"
  - name: person
    dir: people
    label: People
    description: "Researchers, authors, founders, key figures"
  - name: tool
    dir: tools
    label: Tools
    description: "Software, platforms, frameworks, products, services"
  - name: source-summary
    dir: sources
    label: Sources
    description: "Summaries of ingested raw sources"

source_types:                         # Allowed source types
  - blog
  - paper
  - tweet
  - substack
  - github
  - podcast
  - video

ingestion:
  tavily:
    enabled: true                     # Available via MCP
  firecrawl:
    enabled: false                    # Requires FIRECRAWL_API_KEY
    api_key: "${FIRECRAWL_API_KEY}"

defaults:
  decay_rate: medium                  # fast | medium | slow
  confidence: medium                  # high | medium | speculative

vault:
  dir: wiki                       # Directory used as Obsidian vault
  default_workspace: my-notes     # Pre-created workspace for human user

schema_version: 1
```

## Domains

Domains are the knowledge areas your wiki covers. They drive the `tags` field in article frontmatter.

**Examples by use case:**

| Use Case | Domains |
|---|---|
| AI Research | `llm`, `agents`, `evals`, `mcp`, `fine-tuning` |
| Finance | `equities`, `macro`, `crypto`, `options`, `portfolio` |
| Healthcare | `clinical-trials`, `genomics`, `devices`, `policy` |
| Marketing | `seo`, `content`, `paid-ads`, `analytics` |

## Entity Types

Entity types define what kinds of articles your wiki contains and where they live. Each type maps to a directory under `wiki/`.

| Field | Required | Purpose |
|---|---|---|
| `name` | Yes | Value used in frontmatter `type:` field. Kebab-case. |
| `dir` | Yes | Directory name under `wiki/`. Auto-created if missing. |
| `label` | Yes | Human-readable section header in `_index.md`. |
| `description` | Yes | Guides LLM entity extraction during `/compile`. Also documents the type. |

**`source-summary` is special** — it's auto-created per raw source during `/compile`, not extracted from content. Every wiki should include it.

**Examples by domain:**

| Domain | Entity Types |
|---|---|
| AI Research | concept, person, tool, source-summary (defaults) |
| Finance | company, indicator, market, source-summary |
| Healthcare | condition, treatment, study, source-summary |
| Marketing | channel, campaign, metric, source-summary |

**Custom type example:**

```yaml
entity_types:
  - name: company
    dir: companies
    label: Companies
    description: "Public companies, startups, investment funds, corporate entities"
  - name: indicator
    dir: indicators
    label: Indicators
    description: "Financial metrics, ratios, economic indicators (P/E, RSI, GDP, CPI)"
  - name: source-summary
    dir: sources
    label: Sources
    description: "Summaries of ingested raw sources"
```

The LLM uses each type's `description` to decide what entities to extract during `/compile`. No code changes needed — just edit config and start ingesting.

## Decay Rates

Control how quickly content is considered stale:

| Rate | Verify every | Best for |
|---|---|---|
| `fast` | 30 days | Model releases, pricing, market data, tool versions |
| `medium` | 90 days | Patterns, frameworks, best practices, regulations |
| `slow` | 365 days | Core theory, math, established principles |

Domains can override the global default with `decay_rate_override`.

## Environment Variables

Copy `.env.example` to `.env` and fill in your keys:

```bash
FIRECRAWL_API_KEY=     # Required if firecrawl is enabled
ANTHROPIC_API_KEY=     # For non-CLI API usage
OPENAI_API_KEY=        # Optional
GOOGLE_API_KEY=        # Optional
```

`.env` is git-ignored. Never commit API keys.

## Vault

The `vault` section configures the Obsidian-facing directory:

| Field | Default | Description |
|---|---|---|
| `dir` | `wiki` | Directory name for the Obsidian vault |
| `default_workspace` | `my-notes` | Pre-created workspace for human users |
