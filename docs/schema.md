# Frontmatter Schema

Every file in `compiled/` requires YAML frontmatter. The schema is defined at `_meta/schemas/frontmatter.yaml`.

## Shared Fields (all types)

```yaml
---
title: "Article Title"
type: concept | person | tool | source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast | medium | slow
confidence: high | medium | speculative
tags: ["domain-1", "domain-2"]
sources: ["[[raw/blogs/source.md]]"]
related: ["[[concepts/related]]"]
summary: "One-line summary for index"
---
```

## Type-Specific Fields

| Type | Extra Fields |
|---|---|
| `concept` | `domain`, `prerequisites` |
| `person` | `role`, `affiliations`, `follows` |
| `tool` | `category` (framework/platform/service/product), `repo`, `maintained` |
| `source-summary` | `source_url`, `source_type`, `author`, `source_date` |

## Raw Source Frontmatter

Files in `raw/` use a simpler schema:

```yaml
---
title: "Source Title"
source_url: "https://..."
source_type: blog | paper | tweet | substack | github | podcast | video
source_date: 2026-04-01
author: "Author Name"
ingested: 2026-04-04
ingestion_tool: tavily | firecrawl | local
tags: ["domain-1"]
---
```

## Confidence Levels

| Level | Definition |
|---|---|
| `high` | Well-sourced from multiple references or authoritative primary sources |
| `medium` | Single source, or well-known but not independently verified |
| `speculative` | Inferred, opinion-based, from unverified sources, or emerging claims |

## Filename Convention

- Kebab-case, derived from article title
- Max 60 characters
- `.md` extension
- Examples: `model-context-protocol.md`, `andrej-karpathy.md`
