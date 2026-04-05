---
layout: home
hero:
  name: Echo Wiki
  text: LLM-Maintained Knowledge Base
  tagline: Ingest sources. Compile a structured wiki. Browse in Obsidian. Works with any domain.
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/echotheorylabsai/echo-wiki

features:
  - title: Domain-Agnostic
    details: One config file customizes everything. Works for AI research, finance, healthcare, marketing, or any knowledge domain.
  - title: LLM-Powered Pipeline
    details: Agent Skills handle the full pipeline — ingest sources, compile wiki articles, rebuild after source removal, and lint for quality. You provide sources, the LLM writes the wiki.
  - title: Obsidian-Native
    details: Browse your wiki in Obsidian with graph view, backlinks, and wikilink navigation. Pre-configured vault with color-coded node types.
  - title: Provider-Agnostic
    details: Built on the Agent Skills open standard. Works with Claude Code, Codex CLI, Gemini CLI, or any compatible agent.
---

## How It Works

```
  URLs / Files / PDFs
         |
         v
  +--------------+
  |   /ingest    |  Fetch + clean source → raw/
  +--------------+
         |
         v
  +--------------+
  |   /compile   |  Extract entities, build articles → compiled/
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

> `/rebuild` is only needed after manually deleting raw source files. Normal operation uses `/ingest` and `/compile`.

The LLM writes all wiki content. You provide sources, the LLM maintains `compiled/`. You never edit `compiled/` directly — just read it in Obsidian.
