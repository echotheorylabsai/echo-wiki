# Wiki Index

## Concepts
- [[concepts/agent-evaluation|Agent Evaluation]] — The practice of testing AI agents with automated evaluations to measure quality, catch regressions, and enable confident deployment.
- [[concepts/agent-harness|Agent Harness]] — The scaffold/system surrounding an LLM that enables it to function as an agent — system prompt, tools, context management, permissions, and execution environment.
- [[concepts/context-engineering|Context Engineering]] — Managing the context window as a working memory budget — compaction, pruning, progressive disclosure, and KV-cache optimization.
- [[concepts/harness-engineering|Harness Engineering]] — The discipline of shaping the environment around AI agents so they can work reliably — encompassing context, constraints, evals, and orchestration.

## People
- [[people/mario-zechner|Mario Zechner]] — Creator of the PI framework, a TypeScript-based minimal terminal coding harness prioritizing extensibility for harness engineering.
- [[people/nader-dabit|Nader Dabit]] — Developer educator and author of the PI framework tutorial; builds on and documents the AI agent tooling ecosystem.

## Tools
- [[tools/harbor-eval|Harbor]] — Generalized evaluation harness for running agent trials at scale across cloud providers.
- [[tools/openclaw|OpenClaw]] — Multi-channel AI assistant built on the PI framework, supporting Telegram, Discord, Slack, and terminal interfaces.
- [[tools/pi-framework|PI Framework]] — TypeScript monorepo toolkit for building AI agents — pi-ai, pi-agent-core, pi-coding-agent, pi-tui — designed for extensible harness engineering.
- [[tools/swe-bench|SWE-bench]] — Benchmark for evaluating software engineering agents on real-world GitHub issues, using deterministic code-based grading.

## Sources
- [[sources/agent-harness-engineering-guide|Agent Harness Engineering: A Practitioner's Guide]] — Practitioner's guide mapping desired agent behaviors to harness features, with PI framework implementation patterns.
- [[sources/awesome-harness-engineering|Awesome Harness Engineering]] — Curated list of articles, benchmarks, specs, and tools for harness engineering — shaping the environment around AI agents for reliability.
- [[sources/demystifying-evals-for-ai-agents|Demystifying Evals for AI Agents]] — Anthropic's guide to designing rigorous automated evaluations for AI agents, covering grader types, eval roadmaps, and non-determinism handling.
- [[sources/how-to-build-custom-agent-framework-pi|How to Build a Custom Agent Framework with PI]] — Tutorial walking through PI's layered TypeScript toolkit for building AI agents, from LLM communication to full coding assistants.
