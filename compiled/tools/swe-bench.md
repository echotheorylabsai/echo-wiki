---
title: "SWE-bench"
type: tool
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: high
tags: [evals, agents]
sources: ["[[raw/blogs/demystifying-evals-for-ai-agents.md]]", "[[raw/github/awesome-harness-engineering.md]]"]
related: ["[[concepts/agent-evaluation|Agent Evaluation]]", "[[tools/harbor-eval|Harbor]]", "[[concepts/harness-engineering|Harness Engineering]]"]
summary: "Benchmark for evaluating software engineering agents on real-world GitHub issues, using deterministic code-based grading."
category: platform
repo: "https://github.com/princeton-nlp/SWE-bench"
maintained: true
---

# SWE-bench

A benchmark for evaluating software engineering agents on real-world GitHub issues. One of the most widely cited benchmarks in the [[concepts/agent-evaluation|agent evaluation]] space.

## How It Works

SWE-bench presents agents with real GitHub issues from popular open-source repositories. Agents must produce patches that resolve the issues. Grading is deterministic: does the code execute and pass the project's test suite?

**SWE-bench Verified** is the curated subset with human-validated tasks, filtering out ambiguous or poorly-specified issues.

## Why It Matters

- Exemplifies the coding agent eval pattern where deterministic graders (code execution + test passing) are ideal
- Cited by Anthropic as a model for effective coding agent evaluation
- Listed in the awesome-harness-engineering benchmarks section alongside Terminal-Bench, tau-Bench, WebArena, and others
- Used as a standard comparison point for harness quality — [[concepts/harness-engineering|harness engineering]] changes alone can move SWE-bench scores

## Relationship to Harness Engineering

SWE-bench scores are sensitive to [[concepts/harness-engineering|harness]] design, not just model capability. Infrastructure noise (runtime configuration) can move benchmark scores. This makes SWE-bench a useful tool for measuring harness quality, not just model quality.
