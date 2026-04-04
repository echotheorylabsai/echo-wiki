---
title: "Agent Harness"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: medium
confidence: high
tags: [harness-engineering, agents]
sources: ["[[raw/blogs/demystifying-evals-for-ai-agents.md]]", "[[raw/papers/agent-harness-engineering-guide.md]]", "[[raw/github/awesome-harness-engineering.md]]", "[[raw/substacks/how-to-build-custom-agent-framework-pi.md]]"]
related: ["[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/context-engineering|Context Engineering]]", "[[concepts/agent-evaluation|Agent Evaluation]]", "[[tools/pi-framework|PI Framework]]"]
summary: "The scaffold/system surrounding an LLM that enables it to function as an agent — system prompt, tools, context management, permissions, and execution environment."
domain: [harness-engineering, agents]
prerequisites: []
---

# Agent Harness

Everything surrounding the LLM that shapes its behavior — the system prompt, tool definitions, context management strategy, permission gates, compaction logic, and execution environment. The LLM is the engine; the harness is the chassis, steering, and brakes.

## Why It Matters

Models cannot be autonomous agents on their own. They hallucinate, lose context, run unsafe commands, and lack domain knowledge. The agent harness compensates for each of these failure modes. **The harness is the product** — the model is a commodity component within it.

## Components

An agent harness typically includes:
- **System prompt** — Instructions defining agent behavior and constraints
- **Tool definitions** — The actions available to the agent
- **Context management** — [[concepts/context-engineering|Context engineering]] strategy (compaction, pruning, progressive disclosure)
- **Permission gates** — Controls on what the agent can do autonomously vs. with approval
- **Session persistence** — Maintaining state across interactions
- **Execution environment** — Sandboxing, Docker containers, SSH hosts
- **[[concepts/agent-evaluation|Evaluation]] harness** — Infrastructure for testing agent behavior

## Harness vs. Framework

LangChain distinguishes between **frameworks** (libraries for building agents), **runtimes** (execution infrastructure), and **harnesses** (the complete environment shaping agent behavior). The harness is the most encompassing concept — it includes the framework, runtime, and all surrounding infrastructure.

Inngest argues: "Your agent needs a harness, not a framework." The harness is infrastructure-first, while frameworks are abstraction-first.

## PI as a Harness

The [[tools/pi-framework|PI framework]] is explicitly designed as a harness. Its layered architecture (pi-ai, pi-agent-core, pi-coding-agent, pi-tui) maps directly to harness engineering concerns. Three capabilities make it uniquely suited:
1. Full system prompt replacement via SYSTEM.md
2. Per-turn message history manipulation via the context event
3. Per-tool I/O operation overrides for Docker, SSH, or virtual filesystems

## Relationship to [[concepts/harness-engineering|Harness Engineering]]

The agent harness is the concrete artifact that [[concepts/harness-engineering|harness engineering]] as a discipline produces. Harness engineering is the practice; the agent harness is the product.
