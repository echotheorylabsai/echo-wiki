---
title: "Demystifying Evals for AI Agents"
source_url: "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents"
source_type: blog
source_date: 2026-01-09
author: "Mikaela Grace, Jeremy Hadfield, Rodrigo Olivares, Jiri De Jonghe"
ingested: 2026-04-04
ingestion_tool: tavily
tags: ["evals", "agents", "harness-engineering"]
---

# Demystifying Evals for AI Agents

## Introduction

Effective evaluations enable teams to deploy AI agents with greater confidence. Without them, teams become trapped in reactive cycles where issues only surface in production. Evaluations make problems visible before users encounter them, with compounding benefits throughout an agent's lifecycle.

As discussed in related work on agent architecture, agents operate across multiple turns by invoking tools, updating state, and adjusting based on intermediate results. These same qualities that make agents useful—autonomy, intelligence, flexibility—simultaneously complicate evaluation efforts.

Through internal development and customer collaboration at the frontier of agent technology, Anthropic has identified rigorous evaluation design patterns. These approaches work across diverse agent architectures and real-world deployment scenarios.

## The Structure of an Evaluation

An **evaluation** ("eval") is fundamentally a test: provide input to an AI system, then apply scoring logic to measure success. This discussion focuses on **automated evals** that run during development without involving real users.

**Single-turn evaluations** follow a straightforward pattern: prompt, response, and grading logic. As capabilities advanced, **multi-turn evaluations** became increasingly prevalent.

**Agent evaluations** present additional complexity. Agents use tools across many turns, modifying environmental state and adapting continuously—allowing mistakes to propagate and compound.

### Key Definitions

- **Task** (or problem/test case): A single test with defined inputs and success criteria.
- **Trial**: One attempt at completing a task. Multiple trials accommodate model output variance.
- **Grader**: Logic that scores specific performance aspects.
- **Transcript** (trace/trajectory): Complete trial record including outputs, tool calls, reasoning.
- **Outcome**: Final environmental state after trial completion.
- **Evaluation harness**: Infrastructure executing evals end-to-end.
- **Agent harness** (scaffold): System enabling models to function as agents.
- **Evaluation suite**: Task collection measuring specific capabilities or behaviors.

## Why Build Evaluations?

Teams beginning agent development often progress surprisingly far using manual testing, dogfooding, and intuition. However, after prototyping ends and agents reach production at scale, building without evaluations becomes unsustainable.

The breaking point typically arrives when users report degraded performance following changes. Without evals, debugging becomes reactive. Teams cannot distinguish genuine regressions from noise, automatically test changes across hundreds of scenarios pre-deployment, or measure improvements.

Writing evals benefits agents at any lifecycle stage. Early development forces product teams to explicitly define success; mature agents require evals to maintain consistent quality standards.

Evals also determine model adoption velocity. When powerful models release, eval-less teams require weeks testing while competitors with evals quickly assess strengths, tune prompts, and upgrade within days.

## How to Evaluate AI Agents

### Types of Graders for Agents

Agent evaluations combine three grader categories:

**Code-Based Graders:** String matching, binary tests, static analysis, outcome verification, tool call verification, transcript analysis. Fast, low cost, objective, reproducible. But brittle against valid variations and limited in nuance.

**Model-Based Graders:** Rubric-based scoring, natural language assertions, pairwise comparison, reference-based evaluation, multi-judge consensus. Flexible, scalable, captures nuance. But non-deterministic and requires human calibration.

**Human Graders:** Subject matter expert review, crowdsourced judgment, spot-check sampling, A/B testing. Gold-standard quality but expensive and slow.

### Capability vs. Regression Evals

**Capability** ("quality") evals ask what agents perform well, starting with low pass rates to target struggling areas. **Regression evals** ask whether agents maintain previous capabilities, maintaining near-100% pass rates.

### Evaluating Coding Agents

Effective coding agent evals rely on well-specified tasks, stable test environments, and comprehensive code validation. Deterministic graders suit coding agents because software evaluation is typically straightforward: does code execute and pass tests? SWE-bench Verified and Terminal-Bench exemplify this approach.

### Evaluating Conversational Agents

Success involves multiple dimensions: ticket resolution (state check), completion within N turns (transcript constraint), appropriate tone (LLM rubric). τ-Bench and τ2-Bench incorporate multidimensionality.

### Evaluating Research Agents

Research evals face unique challenges: expert disagreement on comprehensiveness, constantly-shifting ground truth, and longer open-ended outputs. BrowseComp tests whether agents find answers across the open web.

### Non-Determinism in Agent Evaluations

**pass@k** measures the likelihood agents achieve at least one correct solution across k attempts. **pass^k** measures the probability that all k trials succeed. Both metrics prove useful; product requirements determine which applies.

## A Roadmap: From Zero to Strong Evaluations

1. **Start Early** — 20-50 simple tasks from real failures make excellent starting points.
2. **Begin With Manual Testing** — Convert user-reported failures into test cases.
3. **Write Unambiguous Tasks** — Good tasks let two independent domain experts reach identical pass-fail verdicts.
4. **Build Balanced Problem Sets** — Test both when behaviors should and shouldn't occur.
5. **Build Robust Eval Harnesses** — Each trial should begin from clean environments.
6. **Design Graders Thoughtfully** — Grade produced artifacts, not paths taken.
7. **Check Transcripts** — Read many trial transcripts and grades.
8. **Monitor Capability Eval Saturation** — 100% pass rate evals signal no improvement room.
9. **Maintain Evaluation Suites Long-Term** — Eval suites are living artifacts needing ongoing attention.

## How Evals Fit With Other Understanding Methods

No single evaluation layer catches everything. Most effective teams combine automated evals, production monitoring, A/B testing, user feedback, manual transcript review, and systematic human studies. Like the Swiss Cheese Model from safety engineering, multiple combined methods mean failures slipping through one get caught by another.

## Appendix: Eval Frameworks

- **Harbor** — Infrastructure for running trials across cloud providers at scale
- **Braintrust** — Combines offline evaluation with production observability
- **LangSmith** — Tracing, evaluations, and dataset management (LangChain ecosystem)
- **Langfuse** — Open-source alternative for teams with data residency requirements
- **Arize Phoenix** — Open-source tracing, debugging, and evaluation platform
