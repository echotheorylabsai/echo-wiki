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
