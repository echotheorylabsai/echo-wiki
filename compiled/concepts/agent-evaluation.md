---
title: "Agent Evaluation"
type: concept
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [evals, agents]
sources: ["[[raw/blogs/demystifying-evals-for-ai-agents.md]]", "[[raw/github/awesome-harness-engineering.md]]", "[[raw/papers/agent-harness-engineering-guide.md]]"]
related: ["[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/agent-harness|Agent Harness]]", "[[tools/swe-bench|SWE-bench]]", "[[tools/harbor-eval|Harbor]]"]
summary: "The practice of testing AI agents with automated evaluations to measure quality, catch regressions, and enable confident deployment."
domain: [evals, agents]
prerequisites: ["[[concepts/agent-harness|Agent Harness]]"]
---

# Agent Evaluation

The practice of testing AI agents with automated evaluations ("evals") to measure quality, catch regressions, and enable confident deployment.

## Why It Matters

Without evals, teams get trapped in reactive debugging cycles where issues only surface in production. Evals make problems visible before users encounter them, with compounding benefits throughout an agent's lifecycle. They also determine model adoption velocity — teams with evals can upgrade models in days rather than weeks.

## Core Structure

An eval has three parts: **input** (task), **execution** (trial), and **scoring** (grader).

- **Task**: A single test case with defined inputs and success criteria
- **Trial**: One attempt at completing a task; multiple trials handle non-determinism
- **Grader**: Scoring logic — code-based (fast, deterministic), model-based (flexible, nuanced), or human (gold standard, expensive)
- **Evaluation harness**: The infrastructure running evals end-to-end (see [[tools/harbor-eval|Harbor]])

## Key Patterns

- **Capability evals** ask "what does the agent do well?" — start with low pass rates
- **Regression evals** ask "did we break anything?" — maintain near-100% pass rates
- **pass@k** measures probability of at least one success across k trials
- **pass^k** measures probability of all k trials succeeding

## Grader Taxonomy

1. **Code-based** — string matching, binary tests, tool call verification, transcript analysis
2. **Model-based** — rubric scoring, pairwise comparison, multi-judge consensus
3. **Human** — expert review, A/B testing, spot-check sampling

## Relationship to [[concepts/harness-engineering|Harness Engineering]]

Agent evaluation is a core pillar of [[concepts/harness-engineering|harness engineering]]. The awesome-harness-engineering resource list dedicates two full sections (Evals & Observability, Benchmarks) to evaluation. The practitioner's guide identifies structured evaluation frameworks as the harness feature that compensates for models' inconsistent behavior across runs.

## Benchmarks

Notable benchmarks for agent evaluation: [[tools/swe-bench|SWE-bench]] Verified, Terminal-Bench, tau-Bench, WebArena, OSWorld, BrowseComp, GAIA, AgentBench.
