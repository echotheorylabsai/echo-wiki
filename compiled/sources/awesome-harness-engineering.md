---
title: "Awesome Harness Engineering"
type: source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [harness-engineering, agents, evals]
source_url: "https://github.com/walkinglabs/awesome-harness-engineering"
source_type: github
author: "walkinglabs"
source_date: 2026-04-04
sources: ["[[raw/github/awesome-harness-engineering.md]]"]
related: ["[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/context-engineering|Context Engineering]]", "[[concepts/agent-evaluation|Agent Evaluation]]", "[[concepts/agent-harness|Agent Harness]]", "[[tools/swe-bench|SWE-bench]]", "[[tools/harbor-eval|Harbor]]"]
summary: "Curated list of articles, benchmarks, specs, and tools for harness engineering — shaping the environment around AI agents for reliability."
---

# Awesome Harness Engineering

A community-curated resource list covering the full scope of harness engineering: [[concepts/context-engineering|context engineering]], [[concepts/agent-evaluation|evaluation]], observability, orchestration, safe autonomy, and software architecture.

## Sections Covered

### Foundations
Key articles from OpenAI, Anthropic, LangChain, Thoughtworks, HumanLayer, and Inngest defining the discipline. Core framing: "weak results are often harness problems, not model problems."

### Context, Memory & Working State
Resources on managing the context window as a working memory budget ([[concepts/context-engineering|context engineering]]). Covers KV-cache locality, tool masking, filesystem memory, context condensation, backpressure, and CLAUDE.md patterns.

### Constraints, Guardrails & Safe Autonomy
Sandboxing, permission design, tool interface safety, prompt injection mitigation, quality checks in the loop, and anchoring agents to reference applications.

### Specs, Agent Files & Workflow Design
AGENTS.md, agent.md, GitHub Spec Kit, spec-driven development, 12 Factor Agents, 12-Factor AgentOps.

### Evals & Observability
Links to OpenAI, Anthropic, and LangChain guidance on [[concepts/agent-evaluation|agent evals]], trace grading, infrastructure noise quantification, and eval-driven harness improvement.

### Benchmarks
Notable benchmarks: [[tools/swe-bench|SWE-bench]] Verified, Terminal-Bench, tau-Bench, WebArena, OSWorld, BrowseComp, GAIA, AgentBench, AppWorld, MCP Bench, [[tools/harbor-eval|Harbor]], and 20+ more.

### Runtimes, Harnesses & Reference Implementations
Frameworks, SDKs, and open-source agents: LangChain deepagents, Claude Agent SDK, SWE-agent, [[tools/harbor-eval|Harbor]], Harness Evolver.

## Significance

This is the definitive community reference for the [[concepts/harness-engineering|harness engineering]] discipline. It positions harness engineering at the intersection of multiple agent infrastructure concerns and provides a reading path from foundations through implementation.
