# Echo Wiki — LLM Knowledge Base for Echo Theory Labs

**Date:** 2026-04-04
**Status:** Approved
**Author:** Shubh + Claude

## Overview

A personal, LLM-maintained knowledge base for Applied AI research. Raw sources (blogs, papers, tweets, Substacks, GitHub repos) are ingested, compiled into a structured markdown wiki, and browsed in Obsidian. The LLM writes and maintains all wiki content — the user never edits `compiled/` directly.

## Goals

- Build a long-term knowledge base for Echo Theory Labs' Applied AI R&D
- Support diverse sources: frontier lab blogs, key figure posts/tweets, Substacks, papers, GitHub repos
- Provider-agnostic: works with Claude Code, Codex, Gemini CLI, or any Agent Skills-compatible agent
- Obsidian as the view layer (graph view, backlinks, browsing)
- Consistency checks before content is committed
- GraphRAG-ready structure (future phase)

## Non-Goals (v1)

- GraphRAG integration
- Marp slides / visualization output
- Custom search engine
- Firecrawl MCP server (use API directly via skills)
- Custom Obsidian plugins or themes
- Real-time collaboration

---

## Architecture

### Directory Structure

```
echo-wiki/
├── _meta/
│   ├── wiki.config.yaml          # Wiki settings (schema version, domains, decay rates)
│   ├── prompts/
│   │   ├── ingest.md             # Reference: ingest operation instructions
│   │   ├── compile.md            # Reference: compile operation instructions
│   │   ├── lint.md               # Reference: lint operation instructions
│   │   ├── query.md              # Reference: query operation instructions
│   │   └── index-update.md       # Reference: index update instructions
│   └── schemas/
│       └── frontmatter.yaml      # Frontmatter schema definition
├── raw/                          # Source documents (append-only, never modified after ingest)
│   ├── blogs/
│   │   └── images/
│   ├── papers/
│   │   └── images/
│   ├── people/                   # Posts, tweets, opinions from key figures
│   │   └── images/
│   ├── substacks/
│   │   └── images/
│   ├── github/
│   └── media/                    # Transcripts from videos/podcasts
├── compiled/                     # LLM-maintained wiki (user browses, LLM writes)
│   ├── _index.md                 # Master index with summaries of all articles
│   ├── _backlinks.md             # Cross-reference map
│   ├── concepts/                 # e.g., "mcp-protocol.md", "agent-architecture.md"
│   ├── people/                   # e.g., "andrej-karpathy.md", "simon-willison.md"
│   ├── tools/                    # e.g., "langgraph.md", "claude-code.md"
│   └── sources/                  # Summary of each raw source document
├── output/                       # Query results, reports
│   └── reports/                  # Lint reports, query answers
├── hooks/
│   └── pre-commit.sh             # Structural validation (no LLM required)
├── .skills/
│   ├── ingest/
│   │   └── SKILL.md              # Ingest skill (Agent Skills spec)
│   ├── compile/
│   │   └── SKILL.md              # Compile skill (Agent Skills spec)
│   └── lint/
│       └── SKILL.md              # Lint skill (Agent Skills spec)
├── .obsidian/                    # Obsidian vault config
│   ├── app.json
│   ├── appearance.json
│   └── graph.json
├── CLAUDE.md                     # Claude Code agent instructions
├── AGENTS.md                     # Codex CLI agent instructions (future)
├── GEMINI.md                     # Gemini CLI agent instructions (future)
└── .git/
```

### Key Conventions

- All articles in `compiled/` use `[[wikilinks]]` for cross-references
- Display aliases: `[[concepts/agent-architecture|Agent Architecture]]`
- Every file in `compiled/` has YAML frontmatter with required fields
- `raw/` is append-only — sources go in, never get modified
- `compiled/` is LLM-only — user reads in Obsidian, never edits manually
- Images stored alongside their source: `raw/<category>/images/`

---

## Frontmatter Schema

### Shared Fields (all types in `compiled/`)

```yaml
---
title: "Article Title"
type: concept | person | tool | source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast | medium | slow
confidence: high | medium | speculative
tags: ["agents", "mcp", "anthropic"]
sources: ["[[raw/blogs/anthropic-mcp.md]]"]
related: ["[[concepts/agent-architecture]]"]
summary: "One-line summary for index files"
---
```

