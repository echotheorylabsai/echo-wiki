---
title: "How to Build a Custom Agent Framework with PI"
type: source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [agents, harness-engineering]
source_url: "https://nader.substack.com/p/how-to-build-a-custom-agent-framework"
source_type: substack
author: "Nader Dabit"
source_date: 2026-02-18
sources: ["[[raw/substacks/how-to-build-custom-agent-framework-pi.md]]"]
related: ["[[tools/pi-framework|PI Framework]]", "[[tools/openclaw|OpenClaw]]", "[[people/nader-dabit|Nader Dabit]]", "[[people/mario-zechner|Mario Zechner]]", "[[concepts/agent-harness|Agent Harness]]", "[[concepts/harness-engineering|Harness Engineering]]"]
summary: "Tutorial walking through PI's layered TypeScript toolkit for building AI agents, from LLM communication to full coding assistants."
---

# How to Build a Custom Agent Framework with PI

[[people/nader-dabit|Nader Dabit]] walks through the [[tools/pi-framework|PI framework]], a TypeScript monorepo of packages for building AI agents. These packages power [[tools/openclaw|OpenClaw]], a multi-channel AI assistant.

## PI's Layered Architecture

```
pi-ai → pi-agent-core → pi-coding-agent → pi-tui
```

- **pi-ai** — Multi-provider LLM communication. Supports Anthropic, OpenAI, Google, Bedrock, Mistral, Groq, xAI, OpenRouter, Ollama. 2000+ model catalog.
- **pi-agent-core** — Agent loop: send messages to LLM, execute tool calls, feed results back, repeat. TypeBox schemas for type-safe tools. Full event stream.
- **pi-coding-agent** — Production runtime with built-in tools (read, bash, edit, write, grep, find, ls), JSONL session persistence, context compaction, skills, and extensions.
- **pi-tui** — Terminal UI with differential rendering, markdown display, and autocomplete.

## Key Capabilities

- **Extension system** hooks into lifecycle events (context, session_before_compact, tool_call, before_agent_start). Extensions are invisible to the LLM.
- **Context compaction** auto-triggers near window limit. Full history persists in JSONL; only in-memory context gets compacted.
- **Tool factories** create workspace-scoped tools with overridable I/O operations (Docker, SSH, virtual filesystems).
- **Session persistence** via JSONL with branching support.

## Production Patterns from OpenClaw

- Multi-provider auth via AuthStorage and ModelRegistry
- Stream middleware for per-provider customization
- Event routing to platform-specific channels (Telegram, Discord, Slack)

## Relevance to Harness Engineering

PI's architecture maps directly to [[concepts/harness-engineering|harness engineering]] needs. Each layer addresses a specific [[concepts/agent-harness|harness]] concern, and the extension system provides the hooks needed for context management, permission gating, and compaction customization.
