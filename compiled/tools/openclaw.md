---
title: "OpenClaw"
type: tool
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast
confidence: medium
tags: [agents, harness-engineering]
sources: ["[[raw/substacks/how-to-build-custom-agent-framework-pi.md]]"]
related: ["[[tools/pi-framework|PI Framework]]", "[[people/mario-zechner|Mario Zechner]]", "[[people/nader-dabit|Nader Dabit]]"]
summary: "Multi-channel AI assistant built on the PI framework, supporting Telegram, Discord, Slack, and terminal interfaces."
category: product
repo: "https://github.com/nicepkg/openclaw"
maintained: true
---

# OpenClaw

A multi-channel AI assistant built on the [[tools/pi-framework|PI framework]]. Created by [[people/mario-zechner|Mario Zechner]].

## What It Does

OpenClaw is the production application that proves out PI's architecture. It routes agent interactions across multiple platforms (Telegram, Discord, Slack, terminal) using a shared agent runtime.

## Production Patterns

[[people/nader-dabit|Nader Dabit]]'s tutorial documents several production patterns from OpenClaw:
- **Multi-provider auth** via AuthStorage and ModelRegistry
- **Stream middleware** for per-provider customization
- **Workspace-scoped tool factories** for isolated environments
- **Event routing** to platform-specific channels
- **Terminal UI** via pi-tui with markdown rendering, autocomplete, streaming

## Significance

OpenClaw demonstrates that [[tools/pi-framework|PI]]'s layered architecture scales from a simple CLI tool to a multi-channel production assistant. The same pi-agent-core loop and pi-coding-agent tools work across all channels.