### Type-Specific Fields

| Type | Extra Fields |
|---|---|
| `concept` | `domain: ["llm", "agents"]`, `prerequisites: ["[[concepts/transformers]]"]` |
| `person` | `role: "AI Researcher"`, `affiliations: ["OpenAI"]`, `follows: ["x.com/karpathy"]` |
| `tool` | `category: "framework"`, `repo: "github.com/..."`, `maintained: true` |
| `source-summary` | `source_url: "https://..."`, `source_type: blog \| paper \| tweet \| substack \| github`, `author: "..."`, `source_date: 2026-04-01` |

### Raw Source Frontmatter (files in `raw/`)

```yaml
---
title: "Source Title"
source_url: "https://..."
source_type: blog | paper | tweet | substack | github | podcast | video
source_date: 2026-04-01
author: "Author Name"
ingested: 2026-04-04
ingestion_tool: tavily | firecrawl | local
tags: ["agents", "mcp"]
---
```

### Decay Rate Rules

- `fast` — AI models, tools, benchmarks, pricing (verify monthly)
- `medium` — architectural patterns, frameworks, best practices (verify quarterly)
- `slow` — foundational concepts, math, theory (verify yearly)

---

## Core Operations

### 1. Ingest (`/ingest`)

**Input:** URL, file path, or list of either
**Output:** Clean markdown file(s) in `raw/` with valid frontmatter

**Steps:**
1. Detect source type (blog, paper, substack, github, tweet)
2. Fetch content via Tavily extract or Firecrawl
3. Download images locally to `raw/<category>/images/`
4. Write clean markdown to `raw/<category>/` with valid frontmatter (source_url, source_date, author, source_type)
5. Trigger `/compile` on the new source(s)

**Ingestion tools:**
- Tavily extract (`mcp__tavily__tavily_extract`) — already available via MCP
- Firecrawl API — requires API key, configured in `_meta/wiki.config.yaml`

### 2. Compile (`/compile`)

**Input:** Path to raw source(s), or "all" for full recompile
**Output:** New/updated articles in `compiled/`, updated index and backlinks

**Steps:**
1. Read the raw source(s)
2. For each source: generate `source-summary` in `compiled/sources/`
3. Extract concepts, people, tools from the source content
4. For each extracted entity:
   - Check if an article already exists in `compiled/`
   - If yes: **merge** new information into existing article (never overwrite)
   - If no: create new article with full frontmatter
5. Add `[[wikilinks]]` between all related articles
6. Update `_index.md` (master index with one-line summaries, sorted by domain/type)
7. Update `_backlinks.md` (which articles link to which)

**Merge behavior:** When a concept/person/tool already has an article, the LLM:
- Adds new information in appropriate sections
- Updates `last_updated` date
- Adds new source to `sources:` list
- Adds new `[[wikilinks]]` to `related:`
- Does NOT remove or overwrite existing content

### 3. Lint (`/lint`)

**Input:** Optional scope (path, domain, or "all")
**Output:** Lint report at `output/reports/lint-<date>.md`

**Checks (semantic, requires LLM):**
1. Validate all frontmatter against schema
2. Check for broken `[[wikilinks]]`
3. Find orphaned articles (no inbound links)
4. Detect contradictory claims across articles
5. Flag stale content past `last_verified` + decay rate threshold
6. Suggest missing concept candidates (topics referenced but not yet having their own article)
7. Detect duplicate concepts under different names

### 4. Query (no skill — ad-hoc)

**Flow:**
1. LLM reads `_index.md` to understand what's available
2. Follows links to relevant articles
3. Synthesizes answer
4. Optionally saves result to `output/reports/` and files insights back into wiki

### 5. Index Update (triggered by Compile, not standalone)

**Flow:**
1. Regenerate `_index.md` (one-line summary per article, grouped by type and domain)
2. Regenerate `_backlinks.md` (for each article, list all articles that link to it)

---

## Validation

### Pre-commit Hook (structural, no LLM)

Shell script at `hooks/pre-commit.sh`, symlinked to `.git/hooks/pre-commit`.

