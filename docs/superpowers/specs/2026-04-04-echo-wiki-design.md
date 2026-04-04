# Echo Wiki — Generic LLM-Maintained Knowledge Base

**Date:** 2026-04-04
**Status:** Approved
**Author:** Shubh + Claude
**License:** MIT

## Overview

A generic, domain-agnostic, LLM-maintained knowledge base system. Raw sources (blogs, papers, tweets, Substacks, GitHub repos) are ingested, compiled into a structured markdown wiki, and browsed in Obsidian. The LLM writes and maintains all wiki content — the user never edits `compiled/` directly.

Users clone the repo, edit `wiki.config.yaml` to define their domain (AI research, finance, healthcare, marketing, etc.), and start ingesting sources. The same system works across any knowledge domain.

## Goals

- Build a reusable, open-source knowledge base system for any domain
- Single configuration file (`wiki.config.yaml`) to customize for a specific use case
- Support diverse source types: blog posts, papers, tweets/posts, Substacks, GitHub repos, podcasts, videos
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
- Custom compiled categories (fixed: concepts, people, tools, sources)

---

## Architecture

### Directory Structure

```
echo-wiki/
├── LICENSE                       # MIT License
├── .env.example                  # Template: required env vars with placeholder values
├── .env                          # User's actual keys (git-ignored)
├── _meta/
│   ├── wiki.config.yaml          # Single customization point (name, domains, defaults)
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
│   │   └── images/
│   └── media/                    # Transcripts from videos/podcasts
│       └── images/
├── compiled/                     # LLM-maintained wiki (user browses, LLM writes)
│   ├── _index.md                 # Master index with summaries of all articles
│   ├── _backlinks.md             # Cross-reference map
│   ├── concepts/                 # Core ideas and theories in your domain
│   ├── people/                   # Key figures, researchers, authors
│   ├── tools/                    # Software, platforms, frameworks, products
│   └── sources/                  # Summary of each raw source document
├── output/                       # Query results, reports
│   └── reports/                  # Lint reports, query answers
├── hooks/
│   ├── pre-commit.sh             # Structural validation (no LLM required)
│   └── token-count.sh            # Count total tokens across wiki (on-demand or hook)
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
├── .gitignore                    # Ignores .env, .obsidian/workspace*, etc.
├── README.md                     # Setup guide, usage, architecture overview
├── CLAUDE.md                     # Claude Code agent instructions
├── AGENTS.md                     # Codex CLI agent instructions (future)
├── GEMINI.md                     # Gemini CLI agent instructions (future)
└── .git/
```

### Configuration (`wiki.config.yaml`)

The single file users edit to customize their wiki instance:

```yaml
# _meta/wiki.config.yaml

wiki:
  name: "My Wiki"                    # Display name for the wiki instance
  description: "Knowledge base for..." # One-line purpose description

domains:                              # Knowledge domains (used in frontmatter tags)
  - name: "example"
    label: "Example Domain"
    decay_rate_override: fast          # Optional: omit field to use global default

source_types:                         # Allowed source_type values
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
    enabled: false                    # Requires FIRECRAWL_API_KEY env var
    api_key: "${FIRECRAWL_API_KEY}"

defaults:
  decay_rate: medium                  # Default for new articles
  confidence: medium                  # Default for new articles

schema_version: 1
```

**Example instances:**

| Use Case | `wiki.name` | `domains` |
|---|---|---|
| AI Research | "Echo Theory Labs Wiki" | llm, agents, harness engineering, evals, mcp, fine-tuning |
| Finance | "Alpha Wiki" | equities, macro, crypto, options |
| Healthcare | "MedBase" | clinical-trials, genomics, devices |
| Marketing | "Growth Wiki" | seo, content, paid-ads, analytics |

### Key Conventions

- All articles in `compiled/` use `[[wikilinks]]` for cross-references
- Display aliases: `[[concepts/agent-architecture|Agent Architecture]]`
- Every file in `compiled/` has YAML frontmatter with required fields
- `raw/` is append-only — sources go in, never get modified
- `compiled/` is LLM-only — user reads in Obsidian, never edits manually
- Images stored alongside their source: `raw/<category>/images/`
- Domain-specific values (tags, domains) are driven by `wiki.config.yaml`, not hardcoded
- Filenames are kebab-case, derived from the article title, max 60 characters (e.g., `model-context-protocol.md`)

