# Vault & Workspace Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure Echo Wiki so Obsidian opens `wiki/` as vault (hiding backend files), with a workspace model for human/agent content alongside the compiled knowledge base.

**Architecture:** Rename `compiled/` to `wiki/` (the Obsidian vault root). Inside `wiki/`, KB type directories (`concepts/`, `people/`, `tools/`, `sources/`) hold pipeline-compiled articles; `workspaces/` holds actor-created content. Skills, hooks, and docs all update to reference the new paths. Structure protection via pre-commit guard + skill self-healing.

**Tech Stack:** Markdown, YAML, Bash (hooks), Obsidian config (JSON)

**Spec:** `docs/superpowers/specs/2026-04-05-vault-workspace-redesign.md`

---

### Task 1: Create wiki/ directory structure and move Obsidian config

**Files:**
- Create: `wiki/.obsidian/graph.json`
- Create: `wiki/.obsidian/app.json`
- Create: `wiki/.obsidian/appearance.json`
- Create: `wiki/concepts/.gitkeep`
- Create: `wiki/people/.gitkeep`
- Create: `wiki/tools/.gitkeep`
- Create: `wiki/sources/.gitkeep`
- Create: `wiki/workspaces/my-notes/.gitkeep`
- Create: `wiki/_index.md`
- Create: `wiki/_backlinks.md`

- [ ] **Step 1: Create the wiki/ directory tree**

```bash
mkdir -p wiki/.obsidian wiki/concepts wiki/people wiki/tools wiki/sources wiki/workspaces/my-notes
```

- [ ] **Step 2: Create .gitkeep files for empty directories**

```bash
touch wiki/concepts/.gitkeep wiki/people/.gitkeep wiki/tools/.gitkeep wiki/sources/.gitkeep wiki/workspaces/my-notes/.gitkeep
```

- [ ] **Step 3: Create wiki/.obsidian/graph.json**

```json
{
  "collapse-filter": true,
  "search": "",
  "showTags": false,
  "showAttachments": false,
  "hideUnresolved": false,
  "showOrphans": true,
  "collapse-color-groups": false,
  "colorGroups": [
    {
      "query": "path:concepts",
      "color": { "a": 1, "rgb": 4491519 }
    },
    {
      "query": "path:people",
      "color": { "a": 1, "rgb": 4504456 }
    },
    {
      "query": "path:tools",
      "color": { "a": 1, "rgb": 16746564 }
    },
    {
      "query": "path:sources",
      "color": { "a": 1, "rgb": 8947848 }
    },
    {
      "query": "path:workspaces",
      "color": { "a": 1, "rgb": 14701138 }
    }
  ],
  "collapse-display": true,
  "showArrow": true,
  "textFadeMultiplier": 0,
  "nodeSizeMultiplier": 1,
  "lineSizeMultiplier": 1,
  "collapse-forces": true,
  "centerStrength": 0.5,
  "repelStrength": 10,
  "linkStrength": 1,
  "linkDistance": 250,
  "scale": 1,
  "close": false
}
```

Key changes from old `.obsidian/graph.json`:
- `"search"` changed from `"path:compiled"` to `""` (no filter — everything in vault is relevant)
- Color group queries: removed `compiled/` prefix (e.g., `path:compiled/concepts` → `path:concepts`)
- Added new color group for `path:workspaces` with distinct purple color (rgb: 14701138)

- [ ] **Step 4: Create wiki/.obsidian/app.json**

```json
{
  "userIgnoreFilters": [
    "_index.md",
    "_backlinks.md"
  ],
  "useMarkdownLinks": false,
  "newFileLocation": "current",
  "newLinkFormat": "shortest",
  "showFrontmatter": true,
  "strictLineBreaks": false,
  "alwaysUpdateLinks": true
}
```

Identical to old `.obsidian/app.json` — no changes needed.

- [ ] **Step 5: Create wiki/.obsidian/appearance.json**

```json
{
  "theme": "obsidian",
  "baseFontSize": 16,
  "interfaceFontSize": 14
}
```

Identical to old `.obsidian/appearance.json` — no changes needed.

- [ ] **Step 6: Create wiki/_index.md**

```markdown
# Wiki Index

## Concepts

## People

## Tools

## Sources

## Workspaces
```

- [ ] **Step 7: Create wiki/_backlinks.md**

```markdown
# Backlinks
```

- [ ] **Step 8: Verify directory structure**

```bash
find wiki -type f | sort
```

Expected output:
```
wiki/.obsidian/app.json
wiki/.obsidian/appearance.json
wiki/.obsidian/graph.json
wiki/_backlinks.md
wiki/_index.md
wiki/concepts/.gitkeep
wiki/people/.gitkeep
wiki/sources/.gitkeep
wiki/tools/.gitkeep
wiki/workspaces/my-notes/.gitkeep
```

- [ ] **Step 9: Commit**

```bash
git add wiki/
git commit -m "feat: create wiki/ directory structure with Obsidian vault config

New vault root at wiki/ replaces compiled/ as the Obsidian-facing directory.
Includes KB type directories, default workspace, and updated Obsidian config."
```

---

### Task 2: Update _meta/ files (schema, config, prompts)

**Files:**
- Modify: `_meta/schemas/frontmatter.yaml`
- Modify: `_meta/wiki.config.yaml`
- Modify: `_meta/prompts/compile.md`
- Modify: `_meta/prompts/index-update.md`
- Modify: `_meta/prompts/ingest.md`
- Modify: `_meta/prompts/lint.md`
- Modify: `_meta/prompts/query.md`
- Create: `_meta/prompts/structure-check.md`

- [ ] **Step 1: Update frontmatter.yaml — change sources type and add workspace section**

In `_meta/schemas/frontmatter.yaml`, make these changes:

Change `sources` in `compiled_shared.required_fields` from:
```yaml
    sources: list[wikilink]  # At least one entry required
```
to:
```yaml
    sources: list[string]  # Raw file paths (plain strings, not wikilinks)
```

Change `related` in `compiled_shared.required_fields` from:
```yaml
    related: list[wikilink]
```
to (no change to type, just confirming it stays as wikilink):
```yaml
    related: list[wikilink]
```

(No change needed for `related` — it stays as `list[wikilink]` since those point to other wiki/ articles.)

Also update the comment on the `compiled_shared` section header (if any reference to `compiled/` exists in comments within the file, change to `wiki/`).

Add after the `raw:` section and before `enums:`:

```yaml
workspace:
  required_fields:
    title: string
    created: date  # YYYY-MM-DD
    author: string  # actor name (human name or agent identifier)
    tags: list[string]
  optional_fields:
    summary: string
    related: list[wikilink]
    sources: list[string]
```

- [ ] **Step 2: Update wiki.config.yaml — add vault section**

In `_meta/wiki.config.yaml`, add before `schema_version: 1`:

```yaml
vault:
  dir: wiki
  default_workspace: my-notes

```

- [ ] **Step 3: Update _meta/prompts/compile.md**

Replace entire file content of `_meta/prompts/compile.md` with:

```markdown
# Compile — Reference

Transform raw source documents into structured wiki articles in `wiki/`.

## Input
- Path to raw source(s), or "all" for full recompile

## Steps
1. Run Step 0: Verify Wiki Structure (see `_meta/prompts/structure-check.md`)
2. Read `_meta/wiki.config.yaml` and `_meta/schemas/frontmatter.yaml`
3. Read `wiki/_index.md` (understand existing wiki state)
4. Read the target raw source(s)
5. For each source:
   a. Create source-summary in `wiki/sources/`
   b. Extract concepts, people, tools from content
   c. For each entity: check if article exists in `wiki/`
      - Exists → read article, merge new information (never overwrite)
      - New → create article with full frontmatter
   d. Add `[[wikilinks]]` between related articles
6. Regenerate `wiki/_index.md` and `wiki/_backlinks.md` per `_meta/prompts/index-update.md`

## Merge Rules
- Add new information in appropriate sections
- Update `last_updated` date
- Add new source to `sources:` list (plain string path, not wikilink)
- Add new `related:` wikilinks
- NEVER remove or overwrite existing content

## Compiled Type Mapping
| type | directory |
|---|---|
| concept | wiki/concepts/ |
| person | wiki/people/ |
| tool | wiki/tools/ |
| source-summary | wiki/sources/ |
```