| Check | Method | Blocks commit? |
|---|---|---|
| Frontmatter exists on all `compiled/*.md` | Regex for `---` header | Yes |
| Required fields present (`title`, `type`, `created`, `summary`, `sources`) | YAML parse | Yes |
| `type` is valid enum | String match | Yes |
| Broken `[[wikilinks]]` | Extract `[[...]]`, check target exists | Yes |
| Files in `compiled/` have at least one `sources:` entry | Frontmatter check | Yes |

**Escape hatch:** `git commit --no-verify` for WIP commits.

### Semantic Lint (`/lint` skill)

Run manually on demand. Requires LLM. Produces actionable report.

---

## Skills Architecture

All skills follow the Agent Skills open standard (agentskills.io). Stored in `.skills/` for cross-platform compatibility.

```
.skills/
├── ingest/
│   └── SKILL.md
├── compile/
│   └── SKILL.md
└── lint/
    └── SKILL.md
```

Each `SKILL.md` contains:
- YAML frontmatter: `name`, `description`, and any `allowed-tools`
- Markdown body: step-by-step instructions the agent follows
- References to `_meta/schemas/frontmatter.yaml` for validation

Skills are the **primary execution path**. Prompt files in `_meta/prompts/` serve as reference documentation and fallback for agents without skill support.

---

## Obsidian Integration

Obsidian reads `echo-wiki/` as a vault (File > Open folder as vault).

**Pre-configured settings:**
- `app.json` — wikilinks enabled, attachment folder config, new file location
- `appearance.json` — clean reading defaults
- `graph.json` — color groups by article type (concepts=blue, people=green, tools=orange, sources=gray)

**Recommended plugins (manual install):**
- Graph View (built-in)
- Obsidian Git
- Dataview

---

## Ingestion Tools

| Tool | Source Types | Setup |
|---|---|---|
| **Tavily extract** | Blog posts, articles, general web content | Already available via MCP |
| **Firecrawl** | Blog posts with images, Substacks, complex pages | API key required, configured in `_meta/wiki.config.yaml` |

Firecrawl API key is stored as environment variable `FIRECRAWL_API_KEY`. Referenced in `_meta/wiki.config.yaml` as `${FIRECRAWL_API_KEY}`. Never hardcoded in config files.

---

## Testing & Validation Plan

### Test Sources

| # | Type | Purpose |
|---|---|---|
| 1 | Blog URL with images | Test Tavily/Firecrawl ingestion, image download |
| 2 | Substack article URL | Test newsletter-style content extraction |
| 3 | GitHub repo URL | Test repo/README extraction |
| 4 | Existing .md or .pdf file | Test local file ingestion |

### Test Sequence

| Step | What we test | Success criteria |
|---|---|---|
| T1: Scaffold | Directory structure, git init, hook install, Obsidian opens vault | Obsidian shows empty wiki with correct folder structure |
| T2: Ingest URL | `/ingest` with blog URL | File in `raw/` with valid frontmatter, images saved locally |
| T3: Compile single | `/compile` triggered after ingest | Source summary + concept/people/tool articles in `compiled/`, `_index.md` updated, wikilinks resolve |
| T4: Ingest 3 more | Remaining test sources | All 4 sources in `raw/`, correct categorization |
| T5: Compile all | Full compilation across all sources | Cross-references work, shared concepts merged (not duplicated) |
| T6: Lint | `/lint all` | Report generated, no false positives on clean wiki |
| T7: Break & lint | Manually introduce errors | Pre-commit hook blocks commit; `/lint` catches semantic issues |
| T8: Query | Question spanning multiple sources | Coherent answer using index navigation |
| T9: Obsidian verify | Open vault in Obsidian | Graph shows connections, backlinks work, wikilinks navigate |

### Success Criteria

- Every file in `compiled/` has valid frontmatter
- Every `[[wikilink]]` resolves to a real file
- `_index.md` is accurate and complete
- Obsidian graph shows meaningful connections (not isolated nodes)
- Pre-commit hook catches structural errors
- `/lint` catches semantic issues and produces actionable report

---

## Future Phases

- **Phase 2:** GraphRAG integration (compiled/ as input, entity graph generation)
- **Phase 3:** Marp slides, matplotlib visualizations in output/
- **Phase 4:** Custom search engine over wiki
- **Phase 5:** Synthetic data generation + fine-tuning
