---
title: "Event Sourcing Context"
created: 2026-07-01
author: "knowledge-maintenance"
summary: "Current engineering context for event sourcing."
related: ["[[concepts/event-sourcing|Event Sourcing]]"]
---

## Purpose

Event sourcing keeps knowledge in an append-only log.

Evidence: raw/blogs/sample-post.md#Overview

## Current Architecture

Articles are projections of the source log.

Evidence: raw/blogs/sample-post.md#Overview

## Constraints

The source log remains append-only.

Evidence: raw/blogs/sample-post.md#Overview

## Decisions

Use [[decisions/use-markdown|Markdown]] for the projection.

Evidence: raw/blogs/sample-post.md#Overview

## Open Questions

Open question: How should projection failures be retried?

## Read Next

- [[concepts/event-sourcing|Event Sourcing]]