### Source Type → Directory Mapping

| `source_type` | `raw/` directory | Notes |
|---|---|---|
| `blog` | `raw/blogs/` | |
| `paper` | `raw/papers/` | |
| `tweet` | `raw/people/` | Tweets are attributed to people |
| `substack` | `raw/substacks/` | |
| `github` | `raw/github/` | |
| `podcast` | `raw/media/` | Stored as transcript |
| `video` | `raw/media/` | Stored as transcript |

All `raw/` subdirectories have an `images/` subfolder for locally-downloaded media.

### Compiled Type → Directory Mapping

| Frontmatter `type` | `compiled/` directory |
|---|---|
| `concept` | `compiled/concepts/` |
| `person` | `compiled/people/` |
| `tool` | `compiled/tools/` |
| `source-summary` | `compiled/sources/` |

### Environment Variables (`.env`)

`.env.example` ships with the repo as a template. Users copy to `.env` and fill in their keys.

```bash
# .env.example

# Ingestion tools
FIRECRAWL_API_KEY=              # Required if firecrawl is enabled in wiki.config.yaml

# LLM API keys (for non-CLI usage, e.g., API-based agents)
ANTHROPIC_API_KEY=              # Claude API
OPENAI_API_KEY=                 # OpenAI API (optional)
GOOGLE_API_KEY=                 # Gemini API (optional)
```

- `.env` is listed in `.gitignore` — never committed
- `.env.example` is committed — shows required vars with empty values
- `wiki.config.yaml` references env vars as `${VAR_NAME}` — resolved at runtime by skills/hooks

### Progressive Context Loading

The wiki can grow large. LLM agents should NOT load the entire wiki into context at once. Instead, use progressive disclosure — load only what's needed for the current operation.

**Loading hierarchy (smallest → largest):**

| Level | What's loaded | When |
|---|---|---|
| **L0: Index only** | `compiled/_index.md` | Default starting point for any operation |
| **L1: + Backlinks** | `compiled/_backlinks.md` | When resolving cross-references |
| **L2: + Target articles** | Specific `compiled/<type>/<article>.md` | When compiling, querying, or linting a specific topic |
| **L3: + Raw sources** | Specific `raw/<category>/<source>.md` | Only during ingest → compile pipeline |

**Rules for skills:**
- `/ingest`: Loads L0 (check for duplicates) → L3 (the new raw source only)
- `/compile`: Loads L0 → L2 (existing articles that may need merging) → L3 (raw source being compiled)
- `/lint`: Loads L0 + L1 → L2 (iterates articles in small batches; contradiction detection may load related article pairs)
- Query: Loads L0 → follows links to L2 as needed

**Why this matters:** A wiki with 200+ articles could exceed 500K tokens if loaded entirely. Progressive loading keeps each operation well within context limits regardless of wiki size.

### Token Count Script (`hooks/token-count.sh`)

Estimates total wiki size in tokens to help users track context window growth.

**Usage:**
```bash
# On-demand
./hooks/token-count.sh

# As post-commit hook (informational, never blocks)
# Symlinked to .git/hooks/post-commit
```

**Behavior:**
- Counts all words across `raw/` and `compiled/` markdown files
- Applies `words × 1.3` as token estimate (standard approximation for English text)
- Outputs breakdown by directory and total
- Appends result to `output/reports/token-count.log` with timestamp (git-ignored to avoid dirty state after each commit)

**Sample output:**
```
[2026-04-04] Wiki Token Estimate
  raw/        12,400 words  ~  16,120 tokens
  compiled/    8,200 words  ~  10,660 tokens
  TOTAL       20,600 words  ~  26,780 tokens

  Context usage: ~2.7% of 1M window
```

