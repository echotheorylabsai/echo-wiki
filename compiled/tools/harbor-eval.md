---
title: "Harbor"
type: tool
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: medium
tags: [evals, agents, harness-engineering]
sources: ["[[raw/blogs/demystifying-evals-for-ai-agents.md]]", "[[raw/github/awesome-harness-engineering.md]]"]
related: ["[[concepts/agent-evaluation|Agent Evaluation]]", "[[tools/swe-bench|SWE-bench]]", "[[concepts/harness-engineering|Harness Engineering]]"]
summary: "Generalized evaluation harness for running agent trials at scale across cloud providers."
category: framework
repo: "https://github.com/harbor-framework/harbor"
maintained: true
---

# Harbor

A generalized evaluation harness for running agent trials at scale across cloud providers.

## What It Does

Harbor provides the infrastructure layer for [[concepts/agent-evaluation|agent evaluation]]. It handles trial execution, environment management, and result collection — the "evaluation harness" in the terminology defined by Anthropic's evals guide.

## Context

- Listed as a recommended eval framework in Anthropic's "Demystifying Evals for AI Agents" alongside Braintrust, LangSmith, Langfuse, and Arize Phoenix
- Included in the awesome-harness-engineering benchmarks section
- Included in the runtimes and reference implementations section of awesome-harness-engineering

## Why It Matters

Each eval trial should begin from a clean environment for reproducibility. Harbor manages this infrastructure concern at scale, enabling teams to run hundreds or thousands of trials across different cloud providers without manual environment setup.

## Relationship to [[concepts/harness-engineering|Harness Engineering]]

Harbor is a concrete tool that operationalizes the "build robust eval harnesses" step from Anthropic's eval roadmap. It sits at the intersection of evaluation and infrastructure — two core [[concepts/harness-engineering|harness engineering]] concerns.
