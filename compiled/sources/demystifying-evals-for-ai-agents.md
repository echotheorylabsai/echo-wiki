---
title: "Demystifying Evals for AI Agents"
type: source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [evals, agents, harness-engineering]
source_url: "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents"
source_type: blog
author: "Mikaela Grace, Jeremy Hadfield, Rodrigo Olivares, Jiri De Jonghe"
source_date: 2026-01-09
sources: ["[[raw/blogs/demystifying-evals-for-ai-agents.md]]"]
related: ["[[concepts/agent-evaluation|Agent Evaluation]]", "[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/agent-harness|Agent Harness]]", "[[tools/harbor-eval|Harbor]]", "[[tools/swe-bench|SWE-bench]]"]
summary: "Anthropic's guide to designing rigorous automated evaluations for AI agents, covering grader types, eval roadmaps, and non-determinism handling."
---

# Demystifying Evals for AI Agents

Anthropic's engineering team presents a comprehensive guide to building evaluations for AI agents, drawn from internal development and customer collaboration.

## Key Ideas

- An **evaluation** is a test: provide input to an AI system, then apply scoring logic to measure success. The focus here is on **automated evals** that run during development.
- Agent evals are harder than single-turn evals because agents use tools across many turns, modify environmental state, and allow mistakes to compound.
- Key terminology: **task** (single test case), **trial** (one attempt), **grader** (scoring logic), **transcript** (complete trial record), **evaluation harness** (infrastructure executing evals), **agent harness** (scaffold enabling models to function as agents).

## Grader Types

Three categories for agent evaluations:
1. **Code-based graders** — string matching, binary tests, tool call verification. Fast and reproducible but brittle.
2. **Model-based graders** — rubric scoring, pairwise comparison, multi-judge consensus. Flexible but non-deterministic.
3. **Human graders** — expert review, A/B testing. Gold standard but expensive.

## Eval Roadmap

Nine-step progression from zero to strong evaluations: start early with 20-50 tasks from real failures, write unambiguous tasks, build robust [[concepts/agent-harness|eval harnesses]], design graders that grade artifacts not paths, and maintain eval suites as living artifacts.

## Non-Determinism

- **pass@k** — probability of at least one correct solution across k attempts.
- **pass^k** — probability that all k trials succeed.

## Eval Frameworks Mentioned

[[tools/harbor-eval|Harbor]], Braintrust, LangSmith, Langfuse, Arize Phoenix.

## Connection to Harness Engineering

Evals are a core pillar of [[concepts/harness-engineering|harness engineering]]. Without [[concepts/agent-evaluation|automated evals]], teams get trapped in reactive debugging cycles. The evaluation harness itself is a specific type of [[concepts/agent-harness|agent harness]] infrastructure.