- Runs in <1 second (just `wc -w`), no LLM required
- As a post-commit hook, it's informational only — prints after commit, never blocks

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
tags: ["domain-tag-1", "domain-tag-2"]     # Values driven by wiki.config.yaml domains
sources: ["[[raw/blogs/example-source.md]]"]
related: ["[[concepts/related-concept]]"]
summary: "One-line summary for index files"
---
```

### Type-Specific Fields

| Type | Extra Fields |
|---|---|
| `concept` | `domain: ["domain-1", "domain-2"]`, `prerequisites: ["[[concepts/prerequisite]]"]` |
| `person` | `role: "Title/Role"`, `affiliations: ["Org"]`, `follows: ["url"]` |
| `tool` | `category: "framework \| platform \| service \| product"`, `repo: "github.com/..."`, `maintained: true` |
| `source-summary` | `source_url: "https://..."`, `source_type: blog \| paper \| tweet \| substack \| github \| podcast \| video`, `author: "..."`, `source_date: 2026-04-01` |

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
tags: ["domain-tag-1", "domain-tag-2"]
---
```

### Decay Rate Rules

- `fast` — rapidly changing information: model releases, pricing, market data, tool versions (verify monthly)
- `medium` — moderately evolving: architectural patterns, frameworks, best practices, regulations (verify quarterly)
- `slow` — stable foundations: core theory, math, established principles, historical facts (verify yearly)

Domains can override the default decay rate in `wiki.config.yaml` (e.g., a crypto domain might default to `fast`).

### Confidence Level Rules

- `high` — well-sourced from multiple references, or from authoritative primary sources
- `medium` — single source, or well-known but not independently verified in the wiki
- `speculative` — inferred, opinion-based, from unverified sources, or emerging/unconfirmed claims

---

## Core Operations

### 1. Ingest (`/ingest`)

**Input:** URL, file path, or list of either
**Output:** Clean markdown file(s) in `raw/` with valid frontmatter

**Steps:**
1. Detect source type from URL/file (blog, paper, substack, github, tweet). For podcast/video, user must specify `source_type` explicitly since URL detection is unreliable for media.
2. Fetch content via Tavily extract or Firecrawl
3. Download images locally to `raw/<category>/images/`
4. Write clean markdown to `raw/<category>/` with valid frontmatter (source_url, source_date, author, source_type)
5. Trigger `/compile` on the new source(s)

**Ingestion tools:**
- Tavily extract (`mcp__tavily__tavily_extract`) — takes `urls: string[]` parameter. Already available via MCP.
- Firecrawl API (`POST https://api.firecrawl.dev/v1/scrape`) — REST API, requires API key in `.env`

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

**`_index.md` format:**
```markdown
# Wiki Index

## Concepts
- [[concepts/mcp-protocol|MCP Protocol]] — Open protocol for connecting LLMs to external tools
- [[concepts/agent-architecture|Agent Architecture]] — Patterns for building autonomous AI agents

## People
- [[people/andrej-karpathy|Andrej Karpathy]] — AI researcher, former Tesla/OpenAI

## Tools
- [[tools/claude-code|Claude Code]] — Anthropic's CLI agent for software engineering

## Sources
- [[sources/anthropic-mcp-blog|Anthropic MCP Blog]] — Official MCP announcement (2024-11)
```

**`_backlinks.md` format:**
```markdown
# Backlinks

## [[concepts/mcp-protocol]]
Linked from:
- [[tools/claude-code]]
- [[people/boris-cherny]]
- [[sources/anthropic-mcp-blog]]

## [[people/andrej-karpathy]]
Linked from:
- [[concepts/transformer-architecture]]
- [[sources/karpathy-llm-knowledge-bases]]
```

---

## Validation

### Pre-commit Hook (structural, no LLM)

Shell script at `hooks/pre-commit.sh`, symlinked to `.git/hooks/pre-commit`.

**Scope:** All files matching `compiled/**/*.md` (recursive), **excluding** `_index.md` and `_backlinks.md` (structural files with their own format).

