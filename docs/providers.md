# Provider Support

Echo Wiki uses the [Agent Skills](https://agentskills.io) open standard, with one canonical set of definitions in `.claude/skills/`. Skill discovery paths depend on the agent.

## Supported Agents

| Agent | Instruction File | Skill loading |
|---|---|---|
| [Claude Code](https://claude.ai/code) | `CLAUDE.md` | Native discovery in `.claude/skills/`; invoke `/name` |
| [Codex](https://github.com/openai/codex) | `AGENTS.md` | Native discovery through `.agents/skills/` links; select a skill or use `$name` where supported |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `GEMINI.md` | Instructions point to `.claude/skills/`; explicitly load the file if needed |
| Other Agent Skills agents | Agent-specific | Verify that agent's discovery path or explicitly load `SKILL.md` |

## How It Works

Each agent reads its instruction file (`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) which points to:
- `_meta/wiki.config.yaml` for domain configuration
- `.claude/skills/` for operation definitions (onboard, ingest, compile, rebuild, index, lint, query, context, maintain)
- `_meta/schemas/frontmatter.yaml` for validation rules

Instruction loading and native skill discovery are separate. Echo Wiki includes `.agents/skills/<name>` relative links pointing to `../../.claude/skills/<name>`, so Codex and Claude share each skill and its supporting files. Onboarding creates the links automatically; [existing instances can add missing links](/getting-started#enable-codex-in-an-existing-instance) without reinstalling. Keep these as Git symlinks rather than duplicate directories.

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

## Sources

- [OpenAI: Skills](https://learn.chatgpt.com/docs/build-skills) — living documentation, undated; checked October 4, 2026. Documents `.agents/skills/` discovery and symlinked skill folders.
- [Anthropic: Extend Claude with skills](https://code.claude.com/docs/en/skills) — living documentation, undated; checked October 4, 2026. Documents `.claude/skills/` project skills and `/skill-name` invocation.
