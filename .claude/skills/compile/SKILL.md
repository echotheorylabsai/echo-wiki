---
name: compile
description: Compile raw sources into structured wiki articles with cross-references
---

# Compile

Transform raw source documents into structured wiki articles in `wiki/`. Extract concepts, people, and tools. Merge into existing articles or create new ones. Update index and backlinks.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- Path to one or more raw source files, OR `all` for full recompile
- Examples: `/compile raw/blogs/some-article.md`, `/compile all`

## Context Loading

1. Read `_meta/wiki.config.yaml` — domain context, defaults
2. Read `_meta/schemas/frontmatter.yaml` — required fields and enums
3. Read `wiki/_index.md` — existing wiki state (L0)
4. Read target raw source(s) (L3)
5. After identifying entities, read existing compiled articles that need merging (L2)

## Steps

### Step 1: Read and Analyze Raw Source

Read the raw source file(s). For each source, identify:
- **Main topic/thesis** — what is this source about?
- **Concepts** — ideas, theories, patterns, methodologies, principles
- **People** — researchers, authors, founders, key figures mentioned
- **Tools** — software, platforms, frameworks, products, services
- **Key claims** — factual assertions, data points, quotes
- **Relationships** — how entities relate to each other

### Step 2: Create Source Summary

For each raw source, create a source-summary article.

**File path:** `wiki/sources/<kebab-case-title>.md`

```yaml
---
title: "<Source Title>"
type: source-summary
created: <today YYYY-MM-DD>
last_updated: <today>
last_verified: <today>
decay_rate: <assess from content, or use config default>
confidence: <assess from source quality>
tags: [<matching domains from wiki.config.yaml>]
source_url: "<original URL from raw file frontmatter>"
source_type: <from raw file frontmatter>
author: "<from raw file frontmatter>"
source_date: <from raw file frontmatter>
sources: ["raw/<category>/<filename>.md"]
related: []
summary: "<One-line summary of the source>"
---

## Key Points

- <Main takeaway 1>
- <Main takeaway 2>
- <Main takeaway 3>

## Details

<Organized summary of the source content. Group by topic. Include specific details, data points, and notable quotes with attribution.>
```

### Step 3: Extract and Classify Entities

From the source content, build a list of entities:

| Entity Type | What to look for | Compiled type |
|---|---|---|
| Concepts | Ideas, theories, patterns, methodologies, architectural patterns, principles | `concept` |
| People | Researchers, authors, founders, key figures, speakers | `person` |
| Tools | Software, platforms, frameworks, products, services, APIs, libraries | `tool` |

For each entity, determine:
1. Does an article already exist? (Check `_index.md` for exact AND semantic matches — "MCP" = "Model Context Protocol")
2. What new information does this source contribute?
3. How does this entity relate to others from this source?

**Important:** Prefer merging over creating duplicates. If unsure whether an entity matches an existing article, read the existing article to decide.

### Step 4: Create or Merge Articles

**If article does NOT exist** — create new:

For **concepts** (`wiki/concepts/<name>.md`):
```yaml
---
title: "<Concept Name>"
type: concept
created: <today>
last_updated: <today>
last_verified: <today>
decay_rate: <from config default or assessed from content volatility>
confidence: <from source quality: high|medium|speculative>
tags: [<matching domains from config>]
domain: [<primary domains>]
prerequisites: [<wikilinks to prerequisite concepts, if any>]
sources: ["raw/<category>/<source-file>.md"]
related: [<wikilinks to related articles>]
summary: "<One-line description>"
---

<Article content. Organize into clear sections with ## headings.>
<Use [[wikilinks]] to reference related articles.>
<Include specific details, not just generic descriptions.>
```

For **people** (`wiki/people/<name>.md`):
```yaml
---
title: "<Full Name>"
type: person
created: <today>
last_updated: <today>
last_verified: <today>
decay_rate: <medium is typical for people>
confidence: <from source quality>
tags: [<matching domains>]
role: "<Title or primary role>"
affiliations: ["<Organization>"]
follows: ["<URL to follow their work>"]
sources: ["raw/<category>/<source-file>.md"]
related: [<wikilinks to related articles>]
summary: "<One-line description of who they are>"
---

<Article content about the person's work, contributions, and views.>
```

For **tools** (`wiki/tools/<name>.md`):
```yaml
---
title: "<Tool Name>"
type: tool
created: <today>
last_updated: <today>
last_verified: <today>
decay_rate: <fast for actively developed tools>
confidence: <from source quality>
tags: [<matching domains>]
category: "<framework|platform|service|product>"
repo: "<github URL if applicable>"
maintained: true
sources: ["raw/<category>/<source-file>.md"]
related: [<wikilinks to related articles>]
summary: "<One-line description>"
---

<Article content about what the tool does, key features, use cases.>
```

**If article ALREADY exists** — merge:

1. Read the existing article fully
2. Add new information in the appropriate sections — do NOT duplicate existing content
3. Update `last_updated` to today's date
4. Append the new raw file path (plain string, not wikilink) to the `sources:` array
5. Add any new `related:` wikilinks
6. Add any new `tags:` that apply
7. **NEVER remove, overwrite, or contradict existing content.** If the new source contradicts existing content, note both views with attribution.

### Step 5: Add Wikilinks

In every article body, add wikilinks to related articles:
- Format: `[[<type>/<filename>|Display Name]]`
- Examples:
  - `[[concepts/transformer-architecture|Transformer Architecture]]`
  - `[[people/andrej-karpathy|Andrej Karpathy]]`
  - `[[tools/claude-code|Claude Code]]`

Rules:
- Only link to articles that exist or are being created in this compile run
- Use display aliases for readability
- Link on first mention in each article, not every occurrence
- Also populate the `related:` frontmatter field with these links

### Step 6: Update Index and Backlinks

**Regenerate `wiki/_index.md`** completely:

```markdown
# Wiki Index

## Concepts
- [[concepts/<name>|<Title>]] — <summary from frontmatter>

## People
- [[people/<name>|<Title>]] — <summary from frontmatter>

## Tools
- [[tools/<name>|<Title>]] — <summary from frontmatter>

## Sources
- [[sources/<name>|<Title>]] — <summary from frontmatter>
```

- Sort entries alphabetically within each section
- One line per article: wikilink + summary

**Important:** The index must include ALL content in `wiki/`, not just KB articles. Scan `wiki/workspaces/` for workspace files and include them under a `## Workspaces` section, grouped by workspace name. For workspace files without a `summary` field, use just the title.

**Regenerate `wiki/_backlinks.md`** completely:

```markdown
# Backlinks

## [[<type>/<name>]]
Linked from:
- [[<type>/<article>]]
- [[<type>/<article>]]
```

- For each article in `wiki/`, scan ALL other wiki files for wikilinks pointing to it
- List every article that links to the target
- Sort sections alphabetically

**Important:** Backlinks must include cross-zone references. If a workspace file links to a KB article, that link appears in the KB article's backlinks entry.

## Filename Convention

- Kebab-case, derived from the article title
- Max 60 characters (truncate if necessary)
- `.md` extension
- Examples: `model-context-protocol.md`, `andrej-karpathy.md`, `claude-code.md`

## Important Rules

- **NEVER create duplicate articles** for the same entity. Always check _index.md first.
- **ALWAYS merge** into existing articles when they exist.
- **ALWAYS include complete frontmatter** on every file — no optional fields skipped.
- **ALWAYS add at least one source** to every compiled article.
- **Use wikilinks** for all cross-references in body text and `related:` frontmatter. The `sources:` field uses plain string paths (not wikilinks).
- **Tags must come from** `wiki.config.yaml` domains list.
