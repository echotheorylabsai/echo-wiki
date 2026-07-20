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
    details: Browse your wiki in Obsidian with graph view, backlinks, and wikilink navigation. Clean vault showing only your knowledge base and workspaces — no backend clutter.
  - title: Provider-Agnostic
    details: Built on the Agent Skills open standard. Works with Claude Code, Codex CLI, Gemini CLI, or any compatible agent.
---

## How It Works

![Echo Wiki — end-to-end flow](/assets/echo-wiki-flow.png)

*The full pipeline: sources → `/ingest` → `raw/` receipts → `/compile` → `wiki/` knowledge → used via Obsidian, `/query` (with workspace write-back), and agents — with the deterministic script rails underneath.*

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
  |   /compile   |  Extract entities, build articles → wiki/
  +--------------+
         |
         v
  +--------------+
  |  /rebuild    |  Stage + validate a replacement (after deletion)
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

> `/rebuild` is only needed after manually deleting raw source files. Normal operation uses `/ingest` and `/compile`.

The LLM writes all wiki content. You provide sources, the LLM maintains `wiki/`. You never edit KB articles directly — just read them in Obsidian. Create your own notes in `wiki/workspaces/`.
