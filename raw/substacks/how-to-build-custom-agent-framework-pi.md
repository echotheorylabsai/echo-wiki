---
title: "How to Build a Custom Agent Framework with PI"
source_url: "https://nader.substack.com/p/how-to-build-a-custom-agent-framework"
source_type: substack
source_date: 2026-02-18
author: "Nader Dabit"
ingested: 2026-04-04
ingestion_tool: tavily
tags: ["agents", "harness-engineering"]
---

# How to Build a Custom Agent Framework with PI: The Agent Stack Powering OpenClaw

PI is a TypeScript toolkit for building AI agents. It's a monorepo of packages that layer on top of each other: `pi-ai` handles LLM communication across providers, `pi-agent-core` adds the agent loop with tool calling, `pi-coding-agent` gives you a full coding agent with built-in tools, session persistence, and extensibility, and `pi-tui` provides a terminal UI.

These are the same packages that power OpenClaw. This guide walks through each layer, progressively building up to a fully featured coding assistant.

## The Stack

```
┌─────────────────────────────────────────┐
│           Your Application              │
│  (OpenClaw, a CLI tool, a Slack bot)    │
├────────────────────┬────────────────────┤
│  pi-coding-agent   │       pi-tui       │
│  Sessions, tools,  │  Terminal UI,      │
│  extensions        │  markdown, editor  │
├────────────────────┴────────────────────┤
│            pi-agent-core                │
│  Agent loop, tool execution, events     │
├─────────────────────────────────────────┤
│               pi-ai                     │
│  Streaming, models, multi-provider LLM  │
└─────────────────────────────────────────┘
```

Each layer adds capability. Use as much or as little as you need.

- **pi-ai** — Call any LLM through one interface. Anthropic, OpenAI, Google, Bedrock, Mistral, Groq, xAI, OpenRouter, Ollama, and more. Streaming, completions, tool definitions, cost tracking.
- **pi-agent-core** — Wraps pi-ai into an agent loop. You define tools, the agent calls the LLM, executes tools, feeds results back, and repeats until done.
- **pi-coding-agent** — The full agent runtime. Built-in file tools (read, write, edit, bash), JSONL session persistence, context compaction, skills, and an extension system.
- **pi-tui** — Terminal UI library with differential rendering. Markdown display, multi-line editor with autocomplete, loading spinners, and flicker-free screen updates.

## Layer 1: pi-ai

The foundation layer provides multi-provider LLM communication. Key features:
- `getModel()` looks up a model by provider and ID from PI's built-in catalog of 2000+ models
- `completeSimple()` sends messages and returns the full AssistantMessage
- `streamSimple()` normalizes streaming across all providers into unified events
- Provider switching requires only changing the `getModel()` call
- Support for custom models and self-hosted endpoints via the Model type
- Thinking levels (minimal/low/medium/high/xhigh) for models that support extended thinking

## Layer 2: pi-agent-core

The agent loop layer. The `Agent` class runs: send messages to LLM → execute tool calls → feed results back → repeat until done.

Key features:
- TypeBox schemas for type-safe tool parameter definitions
- Event stream: agent_start, agent_end, turn_start/end, message_start/update/end, tool_execution_start/update/end
- `agent.steer()` for interrupting with redirects, `agent.followUp()` for queuing messages
- Runtime state management: switch models, tools, system prompt, thinking level at any time

## Layer 3: pi-coding-agent

The production-ready layer with built-in tools and session persistence.

**Built-in tools (7 total):**
- Default active: `read`, `bash`, `edit`, `write`
- Opt-in: `grep`, `find`, `ls`

**Session persistence:** JSONL files with tree structure (branching support). SessionManager factory methods: `inMemory()`, `create()`, `open()`, `continueRecent()`.

**Context compaction:** Auto-triggers when context approaches window limit. Full history stays in JSONL; only in-memory context gets compacted.

**Extensions:** Hook into lifecycle events (context, session_before_compact, tool_call, before_agent_start). The LLM never sees extensions — they operate behind the scenes. Used for context pruning, compaction customization, permission gating.

**Tool factories:** Create workspace-scoped tools via `createCodingTools()`, `createReadTool()`, etc. Accept `operations` overrides for Docker, SSH, virtual filesystems.

## Building Something Real

The guide builds a complete persistent coding assistant in ~120 lines that can read files, run commands, edit code, search the web, and remember conversations across restarts. Uses `createAgentSession` + `session.subscribe()` + `session.prompt()` pattern.

**Production adaptations (from OpenClaw):**
- Multi-provider auth via `AuthStorage` and `ModelRegistry`
- Stream middleware for per-provider customization
- Workspace-scoped tool factories
- Event routing to platform-specific channels (Telegram, Discord, Slack, etc.)
- Terminal UI via pi-tui with markdown rendering, autocomplete, streaming

## What's Next

Additional pi-mono packages: pi-web-ui (browser chat), pi-mom (Slack bot), pi-pods (GPU pod deployment for open-source models).
