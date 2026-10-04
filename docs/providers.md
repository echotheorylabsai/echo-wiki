# Provider Support

Echo Wiki uses the [Agent Skills](https://agentskills.io) open standard, making it compatible with any agent that supports `.claude/skills/` directories.

## Supported Agents

| Agent | Instruction File | Status |
|---|---|---|
| [Claude Code](https://claude.ai/code) | `CLAUDE.md` | Fully supported |
| [Codex CLI](https://github.com/openai/codex) | `AGENTS.md` | Fully supported |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `GEMINI.md` | Fully supported |
| Any Agent Skills agent | `.claude/skills/` | Compatible |

## How It Works

Each agent reads its instruction file (`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) which points to:
- `_meta/wiki.config.yaml` for domain configuration
- `.claude/skills/` for operation definitions (onboard, ingest, compile, rebuild, index, lint, query, context, maintain)
- `_meta/schemas/frontmatter.yaml` for validation rules

The skills themselves are markdown files with YAML frontmatter — human-readable and agent-executable.

## Agent Skills Specification

Skills follow the [Agent Skills](https://agentskills.io) open standard:

```
.claude/skills/
├── onboard/
│   ├── SKILL.md
│   ├── scripts/
│   └── references/
├── ingest/
│   └── SKILL.md    # name: ingest
├── compile/
│   └── SKILL.md    # name: compile
├── rebuild/
│   └── SKILL.md    # name: rebuild
├── index/
│   └── SKILL.md    # name: index
├── lint/
│   └── SKILL.md    # name: lint
├── query/
│   └── SKILL.md    # name: query
├── context/
│   └── SKILL.md    # name: context
└── maintain/
    └── SKILL.md    # name: maintain
```

Each `SKILL.md` contains:
- YAML frontmatter with `name` and `description`
- Step-by-step markdown instructions the agent follows
- References to schemas and config files

## First-time Onboarding

An agent does not need automatic skill discovery to bootstrap a repository. Give it the absolute path to a complete Echo Wiki checkout's `.claude/skills/onboard/SKILL.md` and the destination repository. See [Getting Started](/getting-started) for fresh and existing-repository examples. Verify each agent's instruction loading and command support; the skill does not install or authenticate an agent.