- [ ] **Step 4: Update _meta/prompts/index-update.md**

Replace entire file content of `_meta/prompts/index-update.md` with:

```markdown
# Index Update — Reference

Regenerate `_index.md` and `_backlinks.md`. Covers ALL content in `wiki/` (KB articles + workspace content).

Triggered by `/compile`, `/rebuild`, and `/index`.

## _index.md Format

```
# Wiki Index

## Concepts
- [[concepts/<name>|<Title>]] — <one-line summary>

## People
- [[people/<name>|<Title>]] — <one-line summary>

## Tools
- [[tools/<name>|<Title>]] — <one-line summary>

## Sources
- [[sources/<name>|<Title>]] — <one-line summary>

## Workspaces
### <workspace-name>
- [[workspaces/<workspace-name>/<file>|<Title>]] — <summary or title>
```

Sorted alphabetically within each section. For workspace files without a `summary` frontmatter field, use just the title.

## _backlinks.md Format

```
# Backlinks

## [[<type>/<name>]]
Linked from:
- [[<type>/<article>]]
- [[workspaces/<workspace>/<file>]]
```

For each article in `wiki/`, scan ALL other files (KB + workspaces) for wikilinks pointing to it. Include cross-zone references.

## Scan Scope

When regenerating, scan ALL `.md` files in `wiki/` recursively. Skip:
- `_index.md` and `_backlinks.md` themselves
- Files in `.obsidian/`
- Non-`.md` files
```

- [ ] **Step 5: Update _meta/prompts/ingest.md**

In `_meta/prompts/ingest.md`, change line 2:
```
2. Check `compiled/_index.md` for existing source-summaries (avoid duplicates)
```
to:
```
2. Check `wiki/_index.md` for existing source-summaries (avoid duplicates)
```

- [ ] **Step 6: Update _meta/prompts/lint.md**

In `_meta/prompts/lint.md`, replace the entire file with:

```markdown
# Lint — Reference

Run semantic validation checks on the wiki. Produces report at `output/reports/lint-<date>.md`.

## Input
- Optional scope: path, domain tag, or "all"

## Checks
1. Validate all frontmatter against `_meta/schemas/frontmatter.yaml`
   - KB articles (in `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`): full `compiled_shared` schema
   - Workspace files (in `wiki/workspaces/`): light `workspace` schema (title, created only)
2. Check for broken `[[wikilinks]]` (target file must exist within `wiki/`)
3. Find orphaned articles (no inbound links via `_backlinks.md`)
4. Detect contradictory claims across related KB articles (skip workspace content)
5. Flag stale content: `last_verified` + decay_rate threshold exceeded (skip workspace content)
   - fast: 30 days, medium: 90 days, slow: 365 days
6. Suggest missing concepts (topics frequently referenced but no article)
7. Detect duplicate concepts (different articles about the same entity)

## Progressive Loading
- Start with `wiki/_index.md` + `wiki/_backlinks.md`
- Load articles in small batches for validation
- Load related article pairs for contradiction detection

## Report Format
Markdown report with sections for each check type, listing specific issues with file paths and suggested fixes.
```

- [ ] **Step 7: Update _meta/prompts/query.md**

Replace entire file content of `_meta/prompts/query.md` with:

```markdown
# Query — Reference

Answer questions by navigating the wiki. No dedicated skill — ad-hoc operation.

## Steps
1. Read `wiki/_index.md` to understand what's available
2. Identify relevant articles from the index
3. Read those specific articles
4. Synthesize an answer from wiki content
5. Optionally save result to `output/reports/`

## Progressive Loading
- Start at L0 (`wiki/_index.md`)
- Follow links to L2 (specific articles) as needed
- Never load the entire wiki
```

- [ ] **Step 8: Create _meta/prompts/structure-check.md**

Create new file `_meta/prompts/structure-check.md`:

```markdown
# Structure Check — Reference

Verify wiki directory structure is intact. Run as Step 0 of every skill before any other work.

Referenced by: `/compile`, `/rebuild`, `/lint`, `/index`, `/ingest`

## Required Paths

| Path | Type | Recovery |
|---|---|---|
| `wiki/` | directory | Create it |
| `wiki/concepts/` | directory | Create it |
| `wiki/people/` | directory | Create it |
| `wiki/tools/` | directory | Create it |
| `wiki/sources/` | directory | Create it |
| `wiki/workspaces/` | directory | Create with `my-notes/.gitkeep` inside |
| `wiki/_index.md` | file | Create scaffold with section headers |
| `wiki/_backlinks.md` | file | Create with `# Backlinks` header |

## Behavior

For each required path:
1. Check if it exists
2. If missing, recreate it silently (see Recovery column)
3. Continue to the skill's main workflow

## _index.md Scaffold

If `wiki/_index.md` must be recreated:

```
# Wiki Index

## Concepts

## People

## Tools

## Sources

## Workspaces
```

## Important

- Never abort or error on missing structure — always self-heal
- Log a brief note if any path was recreated (e.g., "Recreated missing wiki/concepts/ directory")
- This check is idempotent — running it multiple times is safe
```

- [ ] **Step 9: Commit**

```bash
git add _meta/
git commit -m "feat: update schemas, config, and prompts for wiki/ vault structure

- Add workspace section to frontmatter schema
- Change sources field from list[wikilink] to list[string]
- Add vault config section to wiki.config.yaml
- Update all prompts: compiled/ → wiki/
- Add structure-check.md for skill self-healing"
```

---

### Task 3: Update agent skills

**Files:**
- Modify: `.claude/skills/compile/SKILL.md`
- Modify: `.claude/skills/rebuild/SKILL.md`
- Modify: `.claude/skills/ingest/SKILL.md`
- Modify: `.claude/skills/lint/SKILL.md`
- Create: `.claude/skills/index/SKILL.md`

- [ ] **Step 1: Update compile skill**

In `.claude/skills/compile/SKILL.md`, apply these changes throughout the entire file:

**Global find-and-replace (apply all):**
- `compiled/` → `wiki/` (all occurrences)
- `compiled/_index.md` → `wiki/_index.md`
- `compiled/_backlinks.md` → `wiki/_backlinks.md`

**Logic change — sources field format.** In Step 2 (Create Source Summary), change:
```yaml
sources: ["[[raw/<category>/<filename>.md]]"]
```
to:
```yaml
sources: ["raw/<category>/<filename>.md"]
```

In Step 4 (Create or Merge Articles), for all three article types (concepts, people, tools), change:
```yaml
sources: ["[[raw/<category>/<source-file>.md]]"]
```
to:
```yaml
sources: ["raw/<category>/<source-file>.md"]
```

In Step 4 merge instructions, change step 4 from:
```
4. Append the new source to the `sources:` array
```
to:
```
4. Append the new raw file path (plain string, not wikilink) to the `sources:` array
```

**Logic change — add Step 0.** Add before "## Input" section:

```markdown
## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.
```

**Logic change — index scans all of wiki/.** In Step 6 (Update Index and Backlinks), add after the _index.md format block:

```markdown
**Important:** The index must include ALL content in `wiki/`, not just KB articles. Scan `wiki/workspaces/` for workspace files and include them under a `## Workspaces` section, grouped by workspace name. For workspace files without a `summary` field, use just the title.
```

In Step 6, add after the _backlinks.md format block:

```markdown
**Important:** Backlinks must include cross-zone references. If a workspace file links to a KB article, that link appears in the KB article's backlinks entry.
```

- [ ] **Step 2: Update rebuild skill**

In `.claude/skills/rebuild/SKILL.md`, apply these changes:

**Global find-and-replace (apply all):**
- `compiled/` → `wiki/` (all occurrences)
- `compiled/_index.md` → `wiki/_index.md`
- `compiled/_backlinks.md` → `wiki/_backlinks.md`

**Logic change — scoped wipe.** Replace Step 4 entirely:

Old Step 4:
```markdown
### Step 4: Wipe Compiled Directory

