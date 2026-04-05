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
- `.claude/skills/` for operation definitions (ingest, compile, rebuild, index, lint)
- `_meta/schemas/frontmatter.yaml` for validation rules

The skills themselves are markdown files with YAML frontmatter — human-readable and agent-executable.

## Agent Skills Specification

Skills follow the [Agent Skills](https://agentskills.io) open standard:

```
.claude/skills/
├── ingest/
│   └── SKILL.md    # name: ingest
├── compile/
│   └── SKILL.md    # name: compile
├── rebuild/
│   └── SKILL.md    # name: rebuild
├── index/
│   └── SKILL.md    # name: index
└── lint/
    └── SKILL.md    # name: lint
```

Each `SKILL.md` contains:
- YAML frontmatter with `name` and `description`
- Step-by-step markdown instructions the agent follows
- References to schemas and config files
