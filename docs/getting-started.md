# Getting Started

Use the `onboard` skill with your coding agent. It separates fresh repositories from repositories containing existing artifacts, previews changes, and stops with action items when setup is ambiguous.

## Prerequisites

- A coding agent with local file and command access
- Git, Bash and Ruby (standard YAML library; no gems required)
- Optional: Obsidian for browsing the resulting `wiki/` folder
- Source extraction tools only when needed: begin with local Markdown; URL/PDF/media extraction depends on your agent's available tools

Node.js is needed only to build this project's documentation site. API keys are not required to initialize a wiki or ingest local Markdown with an already configured agent.

## Get the Onboarding Skill

Use an existing clean Echo Wiki checkout, or clone one **outside your destination repository**:

```bash
git clone --depth 1 https://github.com/echotheorylabsai/echo-wiki.git /tmp/echo-wiki-onboarding
```

Keep the full checkout while onboarding: the skill uses its scripts, references, and runtime files. Do not download only `SKILL.md`.

## Fresh Repository

Clone your own empty repository, or initialize a new local one. For example, from a directory outside any existing repository:

```bash
git init company-kb
cd company-kb
pwd
```

Give your agent the resulting absolute path:

```text
Read /tmp/echo-wiki-onboarding/.claude/skills/onboard/SKILL.md and follow it.
Set up /absolute/path/to/company-kb as "Company Knowledge".
Use company, product, engineering, marketing, and research domains.
Use my-notes as my workspace. Start with the default article types.
```

The agent previews installation, configures your instance, integrates instructions/hooks, and verifies the first source you select. It does not create a remote, publish content, or commit/push automatically.

## Repository with Existing Artifacts

Open your existing repository and give the agent:

```text
Read /tmp/echo-wiki-onboarding/.claude/skills/onboard/SKILL.md and follow it.
Onboard /absolute/path/to/existing-repo. Inspect its document organization,
keep originals in place, preserve existing instructions and Git hooks,
and propose a small source inventory plus one initial import.
```

The agent adds Echo Wiki alongside compatible existing files. It does not move your documents or import the whole repository. If `wiki/`, `raw/`, or `_meta/` already belongs to another system, it reports the collision before installation and recommends a separate knowledge repository or an explicitly planned migration. Changing `vault.dir` is not a supported relocation workaround.

HTML, media, Linear and cloud artifacts may need a text export or an authorized extraction tool. Missing access, unclear document authority, and incompatible hooks are reported with specific next actions.

## Preview and Rerun Behavior

The skill's helper can be run directly from the upstream checkout:

```bash
ruby /tmp/echo-wiki-onboarding/.claude/skills/onboard/scripts/bootstrap.rb --check /absolute/path/to/company-kb
ruby /tmp/echo-wiki-onboarding/.claude/skills/onboard/scripts/bootstrap.rb --apply /absolute/path/to/company-kb
```

`--check` leaves the destination unchanged. `--apply` installs only the runtime scaffold; it does not configure your domains, merge existing instruction/ignore files, install Git hooks, or import sources. Continue with the skill to finish those steps. Rerunning against a recognized instance preserves it; this is not an upgrade tool. Interrupted partial installs need inspection before retrying.

## Verify and Start Using It

The agent should report setup validation, instruction/hook integration, and first-source verification separately. An empty wiki passing validation does not prove ingestion or answers work.

```text
/ingest /absolute/path/to/your-first-document.md
/query What does this document establish?
/context your-product-area
```

Use commands only when your agent recognizes them; otherwise ask it to read and follow the corresponding `.claude/skills/<name>/SKILL.md`. Review the cited source and commit the resulting changes when satisfied. Open **`wiki/`** in Obsidian to browse.

Multiple agents can draft in separate workspaces; use one integration writer at a time. Rerun `/context` or `/query` when their saved outputs need refreshing, and `/maintain` for a manual health review. See [Keeping Content Fresh](/keeping-fresh) for source replacement limits.

## Installed Instance

Existing artifacts remain alongside this scaffold. The documentation site and development dependencies stay in the upstream checkout.

```
my-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only, backend)
├── wiki/                      # Obsidian vault (user-facing)
│   ├── concepts/              # KB: default entity type directories
│   ├── people/                #     (configurable via entity_types)
│   ├── tools/
│   ├── sources/
│   ├── workspaces/            # Your notes + agent workspaces
│   │   └── my-notes/          # Default human workspace
│   ├── _index.md              # Master index
│   ├── _backlinks.md          # Cross-reference map
│   └── _log.md                # Activity log (auto-created by skills)
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # validation, indexing, pre-commit, and rebuild transaction scripts
├── .claude/skills/            # Agent Skills (onboard, ingest, compile, rebuild, lint, index, query, context, maintain)
├── .env.example               # API key template
├── AGENTS.md                  # Agent instructions (merged when present)
├── CLAUDE.md                  # Claude Code instructions
└── GEMINI.md                  # Gemini instructions
```

## What's Next?

- [Configure your domains](/configuration) for your specific use case
- [Learn about the skills](/skills) — ingest, compile, rebuild, lint, index, query, context, and maintain
- [Keep content fresh](/keeping-fresh) when sources, workspaces, or derived context change
- [Set up validation](/validation) — pre-commit hooks and semantic linting
- Create notes in `wiki/workspaces/my-notes/` and run `/index` to include them
