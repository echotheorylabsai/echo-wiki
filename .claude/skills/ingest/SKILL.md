---
name: ingest
description: Fetch and clean source content into raw/ with valid frontmatter
---

# Ingest

Fetch content from URLs or local files and save as clean markdown in `raw/` with valid frontmatter. After ingestion, proceed to compile.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- One or more URLs, or local file paths (md, pdf, txt)
- Optional: `source_type` override (required for podcast/video URLs, since those can't be auto-detected)

## Context Loading

1. Read `_meta/wiki.config.yaml` — for allowed source types and ingestion tool settings
2. Read `wiki/_index.md` — check existing source-summaries to avoid duplicate ingestion

## Steps

### Step 1: Determine Source Type

Auto-detect from URL or file:

| Pattern | source_type |
|---|---|
| `*.substack.com/*` | substack |
| `github.com/*` | github |
| `twitter.com/*` or `x.com/*` | tweet |
| `arxiv.org/*` or file ends `.pdf` | paper |
| Other URLs | blog |
| Local `.md` or `.txt` files | detect from content or default to blog |
| Podcasts / videos | **User must specify explicitly** |

### Step 2: Fetch Content

Choose the appropriate tool based on config and availability:

**Tavily extract** (preferred for most URLs):
- Use `tavily_extract` tool with `urls` parameter (string array)
- Available via MCP — no API key required

**Firecrawl** (for complex pages, heavy images, Substacks):
- `POST https://api.firecrawl.dev/v1/scrape`
- Request body: `{"url": "<target-url>", "formats": ["markdown"]}`
- Header: `Authorization: Bearer $FIRECRAWL_API_KEY`
- Requires `FIRECRAWL_API_KEY` in `.env` and `firecrawl.enabled: true` in config

**Local files:**
- Read directly from the file system
- For PDFs: extract text content
- Set `ingestion_tool: local` in frontmatter

### Step 3: Clean and Format

- Convert to clean markdown
- Remove navigation, ads, cookie banners, sidebar content, boilerplate
- Preserve: headings, code blocks, lists, tables, images, blockquotes
- For images found in the content:
  - Download each image to `raw/<category>/images/` with a descriptive filename
  - Update image references in the markdown to point to the local path

### Step 4: Write to raw/

Map `source_type` to directory:

| source_type | directory |
|---|---|
| blog | `raw/blogs/` |
| paper | `raw/papers/` |
| tweet | `raw/people/` |
| substack | `raw/substacks/` |
| github | `raw/github/` |
| podcast | `raw/media/` |
| video | `raw/media/` |

**Filename:** kebab-case derived from title, max 60 characters, `.md` extension.
Example: "Anthropic's Model Context Protocol" → `anthropics-model-context-protocol.md`

### Step 5: Write Frontmatter

Every raw file must have this frontmatter:

```yaml
---
title: "Source Title"
source_url: "https://..."
source_type: blog
source_date: 2026-04-01
author: "Author Name"
ingested: 2026-04-04
ingestion_tool: tavily
tags: ["domain-1", "domain-2"]
---
```

Field rules:
- `title`: from the source's heading or title
- `source_url`: the original URL (or "local" for file imports)
- `source_type`: as determined in Step 1
- `source_date`: extract from the source if possible. If not found, use today's date and add a note in the article body that the date is approximate.
- `author`: extract from byline or metadata. Use "Unknown" if not found.
- `ingested`: today's date
- `ingestion_tool`: which tool was used (tavily, firecrawl, or local)
- `tags`: match to domains from `wiki.config.yaml` based on content topic

### Step 6: Proceed to Compile

After successful ingestion, immediately run the compile operation on the newly ingested source(s). Read `.claude/skills/compile/SKILL.md` and follow its instructions.

## Important Rules

- `raw/` is append-only — never modify existing files
- One raw file per source URL
- Always check `_index.md` first to avoid ingesting the same source twice
- If a source has already been ingested, inform the user and skip
