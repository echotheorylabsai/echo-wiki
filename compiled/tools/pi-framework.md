---
title: "PI Framework"
type: tool
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [agents, harness-engineering]
sources: ["[[raw/substacks/how-to-build-custom-agent-framework-pi.md]]", "[[raw/papers/agent-harness-engineering-guide.md]]"]
related: ["[[tools/openclaw|OpenClaw]]", "[[people/mario-zechner|Mario Zechner]]", "[[people/nader-dabit|Nader Dabit]]", "[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/agent-harness|Agent Harness]]", "[[concepts/context-engineering|Context Engineering]]"]
summary: "TypeScript monorepo toolkit for building AI agents — pi-ai, pi-agent-core, pi-coding-agent, pi-tui — designed for extensible harness engineering."
category: framework
repo: "https://github.com/nicepkg/pi"
maintained: true
---

# PI Framework

A TypeScript monorepo of layered packages for building AI agents. Created by [[people/mario-zechner|Mario Zechner]], documented by [[people/nader-dabit|Nader Dabit]]. Powers [[tools/openclaw|OpenClaw]].

## Architecture

```
pi-tui          — Terminal UI, markdown rendering, editor
pi-coding-agent — Sessions, built-in tools, extensions, skills
pi-agent-core   — Agent loop, tool execution, event streaming
pi-ai           — Multi-provider LLM communication, streaming, cost tracking
```

Each layer is independently usable. Use as much or as little as needed.

## Layer Details

- **pi-ai** — Supports Anthropic, OpenAI, Google, Bedrock, Mistral, Groq, xAI, OpenRouter, Ollama. 2000+ model catalog. Streaming, completions, tool definitions, cost tracking. Thinking levels (minimal/low/medium/high/xhigh).
- **pi-agent-core** — Agent loop: LLM call, tool execution, result feedback, repeat. TypeBox schemas for type-safe tools. Full event stream (agent_start/end, turn_start/end, message events, tool events). Runtime state management: switch models, tools, system prompt mid-conversation.
- **pi-coding-agent** — 7 built-in tools (read, bash, edit, write + opt-in grep, find, ls). JSONL session persistence with branching. Auto context compaction. Extension system for lifecycle hooks. Tool factories with I/O operation overrides.
- **pi-tui** — Differential rendering, markdown display, multi-line editor with autocomplete, loading spinners, flicker-free updates.

## Why PI for [[concepts/harness-engineering|Harness Engineering]]

Three capabilities unique to PI:
1. **Full system prompt replacement** via SYSTEM.md
2. **Per-turn message history manipulation** via the `context` extension event
3. **Per-tool I/O operation overrides** — redirect execution to Docker, SSH, virtual filesystems

## Extension Events

Complete lifecycle: session_start, input, before_agent_start, agent_start, turn_start, context, before_provider_request, tool_call, tool_execution_start/update/end, tool_result, turn_end, agent_end.

Extensions are invisible to the LLM — they operate behind the scenes for [[concepts/context-engineering|context engineering]], permission gating, and compaction customization.

## Upcoming Packages

pi-web-ui (browser chat), pi-mom (Slack bot), pi-pods (GPU pod deployment for open-source models).
