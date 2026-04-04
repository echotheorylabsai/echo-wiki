---
title: "Awesome Harness Engineering"
source_url: "https://github.com/walkinglabs/awesome-harness-engineering"
source_type: github
source_date: 2026-04-04
author: "walkinglabs"
ingested: 2026-04-04
ingestion_tool: tavily
tags: ["harness-engineering", "agents", "evals"]
---

# Awesome Harness Engineering

> A curated list of articles, playbooks, benchmarks, specifications, and open-source projects for harness engineering: the practice of shaping the environment around AI agents so they can work reliably.

Harness engineering sits at the intersection of context engineering, evaluation, observability, orchestration, safe autonomy, and software architecture.

## Contents

- Courses & Learning Resources
- Foundations
- Context, Memory & Working State
- Constraints, Guardrails & Safe Autonomy
- Specs, Agent Files & Workflow Design
- Evals & Observability
- Benchmarks
- Runtimes, Harnesses & Reference Implementations

## Courses & Learning Resources

- [walkinglabs/learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering) — Project-based course on making Codex and Claude Code more reliable

## Foundations

- [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) — OpenAI's flagship field report
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Anthropic's core article on initializer agents, feature lists, self-verification
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Anthropic follow-up on improving long-running app generation
- [The Anatomy of an Agent Harness](https://blog.langchain.com/the-anatomy-of-an-agent-harness/) — LangChain's framing of agent as model plus harness
- [Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) — Thoughtworks' framing into context engineering, architectural constraints, and entropy
- [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) — Anthropic's broader guide to workflows, agents, tools
- [Skill Issue: Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) — Weak results are often harness problems, not model problems
- [Your Agent Needs a Harness, Not a Framework](https://www.inngest.com/blog/your-agent-needs-a-harness-not-a-framework) — Inngest's case for infrastructure-first approach

## Context, Memory & Working State

- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Managing context window as working memory budget
- [Context Engineering for AI Agents: Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus) — KV-cache locality, tool masking, filesystem memory
- [Context Engineering for Coding Agents](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) — Thoughtworks guidance
- [Advanced Context Engineering for Coding Agents](https://www.humanlayer.dev/blog/advanced-context-engineering) — HumanLayer patterns for reducing context drift
- [Context-Efficient Backpressure for Coding Agents](https://www.humanlayer.dev/blog/context-efficient-backpressure) — Preventing agents from burning context
- [OpenHands Context Condensation](https://openhands.dev/blog/openhands-context-condensensation-for-more-efficient-ai-agents) — Bounded conversation memory
- [Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md) — Creating durable, repo-local instructions

## Constraints, Guardrails & Safe Autonomy

- [Beyond permission prompts](https://www.anthropic.com/engineering/claude-code-sandboxing) — Better sandboxing and policy design
- [Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) — Controlled execution through tool boundaries
- [Writing effective tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents) — Tool interfaces for correct and safe usage
- [Mitigating Prompt Injection Attacks](https://openhands.dev/blog/mitigating-prompt-injection-attacks-in-software-agents) — Confirmation mode, analyzers, sandboxing
- [Assessing internal quality while coding](https://martinfowler.com/articles/exploring-gen-ai/ccmenu-quality.html) — Quality checks in the loop
- [Anchoring AI to a reference application](https://martinfowler.com/articles/exploring-gen-ai/anchoring-to-reference.html) — Constraining agents with exemplars
- [Humans and Agents in Software Engineering Loops](https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html) — Where humans should strengthen the harness
- [Claude Code: Best practices for agentic coding](https://code.claude.com/docs) — Anthropic's practical recommendations

## Specs, Agent Files & Workflow Design

- [AGENTS.md](https://github.com/agentsmd/agents.md) — Lightweight open format for repo-local agent instructions
- [agent.md](https://github.com/agentmd/agent.md) — Related standardization effort
- [GitHub Spec Kit](https://github.com/github/spec-kit) — Spec-driven development toolkit
- [Understanding Spec-Driven-Development](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) — Why strong specs make AI delivery more dependable
- [12 Factor Agents](https://www.humanlayer.dev/blog/12-factor-agents) — Operating principles for production agents
- [12-Factor AgentOps](https://www.12factoragentops.com/) — Operations-oriented companion

## Evals & Observability

- [Testing Agent Skills Systematically with Evals](https://developers.openai.com/blog/eval-skills/) — Turning agent traces into repeatable evals
- [How to Evaluate Agent Skills](https://openhands.dev/blog/evaluating-agent-skills) — Measuring whether a skill actually helps
- [Agent evals](https://platform.openai.com/docs/guides/agent-evals) — OpenAI's product guide
- [Evaluation best practices](https://platform.openai.com/docs/guides/evaluation-best-practices) — Building eval suites matching real-world distributions
- [Trace grading](https://platform.openai.com/docs/guides/trace-grading) — Grading agent traces directly
- [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — What to measure with many possible trajectories
- [Quantifying infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise) — Runtime configuration can move benchmark scores
- [Evaluating Deep Agents](https://blog.langchain.com/evaluating-deep-agents-our-learnings/) — Single-step, full-run, multi-turn eval design
- [Improving Deep Agents with harness engineering](https://blog.langchain.com/improving-deep-agents-with-harness-engineering/) — Harness changes alone improve performance

## Benchmarks

Notable benchmarks for comparing harness quality:
- SWE-bench Verified, Terminal-Bench, τ-Bench, τ2-bench, WebArena, OSWorld, BrowseComp, GAIA, AgentBench, AppWorld, MCP Bench, Harbor, and 20+ more.

## Runtimes, Harnesses & Reference Implementations

- [Agent Frameworks, Runtimes, and Harnesses](https://blog.langchain.com/agent-frameworks-runtimes-and-harnesses-oh-my/) — LangChain's decomposition
- [Building agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk) — Production-oriented agent SDK
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — Multi-agent coordination
- [deepagents](https://github.com/langchain-ai/deepagents) — Longer-running agents with middleware
- [SWE-agent](https://github.com/SWE-agent/SWE-agent) — Inspectable research coding agent
- [Harbor](https://github.com/harbor-framework/harbor) — Generalized harness for evaluating agents at scale
- [Harness Evolver](https://github.com/raphaelchristi/harness-evolver) — Autonomously evolves agent harnesses

License: CC0 1.0