| Check | Method | Blocks commit? |
|---|---|---|
| Frontmatter exists on all `compiled/**/*.md` | Regex for `---` header | Yes |
| Required fields present (`title`, `type`, `created`, `summary`, `sources`) | YAML parse | Yes |
| `type` is valid enum (`concept`, `person`, `tool`, `source-summary`) | String match | Yes |
| Broken `[[wikilinks]]` (across all compiled files including _index.md) | Extract `[[...]]`, check target exists | Yes |
| Files in `compiled/` have at least one `sources:` entry | Frontmatter check | Yes |

**Escape hatch:** `git commit --no-verify` for WIP commits.

### Post-commit: Token Count (informational)

`hooks/token-count.sh` optionally symlinked to `.git/hooks/post-commit`. Prints token estimate after every commit. Never blocks. See "Token Count Script" section above.

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

**Naming constraint:** The `name` field in SKILL.md frontmatter **must match the parent directory name** exactly (i.e., `ingest`, `compile`, `lint`). Names must be lowercase alphanumeric + hyphens only. This is required by the Agent Skills specification.

Skills are the **primary execution path**. Prompt files in `_meta/prompts/` exist for all 5 operations but only ingest, compile, and lint have corresponding skills. Query and index-update prompts serve as reference documentation and fallback for agents without skill support.

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

Configured in `_meta/wiki.config.yaml` under `ingestion:`. Enable/disable per tool.

| Tool | Source Types | Setup |
|---|---|---|
| **Tavily extract** | Blog posts, articles, general web content | Already available via MCP |
| **Firecrawl** | Blog posts with images, Substacks, complex pages | Set `FIRECRAWL_API_KEY` env var, enable in config |

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

## Open Source & Reusability

**License:** MIT

**Getting started (for new users):**
1. Clone the repo
2. `cp .env.example .env` — fill in API keys
3. Edit `_meta/wiki.config.yaml` — set wiki name, description, and domains
4. Install hooks: `ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit && ln -sf ../../hooks/token-count.sh .git/hooks/post-commit`
5. Open the folder as an Obsidian vault
6. Run `/ingest <url>` to add your first source

**What's generic:**
- Directory structure, frontmatter schema, skills, hooks, Obsidian config
- All 4 compiled categories (concepts, people, tools, sources) work across any domain

**What users customize:**
- `wiki.config.yaml` — name, description, domains, ingestion tools, defaults
- `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — thin wrappers that reference config (templates provided)

**Design principle:** No domain-specific logic exists anywhere in the system. The LLM adapts its compilation and writing to the domain based on the config and the content of the raw sources themselves.

---

## Example Configurations (Validation Reference)

These two full configs demonstrate how the same system maps to completely different domains. Use during implementation testing to validate domain-agnosticism.

### Example A: Applied AI & Agents

```yaml
# _meta/wiki.config.yaml
wiki:
  name: "Echo Theory Labs Wiki"
  description: "Applied AI R&D knowledge base — frontier models, agents, harness engineering, evals"

domains:
  - name: "llm"
    label: "Large Language Models"
    decay_rate_override: fast
  - name: "agents"
    label: "AI Agents & Orchestration"
    decay_rate_override: fast
  - name: "harness-engineering"
    label: "Harness Engineering"
  - name: "evals"
    label: "Evaluations & Benchmarks"
    decay_rate_override: fast
  - name: "mcp"
    label: "Model Context Protocol"
  - name: "fine-tuning"
    label: "Fine-Tuning & Training"

source_types:
  - blog
  - paper
  - tweet
  - substack
  - github
  - podcast
  - video

ingestion:
  tavily:
    enabled: true
  firecrawl:
    enabled: true
    api_key: "${FIRECRAWL_API_KEY}"

defaults:
  decay_rate: fast          # AI moves fast — default to monthly verification
  confidence: medium