Delete all `.md` files recursively inside `compiled/` — this includes all articles, `_index.md`, and `_backlinks.md`.

Preserve the directory structure (empty folders are fine). Do NOT touch `raw/` or any other directory.
```

New Step 4:
```markdown
### Step 4: Wipe KB Type Directories

Delete all `.md` files recursively inside these 4 directories only:
- `wiki/concepts/`
- `wiki/people/`
- `wiki/tools/`
- `wiki/sources/`

**NEVER delete or modify:**
- `wiki/workspaces/` (actor workspace content)
- `wiki/.obsidian/` (Obsidian vault config)
- `wiki/_index.md` (will be regenerated in Step 7)
- `wiki/_backlinks.md` (will be regenerated in Step 7)

Preserve the directory structure (empty folders are fine). Do NOT touch `raw/` or any other directory.
```

**Logic change — add Step 0.** Add before "## Input" section:

```markdown
## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.
```

**Logic change — Step 5 scaffold includes Workspaces section.** Update Step 5 scaffold:

```markdown
# Wiki Index

## Concepts

## People

## Tools

## Sources

## Workspaces
```

**Logic change — Step 7 covers workspaces.** In Step 7, add:

```markdown
**Important:** When regenerating `_index.md` and `_backlinks.md`, scan ALL of `wiki/` including preserved `wiki/workspaces/` content. Workspace entries must appear in both files after rebuild.
```

- [ ] **Step 3: Update ingest skill**

In `.claude/skills/ingest/SKILL.md`, apply these changes:

**Find-and-replace:**
- `compiled/_index.md` → `wiki/_index.md` (2 occurrences: Context Loading step 2, and Step 6 reference)

**Add Step 0.** Add before "## Input" section:

```markdown
## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.
```

- [ ] **Step 4: Update lint skill**

In `.claude/skills/lint/SKILL.md`, apply these changes:

**Global find-and-replace (apply all):**
- `compiled/` → `wiki/` (all occurrences)
- `compiled/_index.md` → `wiki/_index.md`
- `compiled/_backlinks.md` → `wiki/_backlinks.md`

**Add Step 0.** Add before "## Input" section:

```markdown
## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.
```

**Logic change — Input examples.** Update input examples:
```
- Examples: `/lint`, `/lint all`, `/lint wiki/concepts/`, `/lint --domain llm`
```

**Logic change — workspace awareness.** Add after Check 1 description:

```markdown
**Workspace files** (in `wiki/workspaces/`): validate with light `workspace` schema — only check `title` and `created` are present with valid date format. Skip `type`, `sources`, `confidence`, `decay_rate`, and type-specific field checks.
```

In Check 2 (Broken Wikilinks), replace:
```markdown
- Verify target file exists:
  - Links starting with `raw/` → check from wiki root
  - All other links → check in `compiled/` directory
