---
title: "Agent Harness Engineering: A Practitioner's Guide"
type: source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: medium
tags: [harness-engineering, agents, evals]
source_url: "local"
source_type: paper
author: "Unknown"
source_date: 2026-04-04
sources: ["[[raw/papers/agent-harness-engineering-guide.md]]"]
related: ["[[concepts/harness-engineering|Harness Engineering]]", "[[concepts/agent-harness|Agent Harness]]", "[[concepts/context-engineering|Context Engineering]]", "[[tools/pi-framework|PI Framework]]", "[[people/mario-zechner|Mario Zechner]]"]
summary: "Practitioner's guide mapping desired agent behaviors to harness features, with PI framework implementation patterns."
---

# Agent Harness Engineering: A Practitioner's Guide

A 100-page guide (partial extraction) that defines the [[concepts/agent-harness|agent harness]] concept and systematically maps model limitations to harness features.

## Core Thesis

Every production-grade agent behavior is the product of a **harness decision**, not a model capability. Models hallucinate, lose context, run unsafe commands, and lack domain knowledge — the harness compensates for each failure mode.

## The Behavior Gap

The guide provides a detailed mapping of model limitations to required harness features:

| Model Limitation | Harness Feature |
|---|---|
| Finite context window | Context compaction / summarization |
| No persistent memory | Filesystem or store-based long-term memory |
| Cannot restrict itself | Permission gates on tool execution |
| No task decomposition | Planning tools (todo lists, task files) |
| No focus control | Progressive skill disclosure |
| Cannot execute safely | Sandboxed execution environments |
| No context awareness | Dynamic context monitoring + pruning |
| Cannot coordinate | Sub-agent spawning + context isolation |
| Inconsistent behavior | Structured [[concepts/agent-evaluation|evaluation]] frameworks |
| No cost awareness | Token tracking + step limits |

## Why PI for Harness Engineering

The guide argues [[tools/pi-framework|PI]] (by [[people/mario-zechner|Mario Zechner]]) is uniquely suited because of three capabilities no other harness provides:
1. **Full system prompt replacement** via SYSTEM.md
2. **Per-turn message history manipulation** via the context event
3. **Per-tool I/O operation overrides** for Docker, SSH, or virtual filesystems

## Behavior-to-Implementation Mapping

For each desired behavior (sustained multi-turn coherence, persistent memory, permission gates, task management, multi-agent coordination, sandboxed execution, skill loading, evaluation harnesses, cost management, self-verification), the guide provides: model limitation analysis, harness feature design, and PI implementation with code.

## Connection to [[concepts/harness-engineering|Harness Engineering]]

This guide operationalizes harness engineering as a systematic discipline, moving from "what should agents do" to "what harness features make that possible" to "how to build it in PI."