schema_version: 1
```

**How the 4 categories map:**

| Category | Examples in this domain |
|---|---|
| `concepts/` | transformer-architecture.md, chain-of-thought.md, rag-patterns.md, mcp-protocol.md |
| `people/` | andrej-karpathy.md, simon-willison.md, boris-cherny.md |
| `tools/` | claude-code.md, langgraph.md, cursor.md, openai-codex.md |
| `sources/` | anthropic-agent-architecture-blog.md, karpathy-llm-knowledge-bases.md |

**Sample compiled article (`compiled/concepts/mcp-protocol.md`):**
```yaml
---
title: "Model Context Protocol (MCP)"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: ["mcp", "agents", "llm"]
domain: ["mcp", "agents"]
prerequisites: ["[[concepts/tool-use]]", "[[concepts/agent-architecture]]"]
sources: ["[[raw/blogs/anthropic-mcp-announcement.md]]"]
related: ["[[tools/claude-code]]", "[[people/boris-cherny]]"]
summary: "Open protocol for connecting LLMs to external tools and data sources"
---
```

### Example B: Retail Investment Analysis

```yaml
# _meta/wiki.config.yaml
wiki:
  name: "Alpha Wiki"
  description: "Retail investment research — equities, macro trends, portfolio strategies"

domains:
  - name: "equities"
    label: "Equities & Stock Analysis"
    decay_rate_override: fast
  - name: "macro"
    label: "Macroeconomics"
  - name: "etfs"
    label: "ETFs & Index Funds"
  - name: "options"
    label: "Options & Derivatives"
    decay_rate_override: fast
  - name: "portfolio"
    label: "Portfolio Strategy"
  - name: "crypto"
    label: "Cryptocurrency"
    decay_rate_override: fast

source_types:
  - blog
  - paper
  - substack
  - tweet
  - podcast
  - video

ingestion:
  tavily:
    enabled: true
  firecrawl:
    enabled: true
    api_key: "${FIRECRAWL_API_KEY}"

defaults:
  decay_rate: medium        # Mix of fast-moving data and stable theory
  confidence: medium

schema_version: 1
```

**How the 4 categories map:**

| Category | Examples in this domain |
|---|---|
| `concepts/` | dollar-cost-averaging.md, modern-portfolio-theory.md, yield-curve-inversion.md |
| `people/` | warren-buffett.md, cathie-wood.md, ray-dalio.md |
| `tools/` | bloomberg-terminal.md, tradingview.md, interactive-brokers.md |
| `sources/` | dalio-changing-world-order-substack.md, buffett-2026-shareholder-letter.md |

**Sample compiled article (`compiled/concepts/dollar-cost-averaging.md`):**
```yaml
---
title: "Dollar-Cost Averaging (DCA)"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: slow
confidence: high
tags: ["portfolio", "equities", "etfs"]
domain: ["portfolio", "equities"]
prerequisites: ["[[concepts/modern-portfolio-theory]]"]
sources: ["[[raw/blogs/vanguard-dca-analysis.md]]"]
related: ["[[concepts/lump-sum-investing]]", "[[tools/interactive-brokers]]", "[[people/warren-buffett]]"]
summary: "Strategy of investing fixed amounts at regular intervals to reduce timing risk"
---
```

### What These Examples Validate

| Validation Point | What to check |
|---|---|
| **Config-driven domains** | Tags, domain fields in frontmatter come from config, not hardcoded |
| **Category universality** | concepts/people/tools/sources map naturally to both AI and finance |
| **Decay rate flexibility** | AI defaults to `fast`, finance uses `medium` with per-domain overrides |
| **Wikilink structure** | Cross-references work the same regardless of domain content |
| **Compilation behavior** | LLM extracts domain-appropriate entities without domain-specific code |

---

## README.md (Implementation Reference)

The following is the complete README.md content to be written during scaffold implementation:

````markdown
# Echo Wiki

A generic, LLM-maintained knowledge base system. Ingest sources, compile a structured wiki, browse in Obsidian. Works with any domain — AI research, finance, healthcare, marketing, or anything else.

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
    compiled/ <-- ready for Obsidian
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
├── .skills/                   # Agent Skills (ingest, compile, lint)
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
````

---

## Future Phases

- **Phase 2:** Marp slides, matplotlib visualizations in output/
- **Phase 3:** GraphRAG integration (compiled/ as input, entity graph generation)
- **Phase 4:** Custom compiled categories (user-defined beyond the 4 defaults)
- **Phase 5:** Custom search engine over wiki
- **Phase 6:** Synthetic data generation + fine-tuning
