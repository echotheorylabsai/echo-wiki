---
title: "Harness Engineering"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: medium
confidence: high
tags: [harness-engineering, agents]
sources: ["[[raw/github/awesome-harness-engineering.md]]", "[[raw/papers/agent-harness-engineering-guide.md]]", "[[raw/blogs/demystifying-evals-for-ai-agents.md]]"]
related: ["[[concepts/agent-harness|Agent Harness]]", "[[concepts/context-engineering|Context Engineering]]", "[[concepts/agent-evaluation|Agent Evaluation]]", "[[tools/pi-framework|PI Framework]]"]
summary: "The discipline of shaping the environment around AI agents so they can work reliably — encompassing context, constraints, evals, and orchestration."
domain: [harness-engineering, agents]
prerequisites: []
---

# Harness Engineering

The discipline of deliberately designing the systems surrounding AI agents to produce desired behaviors that models cannot achieve on their own.

## Why It Matters

**Core insight**: Weak results are often harness problems, not model problems. Every production-grade agent behavior is the product of a harness decision, not a model capability. Harness changes alone can improve agent performance — sometimes more than model upgrades.

## Scope

Harness engineering sits at the intersection of:
- **[[concepts/context-engineering|Context engineering]]** — managing the context window as a working memory budget
- **[[concepts/agent-evaluation|Evaluation]]** — measuring agent performance with automated evals
- **Observability** — tracing, logging, and monitoring agent behavior
- **Orchestration** — coordinating multi-agent systems
- **Safe autonomy** — permission gates, sandboxing, guardrails
- **Software architecture** — tool design, runtime infrastructure

## The Behavior Gap

Models have fundamental limitations. The harness compensates:

| Model Limitation | Harness Compensation |
|---|---|
| Finite context | Compaction / summarization |
| No persistent memory | Filesystem or store-based memory |
| Cannot restrict itself | Permission gates |
| No task discipline | Planning tools |
| No focus control | Progressive skill disclosure |
| Cannot execute safely | Sandboxed environments |
| Inconsistent behavior | Structured [[concepts/agent-evaluation|evaluation]] |

## Key Resources

The [[sources/awesome-harness-engineering|Awesome Harness Engineering]] list is the definitive community reference. Foundational articles from OpenAI, Anthropic, LangChain, Thoughtworks, HumanLayer, and Inngest define the discipline.

## Implementation

The [[sources/agent-harness-engineering-guide|Practitioner's Guide]] maps each desired behavior to a harness feature and provides [[tools/pi-framework|PI framework]] implementation patterns. The [[concepts/agent-harness|agent harness]] is the concrete artifact that harness engineering produces.
