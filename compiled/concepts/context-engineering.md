---
title: "Context Engineering"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [harness-engineering, agents, llm]
sources: ["[[raw/github/awesome-harness-engineering.md]]", "[[raw/papers/agent-harness-engineering-guide.md]]", "[[raw/substacks/how-to-build-custom-agent-framework-pi.md]]"]
related: ["[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/agent-harness|Agent Harness]]", "[[tools/pi-framework|PI Framework]]"]
summary: "Managing the context window as a working memory budget — compaction, pruning, progressive disclosure, and KV-cache optimization."
domain: [harness-engineering, llm]
prerequisites: []
---

# Context Engineering

Managing the LLM context window as a finite working memory budget. The core challenge of keeping agents coherent across long interactions.

## Why It Matters

Models have finite context windows. Performance degrades well before the limit is reached. Without deliberate context management, agents lose coherence, repeat themselves, forget instructions, and burn tokens on irrelevant history. Context engineering is the #1 lever for improving long-running agent reliability.

## Key Techniques

- **Context compaction** — Summarizing older conversation turns to free space. PI auto-triggers compaction near the window limit; full history persists in JSONL while only in-memory context gets compacted.
- **Progressive skill disclosure** — Loading domain knowledge only when relevant rather than dumping everything into the system prompt.
- **Context condensation** — OpenHands' approach to bounded conversation memory.
- **KV-cache locality** — Manus' approach to optimizing cache hit rates for faster inference.
- **Tool masking** — Hiding irrelevant tools to reduce context consumption.
- **Backpressure** — Preventing agents from burning context on low-value actions.
- **Filesystem memory** — Using files as external memory to extend beyond the context window.

## Relationship to [[concepts/harness-engineering|Harness Engineering]]

Context engineering is one of the core pillars of [[concepts/harness-engineering|harness engineering]]. The awesome-harness-engineering resource list dedicates a full section to it. The practitioner's guide identifies context management as the harness feature that compensates for the model's finite context window.

## PI Implementation

The [[tools/pi-framework|PI framework]] provides two unique capabilities for context engineering:
1. **Per-turn message history manipulation** via the `context` extension event
2. **Auto-compaction** via the `session_before_compact` extension event

These allow harness engineers to implement custom compaction strategies, context pruning, and progressive disclosure without modifying the agent loop.

## Key Resources

Anthropic's "Effective context engineering for AI agents," Manus' "Context Engineering for AI Agents," Thoughtworks' and HumanLayer's context engineering guides, and OpenHands' context condensation approach.