```
with:
```markdown
- Verify target file exists within `wiki/`: `wiki/${link}.md`
- No special handling for `raw/` prefix (raw references are plain strings in frontmatter, not wikilinks)
```

In Check 3 (Orphaned Articles), add:
```markdown
- Include workspace files in orphan detection — workspace files with zero inbound links should be reported
```

In Check 5 (Stale Content), add:
```markdown
- Skip workspace files (they don't have `last_verified` or `decay_rate` fields)
```

- [ ] **Step 5: Create /index skill**

Create new file `.claude/skills/index/SKILL.md`:

```markdown
---
name: index
description: Scan wiki/ and regenerate _index.md and _backlinks.md to include all content
---

# Index

Scan all content in `wiki/` (KB articles + workspace content) and regenerate the master index and backlinks files. Non-destructive — only reads content and rewrites `_index.md` and `_backlinks.md`.

## Prerequisites

Before starting, run Step 0: Verify Wiki Structure as described in `_meta/prompts/structure-check.md`. If any required paths are missing, recreate them before proceeding.

## Input

- No arguments required
- Example: `/index`

## When to Use

- After manually creating or modifying workspace content (notes, drafts, etc.)
- After any operation where `_index.md` may be out of sync with actual files
- As a standalone reindex without recompiling

## Context Loading

1. Read `_meta/wiki.config.yaml` — domain context
2. Read `_meta/schemas/frontmatter.yaml` — field definitions

## Steps

### Step 1: Scan Wiki Directory

Find all `.md` files recursively in `wiki/`. Exclude:
- `wiki/_index.md` (this is what we're regenerating)
- `wiki/_backlinks.md` (this is what we're regenerating)
- Any files in `wiki/.obsidian/`

### Step 2: Read Frontmatter

For each file found, read its YAML frontmatter. Extract:
- `title` (required — skip file with warning if missing)
- `type` (for KB articles: concept, person, tool, source-summary)
- `summary` (optional — use title if absent)
- All `[[wikilinks]]` in the file body

### Step 3: Regenerate _index.md

Follow the format defined in `_meta/prompts/index-update.md`:
- Group KB articles by type section (Concepts, People, Tools, Sources)
- Group workspace files under Workspaces section, sub-grouped by workspace name
- Sort entries alphabetically within each section
- One line per article: `- [[path|Title]] — summary`

### Step 4: Regenerate _backlinks.md

Follow the format defined in `_meta/prompts/index-update.md`:
- For each file in `wiki/`, find all other files that contain a `[[wikilink]]` pointing to it
- Include cross-zone references (workspace → KB, KB → workspace)
- Sort sections alphabetically

### Step 5: Report

Print summary:

```
Index updated. X KB articles, Y workspace files indexed.
```

## Important Rules

- This skill is non-destructive — it only writes `_index.md` and `_backlinks.md`
- Never modify any article content or frontmatter
- Include ALL files in `wiki/` regardless of zone (KB or workspace)
- For workspace files without `summary`, use the title as the index entry
```

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/
git commit -m "feat: update all skills for wiki/ vault structure

- compile: wiki/ paths, plain string sources, workspace-aware index
- rebuild: scoped wipe (4 KB dirs only), workspace-safe
- ingest: wiki/_index.md context loading
- lint: wiki/ paths, workspace light validation
- index: new skill for standalone reindexing"
```

---

### Task 4: Update hooks

**Files:**
- Modify: `hooks/pre-commit.sh`
- Modify: `hooks/token-count.sh`

- [ ] **Step 1: Rewrite pre-commit.sh**

Replace entire content of `hooks/pre-commit.sh` with:

```bash
#!/usr/bin/env bash
# Echo Wiki — Pre-commit Hook
# Validates structural integrity of wiki/ markdown files.
# Install: ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
# Escape: git commit --no-verify
set -euo pipefail

WIKI_ROOT="$(git rev-parse --show-toplevel)"
ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

# --- Helpers ---

# Extract YAML frontmatter (text between first and second --- lines)
frontmatter() {
    awk 'BEGIN{c=0}/^---$/{c++;next}c==1{print}c==2{exit}' "$1"
}

# --- Phase 0: Structure integrity check ---

PROTECTED_PATHS=(
  "wiki/_index.md"
  "wiki/_backlinks.md"
  "wiki/concepts"
  "wiki/people"
  "wiki/tools"
  "wiki/sources"
  "wiki/workspaces"
)

for path in "${PROTECTED_PATHS[@]}"; do
  if [ ! -e "$WIKI_ROOT/$path" ]; then
    echo "BLOCKED: '$path' is missing. This path is required by the wiki system." >> "$ERR_FILE"
    echo "  If you renamed or deleted it, restore it or run a skill to recreate it." >> "$ERR_FILE"
  fi
done

if [ -s "$ERR_FILE" ]; then
    echo "Pre-commit validation failed:"
    echo ""
    sed 's/^/  - /' "$ERR_FILE"
    echo ""
    echo "Restore missing paths or use 'git commit --no-verify' for WIP commits."
    exit 1
fi

# --- Get staged wiki files ---

STAGED_KB=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '^wiki/(concepts|people|tools|sources)/.*\.md$' || true)
STAGED_WS=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '^wiki/workspaces/.*\.md$' || true)

if [ -z "$STAGED_KB" ] && [ -z "$STAGED_WS" ]; then
    exit 0
fi

# --- Phase 1: KB file validation (full schema) ---

for file in $STAGED_KB; do
    fp="$WIKI_ROOT/$file"
    bn=$(basename "$file")

    # Skip structural files (they have their own format)
    [[ "$bn" == _index.md || "$bn" == _backlinks.md ]] && continue

    # Check frontmatter opens
    if ! head -1 "$fp" | grep -q '^---$'; then
        echo "$file: missing frontmatter" >> "$ERR_FILE"
        continue
    fi

    # Check frontmatter closes
    if [ "$(grep -c '^---$' "$fp")" -lt 2 ]; then
        echo "$file: unclosed frontmatter" >> "$ERR_FILE"
        continue
    fi

    fm=$(frontmatter "$fp")

    # Required fields: title, type, created, summary, sources
    for field in title type created summary sources; do
        if ! echo "$fm" | grep -q "^${field}:"; then
            echo "$file: missing required field '$field'" >> "$ERR_FILE"
        fi
    done

    # Validate type enum
    type_val=$(echo "$fm" | grep '^type:' | head -1 | sed 's/^type:[[:space:]]*//' | tr -d "\"'" | xargs 2>/dev/null || true)
    if [ -n "$type_val" ]; then
        case "$type_val" in
            concept|person|tool|source-summary) ;;
            *) echo "$file: invalid type '$type_val' (expected: concept|person|tool|source-summary)" >> "$ERR_FILE" ;;
        esac
    fi

    # Check sources is non-empty (handles inline and multi-line YAML arrays)
    sources_ok=$(echo "$fm" | awk '
        /^sources:/ {
            val = $0; sub(/^sources:[[:space:]]*/, "", val)
            if (val ~ /\[.+\]/) { print "ok"; exit }
            if (val == "" || val == "[]") { need_items = 1; next }
            print "ok"; exit
        }
        need_items && /^[[:space:]]+-/ { print "ok"; exit }
        need_items && /^[^[:space:]]/ { exit }
    ')
    [ "$sources_ok" != "ok" ] && echo "$file: sources list is empty" >> "$ERR_FILE"
done

# --- Phase 1b: Workspace file validation (light schema) ---

for file in $STAGED_WS; do
    fp="$WIKI_ROOT/$file"
    bn=$(basename "$file")

    # Check frontmatter opens
    if ! head -1 "$fp" | grep -q '^---$'; then
        echo "$file: missing frontmatter" >> "$ERR_FILE"
        continue
    fi

    # Check frontmatter closes
    if [ "$(grep -c '^---$' "$fp")" -lt 2 ]; then
        echo "$file: unclosed frontmatter" >> "$ERR_FILE"
        continue
    fi

    fm=$(frontmatter "$fp")

    # Required fields for workspace: title, created
    for field in title created; do
        if ! echo "$fm" | grep -q "^${field}:"; then
            echo "$file: missing required field '$field'" >> "$ERR_FILE"
        fi
    done
done

# --- Phase 2: Wikilink resolution ---

ALL_STAGED="$STAGED_KB $STAGED_WS"

for file in $ALL_STAGED; do
    fp="$WIKI_ROOT/$file"

    # Extract all [[link]] and [[link|alias]] patterns
    grep -oE '\[\[[^]]+\]\]' "$fp" 2>/dev/null | sed 's/\[\[//;s/\]\]//;s/|.*//' | sort -u | while IFS= read -r link; do
        [ -z "$link" ] && continue

        # All wikilinks resolve within wiki/
        target="$WIKI_ROOT/wiki/${link}.md"

        if [ ! -f "$target" ]; then
            echo "$file: broken wikilink [[$link]]" >> "$ERR_FILE"
        fi
    done
done

# --- Report ---

if [ -s "$ERR_FILE" ]; then
    echo "Pre-commit validation failed:"
    echo ""
    sed 's/^/  - /' "$ERR_FILE"
    echo ""
    echo "Fix errors or use 'git commit --no-verify' for WIP commits."
    exit 1
fi

echo "Pre-commit validation passed"
```

- [ ] **Step 2: Update token-count.sh**

Replace entire content of `hooks/token-count.sh` with:

```bash
#!/usr/bin/env bash
# Echo Wiki — Token Count Estimator
# Counts words across raw/ and wiki/, estimates tokens (words x 1.3).
# Usage: ./hooks/token-count.sh
# Also usable as post-commit hook (informational, never blocks).
set -euo pipefail

WIKI_ROOT="$(git rev-parse --show-toplevel)"
DATE=$(date +%Y-%m-%d)

count_words() {
    find "$1" -name '*.md' -type f -exec cat {} + 2>/dev/null | wc -w | tr -d ' '
}

RAW_WORDS=$(count_words "$WIKI_ROOT/raw")
WIKI_WORDS=$(count_words "$WIKI_ROOT/wiki")
TOTAL_WORDS=$((RAW_WORDS + WIKI_WORDS))

RAW_TOKENS=$((RAW_WORDS * 13 / 10))
WIKI_TOKENS=$((WIKI_WORDS * 13 / 10))
TOTAL_TOKENS=$((TOTAL_WORDS * 13 / 10))

# Calculate percentage of 1M context window
if [ "$TOTAL_TOKENS" -eq 0 ]; then
    PCT="0.0"
else
    PCT=$(echo "scale=1; $TOTAL_TOKENS * 100 / 1000000" | bc)
    [[ "$PCT" == .* ]] && PCT="0$PCT"
fi

OUTPUT="[$DATE] Wiki Token Estimate
  raw/        $RAW_WORDS words  ~  $RAW_TOKENS tokens
  wiki/       $WIKI_WORDS words  ~  $WIKI_TOKENS tokens
  TOTAL       $TOTAL_WORDS words  ~  $TOTAL_TOKENS tokens

  Context usage: ~${PCT}% of 1M window"

echo "$OUTPUT"

# Append to log (git-ignored)
LOG_DIR="$WIKI_ROOT/output/reports"
mkdir -p "$LOG_DIR"
echo "$OUTPUT" >> "$LOG_DIR/token-count.log"
echo "" >> "$LOG_DIR/token-count.log"
```

- [ ] **Step 3: Commit**

```bash
git add hooks/
git commit -m "feat: update hooks for wiki/ vault structure

- pre-commit: Phase 0 structure guard, KB/workspace split validation,
  simplified wikilink resolution (all resolve within wiki/)
- token-count: compiled/ → wiki/ paths and labels"
```

---

### Task 5: Update instruction files and .gitignore

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `GEMINI.md`
- Modify: `.gitignore`

- [ ] **Step 1: Update CLAUDE.md**

Replace entire content of `CLAUDE.md` with:

```markdown
# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for wiki configuration.

## Skills

- `/ingest <url-or-path>` — Fetch source content, save to `raw/`
- `/compile <path|all>` — Compile raw sources into wiki articles in `wiki/`
- `/rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `/index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `/lint [scope]` — Semantic validation, report to `output/reports/`

## Rules

1. **KB type directories are LLM-only.** Write to `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/` via `/compile` or `/rebuild` only. Never edit directly.
2. **`raw/` is append-only during normal operation.** Do not modify or delete sources as part of `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`.
3. **Workspaces are actor-managed.** `wiki/workspaces/<name>/` directories are owned by their creator (human or agent). Skills never modify workspace content.
4. **Frontmatter required** on all files. Schema: `_meta/schemas/frontmatter.yaml`. KB articles use full schema; workspace files use light schema.
5. **Wikilinks** for all cross-references between articles: `[[concepts/name|Display Name]]`
6. **Sources field** uses plain strings (not wikilinks): `sources: ["raw/blogs/foo.md"]`
7. **Tags** must match domains defined in `_meta/wiki.config.yaml`
8. **Filenames** are kebab-case, max 60 characters, `.md` extension.

## Progressive Context Loading

Load incrementally — never load the entire wiki at once:

| Level | Load | When |
|---|---|---|
| L0 | `wiki/_index.md` | Always start here |
| L1 | `wiki/_backlinks.md` | Resolving cross-references |
| L2 | Specific `wiki/<type>/<article>.md` | Working on specific topics |
| L3 | Specific `raw/<category>/<source>.md` | During ingest/compile only |

## Handling Queries

No skill needed. When the user asks a question:
1. Read `wiki/_index.md` to find relevant articles
2. Read those specific articles
3. Synthesize an answer from wiki content
4. Optionally save result to `output/reports/`

## Validation

- **Pre-commit hook** runs automatically — validates frontmatter, wikilinks, and structure integrity
- **`/lint`** for deeper semantic checks (contradictions, staleness, orphans)
- **`./hooks/token-count.sh`** to check wiki size anytime
```

- [ ] **Step 2: Update AGENTS.md**

Replace entire content of `AGENTS.md` with:

```markdown
# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.claude/skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `wiki/`
- `rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `lint` — Semantic validation, report to `output/reports/`

## Key Rules

- KB type directories (`wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) are LLM-maintained only — never edit manually
- `wiki/workspaces/` is for actor-created content (human or agent) — skills never modify workspace content
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Use `[[wikilinks]]` for cross-references between articles; use plain strings for `sources:` field
- Load context progressively: `wiki/_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
```

- [ ] **Step 3: Update GEMINI.md**

Replace entire content of `GEMINI.md` with the same content as `AGENTS.md` (identical file):

```markdown
# Echo Wiki

LLM-maintained knowledge base. Read `_meta/wiki.config.yaml` for configuration.

## Skills

Skill definitions in `.claude/skills/`:
- `ingest` — Fetch source content, save to `raw/`
- `compile` — Compile raw sources into wiki articles in `wiki/`
- `rebuild` — Wipe KB type directories and recompile from all remaining raw sources
- `index` — Rescan `wiki/` and regenerate `_index.md` and `_backlinks.md`
- `lint` — Semantic validation, report to `output/reports/`

## Key Rules

- KB type directories (`wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`) are LLM-maintained only — never edit manually
- `wiki/workspaces/` is for actor-created content (human or agent) — skills never modify workspace content
- `raw/` is append-only during normal operation — do not modify or delete via `/ingest` or `/compile`. To remove a source, delete the raw file manually, then run `/rebuild`
- All files require YAML frontmatter (see `_meta/schemas/frontmatter.yaml`)
- Use `[[wikilinks]]` for cross-references between articles; use plain strings for `sources:` field
- Load context progressively: `wiki/_index.md` first, then specific articles as needed
- Tags must match domains in `_meta/wiki.config.yaml`
- Filenames: kebab-case, max 60 characters
```

- [ ] **Step 4: Update .gitignore**

In `.gitignore`, replace the Obsidian section:

Old:
```
# Obsidian workspace (user-specific UI state)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/core-plugins.json
.obsidian/community-plugins.json
.obsidian/hotkeys.json
.obsidian/plugins/
```

New:
```
# Obsidian workspace (user-specific UI state)
wiki/.obsidian/workspace.json
wiki/.obsidian/workspace-mobile.json
wiki/.obsidian/core-plugins.json
wiki/.obsidian/community-plugins.json
wiki/.obsidian/hotkeys.json
wiki/.obsidian/plugins/
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md AGENTS.md GEMINI.md .gitignore
git commit -m "feat: update instruction files and .gitignore for wiki/ vault

- CLAUDE.md: wiki/ paths, workspace rules, /index skill, plain string sources
- AGENTS.md/GEMINI.md: same updates
- .gitignore: Obsidian paths → wiki/.obsidian/"
```

---

### Task 6: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README.md**

Replace entire content of `README.md` with:

```markdown
# Echo Wiki

A generic, LLM-maintained knowledge base system. Ingest sources, compile a structured wiki, browse in Obsidian. Works with any domain — AI research, finance, healthcare, marketing, or anything else.

> **[Read the docs](https://echotheorylabsai.github.io/echo-wiki/)** for full setup guide, configuration reference, and usage examples.

## How It Works

```
  URLs / Files / PDFs
         |
         v
  +--------------+
  |   /ingest    |  Fetch + clean source -> raw/
  +--------------+
         |
         v
  +--------------+
  |   /compile   |  Extract entities, build articles -> wiki/
  +--------------+
         |
         v
  +--------------+
  |  /rebuild    |  Wipe KB dirs, replay all sources (after deletion)
  +--------------+
         |
         v
  +--------------+
  |   Obsidian   |  Browse, graph view, backlinks
  +--------------+
```

**The LLM writes all wiki content.** You provide sources, the LLM maintains `wiki/`. You never edit KB articles directly — just read them in Obsidian. You can create your own notes and drafts in `wiki/workspaces/`.

```
raw/                          wiki/ (Obsidian vault)
├── blogs/                    ├── _index.md        <- Master index
│   └── source-article.md    ├── _backlinks.md    <- Cross-reference map
├── papers/                   ├── concepts/        <- Ideas & theories
├── people/                   │   └── topic.md
├── substacks/                ├── people/          <- Key figures
├── github/                   │   └── person.md
└── media/                    ├── tools/           <- Software & platforms
                              │   └── tool.md
                              ├── sources/         <- Source summaries
                              │   └── summary.md
                              └── workspaces/      <- Actor workspaces
                                  └── my-notes/    <- Your notes
```

## Quick Start

```bash
# 1. Clone
git clone <repo-url> my-wiki && cd my-wiki

# 2. Set up environment
cp .env.example .env
# Edit .env — add your API keys

# 3. Configure your domain
# Edit _meta/wiki.config.yaml — set name, description, domains

# 4. Install hooks
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit

# 5. Open in Obsidian
# File > Open folder as vault > select the wiki/ directory

# 6. Ingest your first source
/ingest https://example.com/article
```

## Configuration

All customization lives in one file: `_meta/wiki.config.yaml`

```yaml
wiki:
  name: "My Wiki"
  description: "What this wiki is about"

domains:
  - name: "topic"
    label: "Topic Label"

vault:
  dir: wiki
  default_workspace: my-notes

defaults:
  decay_rate: medium    # fast | medium | slow
  confidence: medium    # high | medium | speculative
```

See `.env.example` for required API keys.

## Core Operations

| Command | What it does |
|---|---|
| `/ingest <url>` | Fetch URL, save clean markdown to `raw/` |
| `/ingest <path>` | Import local file (md, pdf) to `raw/` |
| `/compile <path>` | Compile raw source into wiki articles |
| `/compile all` | Recompile entire wiki |
| `/rebuild` | Wipe KB dirs, recompile from all remaining raw sources |
| `/index` | Rescan `wiki/` and update `_index.md` and `_backlinks.md` |
| `/lint` | Run semantic checks, produce report |
| `/lint all` | Lint entire wiki |

## Workspaces

Users and agents can create content alongside KB articles in `wiki/workspaces/`:

```
wiki/workspaces/
├── my-notes/              <- Default human workspace (ships with template)
│   ├── research-log.md
│   └── todo.md
├── content-creator/       <- Agent workspace (created on demand)
│   └── drafts/
└── social-media/          <- Agent workspace
    └── drafts/
```

- **Zero registration** — just create a directory under `workspaces/`
- **Agents and humans are peers** — same structure, same rules
- **Cross-zone wikilinks** — workspace notes can link to KB articles and vice versa
- **Rebuild-safe** — `/rebuild` never touches `workspaces/`
- Run `/index` after creating workspace content to update the master index

## Data Flow

```
                    /ingest
                       |
    URL -----> [Tavily/Firecrawl] -----> raw/<category>/<source>.md
    File ----> [copy + frontmatter] --/        |
                                               |
                    /compile                   |
                       |                       |
    raw source --------+                       |
         |                                     |
         v                                     |
    Extract: concepts, people, tools           |
         |                                     |
         v                                     |
    For each entity:                           |
      exists? --> MERGE (add info, keep old)   |
      new?    --> CREATE (full frontmatter)     |
         |                                     |
         v                                     |
    Update _index.md + _backlinks.md           |
         |                                     |
         v                                     |
    wiki/ <-- ready for Obsidian               |
                                               |
                    /rebuild                    |
                       |                       |
    [delete raw] --> wipe KB dirs --> replay all sources chronologically
                     (workspaces preserved)
```

## Validation

**Pre-commit hook (automatic):**
- Structure integrity — protected paths must exist
- KB articles: frontmatter, required fields, type enum, wikilinks, sources
- Workspace files: frontmatter, title, created

**Semantic lint (`/lint`, on-demand):**
- Contradictory claims across articles
- Stale content past decay thresholds
- Orphaned articles (no inbound links)
- Missing concepts (referenced but no article)
- Duplicate concepts under different names

**Token count (post-commit, informational):**
```bash
./hooks/token-count.sh    # Run manually anytime
# Also runs after each commit (never blocks)
```

## Directory Structure

```
echo-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only, backend)
├── wiki/                      # Obsidian vault (user-facing)
│   ├── concepts/              # KB: ideas, theories, patterns
│   ├── people/                # KB: key figures
│   ├── tools/                 # KB: software, platforms
│   ├── sources/               # KB: source summaries
│   ├── workspaces/            # Actor workspaces (human + agent)
│   │   └── my-notes/          # Default human workspace
│   ├── _index.md              # Master index
│   └── _backlinks.md          # Cross-reference map
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # pre-commit.sh, token-count.sh
├── .claude/skills/            # Agent Skills (ingest, compile, rebuild, lint, index)
├── docs/                      # VitePress documentation site
├── .env.example               # API key template
├── CLAUDE.md                  # Claude Code instructions
└── README.md
```

## Provider Support

Echo Wiki uses the [Agent Skills](https://agentskills.io) open standard. Works with:

- **Claude Code** — via CLAUDE.md + .claude/skills/
- **Codex CLI** — via AGENTS.md + .claude/skills/
- **Gemini CLI** — via GEMINI.md + .claude/skills/
- **Any Agent Skills-compatible agent**

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for wiki/ vault structure and workspaces"
```

---

### Task 7: Update VitePress docs

**Files:**
- Modify: `docs/index.md`
- Modify: `docs/getting-started.md`
- Modify: `docs/skills.md`
- Modify: `docs/schema.md`
- Modify: `docs/obsidian.md`
- Modify: `docs/configuration.md`
- Modify: `docs/validation.md`
- Modify: `docs/providers.md`

- [ ] **Step 1: Update docs/index.md**

In `docs/index.md`, update the features section — replace the "Obsidian-Native" feature details:

Old:
```yaml
  - title: Obsidian-Native
    details: Browse your wiki in Obsidian with graph view, backlinks, and wikilink navigation. Pre-configured vault with color-coded node types.
```

New:
```yaml
  - title: Obsidian-Native
    details: Browse your wiki in Obsidian with graph view, backlinks, and wikilink navigation. Clean vault showing only your knowledge base and workspaces — no backend clutter.
```

In the "How It Works" code block, replace all `compiled/` with `wiki/`. Replace the diagram:

Old:
```
  |   /compile   |  Extract entities, build articles → compiled/
```
New:
```
  |   /compile   |  Extract entities, build articles → wiki/
```

Old:
```
  |  /rebuild    |  Wipe compiled/, replay all sources (after deletion)
```
New:
```
  |  /rebuild    |  Wipe KB dirs, replay all sources (after deletion)
```

Replace the descriptive paragraph:
Old:
```
The LLM writes all wiki content. You provide sources, the LLM maintains `compiled/`. You never edit `compiled/` directly — just read it in Obsidian.
```
New:
```
The LLM writes all wiki content. You provide sources, the LLM maintains `wiki/`. You never edit KB articles directly — just read them in Obsidian. Create your own notes in `wiki/workspaces/`.
```

- [ ] **Step 2: Update docs/getting-started.md**

Replace entire content of `docs/getting-started.md` with:

```markdown
# Getting Started

## Prerequisites

- An LLM agent that supports [Agent Skills](https://agentskills.io) (Claude Code, Codex CLI, Gemini CLI, etc.)
- [Obsidian](https://obsidian.md) for browsing the wiki
- (Optional) [Firecrawl](https://firecrawl.dev) API key for advanced web scraping

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/echotheorylabsai/echo-wiki.git my-wiki
cd my-wiki
```

### 2. Set up environment

```bash
cp .env.example .env
# Edit .env — add your API keys
```

### 3. Configure your domain

Edit `_meta/wiki.config.yaml` — set your wiki name, description, and knowledge domains:

```yaml
wiki:
  name: "My Research Wiki"
  description: "Knowledge base for..."

domains:
  - name: "topic-1"
    label: "First Topic"
  - name: "topic-2"
    label: "Second Topic"
    decay_rate_override: fast  # optional
```

See [Configuration](/configuration) for full reference.

### 4. Install hooks

```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit
```

### 5. Open in Obsidian

Open Obsidian → File → Open folder as vault → select the **`wiki/`** directory (not the repo root).

The vault comes pre-configured with:
- Wikilinks enabled
- Graph view color groups (concepts=blue, people=green, tools=orange, sources=gray, workspaces=purple)
- Frontmatter display
- A default `workspaces/my-notes/` directory for your personal notes

### 6. Ingest your first source

```
/ingest https://example.com/article
```

The agent will fetch the content, save it to `raw/`, then compile it into wiki articles in `wiki/`.

## Directory Structure

```
my-wiki/
├── _meta/
│   ├── wiki.config.yaml      # Your wiki configuration
│   ├── prompts/               # Reference docs for each operation
│   └── schemas/               # Frontmatter validation schema
├── raw/                       # Source documents (append-only, backend)
├── wiki/                      # Obsidian vault (user-facing)
│   ├── concepts/              # KB: compiled articles
│   ├── people/
│   ├── tools/
│   ├── sources/
│   ├── workspaces/            # Your notes + agent workspaces
│   │   └── my-notes/          # Default human workspace
│   ├── _index.md              # Master index
│   └── _backlinks.md          # Cross-reference map
├── output/reports/            # Lint reports, query results, token counts
├── hooks/                     # pre-commit.sh, token-count.sh
├── .claude/skills/            # Agent Skills (ingest, compile, rebuild, lint, index)
├── docs/                      # VitePress documentation site
├── .env.example               # API key template
├── CLAUDE.md                  # Claude Code instructions
└── README.md
```

## What's Next?

- [Configure your domains](/configuration) for your specific use case
- [Learn about the skills](/skills) — ingest, compile, rebuild, lint, and index
- [Set up validation](/validation) — pre-commit hooks and semantic linting
- Create notes in `wiki/workspaces/my-notes/` and run `/index` to include them
```

- [ ] **Step 3: Update docs/skills.md**

Replace entire content of `docs/skills.md` with:

```markdown
# Skills

Echo Wiki uses [Agent Skills](https://agentskills.io) to manage the wiki pipeline. Skills are stored in `.claude/skills/` and work with any compatible agent.

All skills run a structure check (Step 0) before starting. If any required wiki paths are missing, the skill recreates them automatically. See `_meta/prompts/structure-check.md` for details.

## /ingest

**Fetch and clean source content into `raw/`.**

```
/ingest <url>           # Ingest a web URL
/ingest <file-path>     # Ingest a local file (md, pdf)
```

What it does:
1. Detects source type from URL pattern (blog, substack, github, paper, tweet)
2. Fetches content via Tavily or Firecrawl
3. Downloads images locally
4. Writes clean markdown with frontmatter to `raw/`
5. Automatically triggers `/compile`

**Source type detection:**

| URL Pattern | Type | Directory |
|---|---|---|
| `*.substack.com/*` | substack | `raw/substacks/` |
| `github.com/*` | github | `raw/github/` |
| `twitter.com/*`, `x.com/*` | tweet | `raw/people/` |
| `arxiv.org/*`, `*.pdf` | paper | `raw/papers/` |
| Other URLs | blog | `raw/blogs/` |
| Podcasts / videos | — | User must specify type |

## /compile

**Compile raw sources into structured wiki articles.**

```
/compile raw/blogs/article.md    # Compile a specific source
/compile all                      # Recompile entire wiki
```

What it does:
1. Reads raw source(s)
2. Creates source-summary in `wiki/sources/`
3. Extracts concepts, people, and tools
4. Creates new articles or merges into existing ones (never overwrites)
5. Adds `[[wikilinks]]` between related articles
6. Regenerates `_index.md` and `_backlinks.md` (includes workspace content)

**Four KB categories:**

| Type | Directory | Examples |
|---|---|---|
| Concepts | `wiki/concepts/` | Ideas, theories, patterns |
| People | `wiki/people/` | Researchers, authors, key figures |
| Tools | `wiki/tools/` | Software, platforms, frameworks |
| Sources | `wiki/sources/` | Summary of each raw source |

## /rebuild

**Wipe KB type directories and recompile from all remaining raw sources.**

```
/rebuild
```

Use this after manually deleting one or more raw source files. The `/compile` skill only appends and merges — it cannot remove content from deleted sources. `/rebuild` starts fresh and recompiles only from sources that still exist.

What it does:
1. Collects all remaining raw sources (`raw/**/*.md`)
2. If no sources found, aborts safely — KB directories are **not** wiped
3. Deletes all files in KB type directories (`wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`)
4. **Preserves `wiki/workspaces/` and `wiki/.obsidian/`** — workspace content is never touched
5. Replays each source chronologically (`ingested` date, oldest first) using the compile workflow
6. Regenerates `_index.md` and `_backlinks.md` (includes preserved workspace content)

**Removing a source from the wiki:**

```bash
# 1. Delete the raw source file
rm raw/substacks/outdated-article.md

# 2. Rebuild to reconcile
/rebuild
```

After rebuild, all articles unique to the deleted source are gone, and multi-source articles are rewritten without the deleted source's content. Workspace content is untouched.

::: tip
`raw/` is append-only during normal operations (`/ingest` and `/compile` never modify existing raw files). Only delete raw files as a deliberate manual action before running `/rebuild`.
:::

## /index

**Rescan `wiki/` and update `_index.md` and `_backlinks.md`.**

```
/index
```

Use this after manually creating or modifying workspace content (notes, drafts, etc.) to update the master index.

What it does:
1. Scans all `.md` files in `wiki/` (KB articles + workspace content)
2. Regenerates `_index.md` with all entries grouped by type and workspace
3. Regenerates `_backlinks.md` with cross-zone references

This is a non-destructive operation — it only reads content and rewrites the two index files.

## /lint

**Run semantic validation checks on the wiki.**

```
/lint                    # Lint entire wiki
/lint wiki/concepts/     # Lint specific directory
```

Produces a report at `output/reports/lint-<date>.md` with 7 checks:

1. **Frontmatter validation** — required fields, valid enums, type-specific fields (KB: full schema, workspaces: light schema)
2. **Broken wikilinks** — every `[[link]]` must resolve to a real file within `wiki/`
3. **Orphaned articles** — no inbound links
4. **Contradictory claims** — conflicting facts across related KB articles
5. **Stale content** — past decay rate threshold (KB articles only)
6. **Missing concepts** — topics mentioned in 3+ articles without their own article
7. **Duplicate detection** — same entity under different names
```

- [ ] **Step 4: Update docs/schema.md**

Replace entire content of `docs/schema.md` with:

```markdown
# Frontmatter Schema

Every file in `wiki/` requires YAML frontmatter. The schema is defined at `_meta/schemas/frontmatter.yaml`.

## KB Articles (Full Schema)

Files in `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`:

```yaml
---
title: "Article Title"
type: concept | person | tool | source-summary
created: 2026-04-04
last_updated: 2026-04-04
last_verified: 2026-04-04
decay_rate: fast | medium | slow
confidence: high | medium | speculative
tags: ["domain-1", "domain-2"]
sources: ["raw/blogs/source.md"]
related: ["[[concepts/related]]"]
summary: "One-line summary for index"
---
```

**Note:** The `sources` field uses plain strings (raw file paths), not `[[wikilinks]]`. This is because `raw/` is outside the Obsidian vault.

## Type-Specific Fields

| Type | Extra Fields |
|---|---|
| `concept` | `domain`, `prerequisites` |
| `person` | `role`, `affiliations`, `follows` |
| `tool` | `category` (framework/platform/service/product), `repo`, `maintained` |
| `source-summary` | `source_url`, `source_type`, `author`, `source_date` |

## Workspace Files (Light Schema)

Files in `wiki/workspaces/`:

```yaml
---
title: "My Research Notes"
created: 2026-04-05
author: "shubh"
tags: ["ai"]
---
```

Only `title`, `created`, `author`, and `tags` are required. Optional fields: `summary`, `related`, `sources`.

## Raw Source Frontmatter

Files in `raw/` use a simpler schema:

```yaml
---
title: "Source Title"
source_url: "https://..."
source_type: blog | paper | tweet | substack | github | podcast | video
source_date: 2026-04-01
author: "Author Name"
ingested: 2026-04-04
ingestion_tool: tavily | firecrawl | local
tags: ["domain-1"]
---
```

## Confidence Levels

| Level | Definition |
|---|---|
| `high` | Well-sourced from multiple references or authoritative primary sources |
| `medium` | Single source, or well-known but not independently verified |
| `speculative` | Inferred, opinion-based, from unverified sources, or emerging claims |

## Filename Convention

- Kebab-case, derived from article title
- Max 60 characters
- `.md` extension
- Examples: `model-context-protocol.md`, `andrej-karpathy.md`
```

- [ ] **Step 5: Update docs/obsidian.md**

Replace entire content of `docs/obsidian.md` with:

```markdown
# Obsidian Integration

Echo Wiki is designed to be browsed in [Obsidian](https://obsidian.md) as a local vault.

## Setup

1. Install Obsidian from [obsidian.md](https://obsidian.md)
2. Open Obsidian → File → Open folder as vault
3. Select the **`wiki/`** directory (not the repo root)

The vault comes pre-configured in `wiki/.obsidian/`:

## Pre-configured Settings

- **Wikilinks enabled** — `[[concept-name|Display Name]]` links work out of the box
- **Shortest path linking** — `[[concepts/mcp-protocol]]` resolves via suffix matching
- **Frontmatter display** — YAML metadata visible in reading view
- **Clean sidebar** — only KB articles and workspaces visible, no backend files

## Graph View

The graph view is color-coded by content type:

| Type | Color | Query |
|---|---|---|
| Concepts | Blue | `path:concepts` |
| People | Green | `path:people` |
| Tools | Orange | `path:tools` |
| Sources | Gray | `path:sources` |
| Workspaces | Purple | `path:workspaces` |

Open graph view: Ctrl/Cmd + G

## Workspaces

The `workspaces/` directory is where you (and agents) create content:

- **`my-notes/`** ships as the default human workspace
- Agents create their own workspace directories on demand (e.g., `workspaces/content-creator/`)
- Workspace content uses a light frontmatter schema (just `title`, `created`, `author`, `tags`)
- Run `/index` after creating workspace content to include it in the master index
- Workspace content is never touched by `/rebuild`

## Recommended Plugins

These are optional but enhance the experience:

- **Graph View** (built-in) — visualize article connections
- **Backlinks** (built-in) — see which articles link to the current one
- **Obsidian Git** — sync wiki changes via git
- **Dataview** — query articles by frontmatter fields

## Tips

- Use `_index.md` as your starting point — it lists all articles with summaries
- Click any `[[wikilink]]` to navigate between articles
- Use the backlinks panel (right sidebar) to discover connections
- The graph view shows the overall structure of your knowledge base
- Workspace notes can link to KB articles with `[[concepts/foo|Foo]]`
```

- [ ] **Step 6: Update docs/configuration.md**

In `docs/configuration.md`, add after the `defaults:` block in the Full Schema section and before `schema_version: 1`:

```yaml
vault:
  dir: wiki                       # Directory used as Obsidian vault
  default_workspace: my-notes     # Pre-created workspace for human user
```

Add a new section after "## Environment Variables":

```markdown
## Vault

The `vault` section configures the Obsidian-facing directory:

| Field | Default | Description |
|---|---|---|
| `dir` | `wiki` | Directory name for the Obsidian vault |
| `default_workspace` | `my-notes` | Pre-created workspace for human users |
```

- [ ] **Step 7: Update docs/validation.md**

Replace entire content of `docs/validation.md` with:

```markdown
# Validation & Linting

Echo Wiki uses two layers of validation: a structural pre-commit hook (no LLM required) and a semantic lint skill (LLM-powered).

## Pre-commit Hook

Automatically runs on every commit. Blocks commits with structural errors.

**Install:**
```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

### Phase 0: Structure Guard

Before validating any files, the hook checks that all protected wiki paths exist:

| Protected Path | Purpose |
|---|---|
| `wiki/_index.md` | Master index |
| `wiki/_backlinks.md` | Cross-reference map |
| `wiki/concepts/` | KB type directory |
| `wiki/people/` | KB type directory |
| `wiki/tools/` | KB type directory |
| `wiki/sources/` | KB type directory |
| `wiki/workspaces/` | Actor workspace root |

If any path is missing, the commit is blocked with a clear message. Restore the path or run a skill (which auto-heals missing structure).

### KB Article Validation (Full Schema)

Files in `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`:

| Check | Method | Blocks commit? |
|---|---|---|
| Frontmatter exists | Regex for `---` header | Yes |
| Required fields present | `title`, `type`, `created`, `summary`, `sources` | Yes |
| `type` is valid enum | `concept \| person \| tool \| source-summary` | Yes |
| All `[[wikilinks]]` resolve | Target file must exist in `wiki/` | Yes |
| `sources:` is non-empty | At least one entry | Yes |

### Workspace Validation (Light Schema)

Files in `wiki/workspaces/`:

| Check | Method | Blocks commit? |
|---|---|---|
| Frontmatter exists | Regex for `---` header | Yes |
| `title` present | Field check | Yes |
| `created` present | Field check | Yes |
| All `[[wikilinks]]` resolve | Target file must exist in `wiki/` | Yes |

**Escape hatch:** `git commit --no-verify` for WIP commits.

## Skill Self-Healing

Every skill runs a structure check (Step 0) before any work. If a required path is missing, the skill recreates it silently. This means you can always recover by running any skill — even if you accidentally deleted a directory.

## Semantic Lint

Run on-demand via `/lint`. Requires an LLM agent. Produces detailed reports.

See [Skills → /lint](/skills#lint) for the full list of 7 checks.

## Token Count

Track wiki size over time:

```bash
./hooks/token-count.sh    # Run manually
```

**Install as post-commit hook (informational, never blocks):**
```bash
ln -sf ../../hooks/token-count.sh .git/hooks/post-commit
```

Sample output:
```
[2026-04-05] Wiki Token Estimate
  raw/        12,400 words  ~  16,120 tokens
  wiki/        8,200 words  ~  10,660 tokens
  TOTAL       20,600 words  ~  26,780 tokens

  Context usage: ~2.7% of 1M window
```
```

- [ ] **Step 8: Update docs/providers.md**

In `docs/providers.md`, check for any references to `compiled/`. The current file references `.claude/skills/` paths and agent instruction files but no `compiled/` paths. Verify by running:

```bash
grep "compiled" docs/providers.md
```

Expected: zero matches. If any found, replace `compiled/` with `wiki/`. Otherwise no changes needed.

- [ ] **Step 9: Commit**

```bash
git add docs/
git commit -m "docs: update all VitePress docs for wiki/ vault and workspaces

- getting-started: open wiki/ as vault, updated directory tree
- skills: add /index, scoped rebuild, workspace-aware compile
- schema: workspace light schema, sources as plain strings
- obsidian: vault setup at wiki/, workspace guidance, updated graph colors
- configuration: vault config section
- validation: Phase 0 structure guard, workspace validation rules"
```

---

### Task 8: Delete old directories and final verification

**Files:**
- Delete: `compiled/` (entire directory)
- Delete: `.obsidian/` (at repo root)

- [ ] **Step 1: Delete old compiled/ directory**

```bash
git rm -r compiled/
```

- [ ] **Step 2: Delete old .obsidian/ at repo root**

```bash
git rm -r .obsidian/
```

- [ ] **Step 3: Verify no stale compiled/ references**

```bash
grep -r "compiled/" --include="*.md" --include="*.yaml" --include="*.sh" --include="*.yml" --include="*.json" . | grep -v "node_modules" | grep -v ".git/" | grep -v "docs/superpowers/specs/" | grep -v "docs/superpowers/plans/"
```

Expected: zero matches. If any found, fix them before committing.

- [ ] **Step 4: Verify wiki/ structure is complete**

```bash
find wiki -type f | sort
```

Expected:
```
wiki/.obsidian/app.json
wiki/.obsidian/appearance.json
wiki/.obsidian/graph.json
wiki/_backlinks.md
wiki/_index.md
wiki/concepts/.gitkeep
wiki/people/.gitkeep
wiki/sources/.gitkeep
wiki/tools/.gitkeep
wiki/workspaces/my-notes/.gitkeep
```

- [ ] **Step 5: Verify pre-commit hook works**

```bash
# Reinstall the hook
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit

# Test: commit should pass with no wiki changes staged
git add compiled/ .obsidian/  # staging the deletions
git commit -m "chore: remove old compiled/ and .obsidian/ directories

Replaced by wiki/ vault structure with dedicated Obsidian config."
```

- [ ] **Step 6: Run token count to verify**

```bash
./hooks/token-count.sh
```

Expected output should show `wiki/` label (not `compiled/`).

- [ ] **Step 7: Final grep for any remaining compiled/ references**

```bash
grep -rn "compiled/" --include="*.md" --include="*.yaml" --include="*.sh" --include="*.yml" --include="*.json" . | grep -v "node_modules" | grep -v ".git/" | grep -v "docs/superpowers/"
```

Expected: zero matches.
