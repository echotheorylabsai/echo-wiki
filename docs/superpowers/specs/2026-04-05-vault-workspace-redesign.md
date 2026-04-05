# Vault & Workspace Redesign

**Date:** 2026-04-05
**Status:** Draft
**Scope:** Directory restructure, Obsidian vault isolation, workspace model, skill updates, docs updates

## Problem

1. **Obsidian shows backend files.** The vault root is the repo root, so users see `_meta/`, `raw/`, `hooks/`, `CLAUDE.md`, `AGENTS.md`, and other system files in the Obsidian sidebar. Users only care about their research and work products.

2. **No space for user/agent-created content.** The system only supports the `raw/ -> compiled/` pipeline. Users and agents creating notes, drafts, todos, or other artifacts have no designated place.

3. **No change detection.** The system cannot detect new content that didn't go through `/ingest`.

4. **`compiled/` is not a user-friendly name.** It exposes an implementation detail.

## Design

### Directory Structure

```
echo-wiki/                             # repo root
├── _meta/
│   ├── wiki.config.yaml
│   ├── prompts/
│   └── schemas/
│       └── frontmatter.yaml
├── raw/                               # ingested sources (backend only, NOT in vault)
│   ├── blogs/
│   ├── papers/
│   ├── substacks/
│   ├── github/
│   ├── people/
│   └── media/
├── wiki/                              # Obsidian vault root
│   ├── .obsidian/                     # vault config (moved from repo root)
│   ├── concepts/                      # KB: compiled from raw
│   ├── people/                        # KB: compiled from raw
│   ├── tools/                         # KB: compiled from raw
│   ├── sources/                       # KB: compiled from raw
│   ├── workspaces/                    # actor workspaces
│   │   ├── my-notes/                  # default human workspace (ships with template)
│   │   │   └── .gitkeep
│   │   ├── <agent-name>/              # created on demand by agents
│   │   └── ...
│   ├── _index.md                      # master index (covers everything)
│   └── _backlinks.md                  # master backlinks (covers everything)
├── hooks/
├── output/
├── docs/
├── .claude/skills/
├── CLAUDE.md
├── AGENTS.md
├── GEMINI.md
├── README.md
└── package.json
```

### Two Zones Inside `wiki/`

**Knowledge Base (type directories):** `concepts/`, `people/`, `tools/`, `sources/`
- Auto-managed by the ingestion pipeline (`/ingest` -> `/compile`)
- `/rebuild` wipes only these 4 directories, then recompiles from `raw/`
- Full frontmatter schema required (title, type, created, confidence, sources, etc.)

**Workspaces:** `workspaces/<actor-name>/`
- Self-managed by their owner (human or agent)
- `/rebuild` never touches `workspaces/`
- Light frontmatter schema (title, created, author, tags)
- Internal structure is free-form (each actor organizes however they want)

### Default Human Workspace

The template ships with `wiki/workspaces/my-notes/` pre-created (with a `.gitkeep`). This makes it immediately obvious where users create their own content. Users can rename it or create additional workspace directories.

### Workspace Rules

- **Zero registration.** An actor writes files under `wiki/workspaces/<name>/`. If the directory doesn't exist, it's created on first write.
- **Internal structure is free-form.** Each workspace owner organizes however they want: `drafts/`, `notes/`, `tasks/`, `images/`, etc.
- **Agents and humans are peers.** Both get workspace directories under the same `workspaces/` parent. No structural distinction.
- **Cross-zone wikilinks work.** A workspace note can reference KB articles (`[[concepts/foo|Foo]]`), and vice versa.

### Raw Source References (Breaking Change)

**Problem:** Currently, the `sources:` frontmatter field in compiled articles uses wikilinks to raw files: `sources: ["[[raw/blogs/foo.md]]"]`. After moving the vault to `wiki/`, these wikilinks would try to resolve to `wiki/raw/blogs/foo.md` — which doesn't exist. `raw/` is outside the vault.

**Solution:** Change `sources:` from `list[wikilink]` to `list[string]`. Drop the `[[` `]]` brackets:

```yaml
# Before
sources: ["[[raw/blogs/some-article.md]]"]

# After
sources: ["raw/blogs/some-article.md"]
```

Sources become plain provenance metadata, not navigable links. This is correct because:
- `raw/` is backend storage — users should never navigate there from Obsidian
- The source URL is already in `source_url:` frontmatter for actual navigation to the original
- Provenance tracking still works — the path string identifies which raw file produced the article

**Impact:** This changes the `compiled_shared` schema, the `/compile` skill, the `/rebuild` skill (since it calls compile logic), and the pre-commit hook (wikilink resolution no longer needs to handle `raw/` paths).

### Frontmatter Schema Changes

**`_meta/schemas/frontmatter.yaml`** changes:

1. **`compiled_shared.sources`**: Change from `list[wikilink]` to `list[string]` (plain paths, not wikilinks)
2. **Add `workspace` section:**

```yaml
workspace:
  required_fields:
    title: string
    created: date           # YYYY-MM-DD
    author: string          # actor name (human name or agent name)
    tags: list[string]      # domains from wiki.config.yaml
  optional_fields:
    summary: string
    related: list[wikilink]
    sources: list[string]   # plain paths, same as compiled_shared
```

3. **All path references**: `compiled/` -> `wiki/` in comments and documentation within the schema file.

### Skill Changes

#### `/ingest` -- Path change in context loading

- Still writes to `raw/`. Output path unchanged.
- Still auto-triggers `/compile` after ingestion.
- **Path change:** Context loading step reads `wiki/_index.md` (was `compiled/_index.md`) to check for existing source-summaries and avoid duplicate ingestion.

#### `/compile` -- Path changes + two logic changes

Path changes (find-and-replace):
- All output paths: `compiled/<type>/` -> `wiki/<type>/`
- Index file: `compiled/_index.md` -> `wiki/_index.md`
- Backlinks file: `compiled/_backlinks.md` -> `wiki/_backlinks.md`

Logic change 1 — **`sources:` field format:**
- Old: `sources: ["[[raw/blogs/foo.md]]"]` (wikilinks)
- New: `sources: ["raw/blogs/foo.md"]` (plain strings)
- Applies to: source-summary creation (Step 2), article creation (Step 4), article merging (Step 4)

Logic change 2 — **Index generation scans all of `wiki/`:**
- Old: Index and backlinks only cover `compiled/` content
- New: Must scan `wiki/workspaces/` too when regenerating `_index.md` and `_backlinks.md`
- For workspace files without a `summary` field, use the title as the index entry (no dash-summary suffix)
- `_backlinks.md` tracks wikilinks across both KB and workspace content

#### `/rebuild` -- Scoped wipe + same compile changes

- Old behavior: wipe all of `compiled/`
- New behavior: wipe only `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`
- **Never touches:** `wiki/workspaces/`, `wiki/.obsidian/`, `wiki/_index.md`, `wiki/_backlinks.md`
- After recompilation, regenerate `_index.md` and `_backlinks.md` covering ALL of `wiki/` (including preserved workspace content)
- Inherits both compile logic changes (plain `sources:` strings, workspace-aware index)

#### `/lint` -- Path changes + workspace awareness

Path changes (find-and-replace): all `compiled/` references -> `wiki/`

Logic changes:
- **KB articles** (in `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`): validate with full `compiled_shared` schema — all existing checks apply
- **Workspace files** (in `wiki/workspaces/`): validate with light `workspace` schema — only check `title` and `created` are present, valid date format. Skip `type`, `sources`, `confidence`, `decay_rate` checks.
- **Wikilink resolution (Check 2):** all `[[wikilinks]]` resolve within `wiki/`. No more special handling for `raw/` prefix links.
- **Orphan detection (Check 3):** include workspace files in the analysis
- **Stale content (Check 5):** skip for workspace files (they don't have `last_verified` or `decay_rate`)

#### `/index` -- New skill

- Scans all `.md` files in `wiki/` (both KB type directories and `workspaces/`)
- Regenerates `wiki/_index.md` and `wiki/_backlinks.md` to include everything
- Non-destructive: only reads content and rewrites the two index files
- For workspace files without a `summary` field, use the title as the index entry
- Skips `_index.md`, `_backlinks.md`, and `.obsidian/` files
- Use case: run after manually creating workspace content to update the master index

**Shared index logic:** `/compile`, `/rebuild`, and `/index` all call the same index-generation logic. This should be described once in `_meta/prompts/index-update.md` and referenced by all three skills. When any of them regenerate `_index.md`, they must scan ALL of `wiki/` to avoid dropping workspace entries from the index.

### Index Format Changes

`_index.md` adds a Workspaces section:

```markdown
# Wiki Index

## Concepts
- [[concepts/<name>|<Title>]] -- <summary>

## People
- [[people/<name>|<Title>]] -- <summary>

## Tools
- [[tools/<name>|<Title>]] -- <summary>

## Sources
- [[sources/<name>|<Title>]] -- <summary>

## Workspaces
### <workspace-name>
- [[workspaces/<name>/<file>|<Title>]] -- <summary or title if no summary>
```

`_backlinks.md` includes cross-zone references (e.g., a workspace note linking to a KB article shows up in that article's backlinks).

### Change Detection

Compare `_index.md` entries against actual files in `wiki/`:
- Files in `wiki/` not listed in `_index.md` = unindexed content
- A `/status` flag on `/lint` (or standalone) reports unindexed files
- User/agent runs `/index` to pick up new content

No manifest file or hash tracking needed. The index IS the manifest.

### Structure Protection

The wiki relies on a fixed set of paths that skills, hooks, and indexing depend on. Users or agents may accidentally rename or delete these from Obsidian. Two complementary defenses:

**Protected paths:**

| Path | Purpose |
|---|---|
| `wiki/_index.md` | Master index — read by every skill for context loading |
| `wiki/_backlinks.md` | Cross-reference map — read by lint, compile, index |
| `wiki/concepts/` | KB type directory — compile/rebuild output target |
| `wiki/people/` | KB type directory — compile/rebuild output target |
| `wiki/tools/` | KB type directory — compile/rebuild output target |
| `wiki/sources/` | KB type directory — compile/rebuild output target |
| `wiki/workspaces/` | Actor workspace root |

**Defense 1: Pre-commit hook guard (preventive)**

A new Phase 0 in the pre-commit hook runs BEFORE any file validation. It checks that every protected path exists on disk. If any are missing, the commit is blocked with a clear message:

```bash
# Phase 0: Structure integrity check
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
```

This prevents accidental structural damage from becoming permanent in git history.

**Defense 2: Skill-level self-healing (resilient)**

Every skill (`/compile`, `/rebuild`, `/lint`, `/index`, `/ingest`) includes a shared **Step 0: Verify Wiki Structure** before any other work. If any protected path is missing, the skill recreates it silently and continues:

- Missing type directories → recreate as empty directories
- Missing `_index.md` → recreate with empty scaffold (section headers only)
- Missing `_backlinks.md` → recreate as empty file with `# Backlinks` header
- Missing `workspaces/` → recreate with `my-notes/.gitkeep` inside

This ensures skills work correctly even if the user deleted something in Obsidian and hasn't committed yet. No error, no abort — self-heal and proceed.

The self-healing logic should be documented once in `_meta/prompts/structure-check.md` and referenced by all skills rather than duplicated in each SKILL.md.

### Pre-commit Hook Changes

Update `hooks/pre-commit.sh`:

0. **Phase 0: Structure integrity** (new — see Structure Protection above)
1. **Staged file filter:** `compiled/.*\.md$` -> `wiki/.*\.md$` (but exclude `wiki/workspaces/` for full validation)
2. **KB file validation** (files in `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/`):
   - All existing checks: frontmatter exists, required fields (title, type, created, summary, sources), type enum, sources non-empty
   - Same behavior as today, just with updated paths
3. **Workspace file validation** (files in `wiki/workspaces/`):
   - Check frontmatter exists and closes properly
   - Check `title` field present
   - Check `created` field present
   - Skip: type enum, sources non-empty, type-specific fields
4. **Wikilink resolution (Phase 2):**
   - Remove the `raw/` prefix special case (raw links no longer exist as wikilinks)
   - All `[[link]]` targets resolve within `wiki/`: `target="$WIKI_ROOT/wiki/${link}.md"`
5. **Skip:** `.obsidian/` files and non-`.md` files

### Obsidian Config Changes

Move `.obsidian/` from repo root to `wiki/.obsidian/`.

**`wiki/.obsidian/graph.json`:**
- Remove `"search": "path:compiled"` filter (everything in vault is relevant now)
- Update color group queries:
  - `path:compiled/concepts` -> `path:concepts`
  - `path:compiled/people` -> `path:people`
  - `path:compiled/tools` -> `path:tools`
  - `path:compiled/sources` -> `path:sources`
- Add new color group: `path:workspaces` with a distinct color

**`wiki/.obsidian/app.json`:**
- No changes needed (`userIgnoreFilters` for `_index.md` and `_backlinks.md` still apply)

**`wiki/.obsidian/appearance.json`:**
- No changes needed (move as-is)

### Wikilink Format

KB article links remain short (identical path structure to today):
- `[[concepts/foo|Foo]]` — relative to `wiki/` vault root
- `[[people/bar|Bar]]`
- `[[sources/baz|Baz]]`

Workspace links include the workspace path:
- `[[workspaces/content-creator/drafts/blog-post|Blog Draft]]`
- `[[workspaces/my-notes/research-log|Research Log]]`

### wiki.config.yaml Changes

Add vault configuration:

```yaml
vault:
  dir: wiki
  default_workspace: my-notes
```

### .gitignore Changes

Update Obsidian paths from repo root to `wiki/`:

```gitignore
# Before
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/core-plugins.json
.obsidian/community-plugins.json
.obsidian/hotkeys.json
.obsidian/plugins/

# After
wiki/.obsidian/workspace.json
wiki/.obsidian/workspace-mobile.json
wiki/.obsidian/core-plugins.json
wiki/.obsidian/community-plugins.json
wiki/.obsidian/hotkeys.json
wiki/.obsidian/plugins/
```

### Token Count Script Changes

Update `hooks/token-count.sh`:
- Change `count_words "$WIKI_ROOT/compiled"` -> `count_words "$WIKI_ROOT/wiki"`
- Update output labels: `compiled/` -> `wiki/`
- Variable names: `COMPILED_WORDS` -> `WIKI_WORDS`, `COMPILED_TOKENS` -> `WIKI_TOKENS`

---

## Files to Create

| File | Purpose |
|---|---|
| `wiki/.obsidian/graph.json` | Updated graph config (no compiled filter, updated color groups) |
| `wiki/.obsidian/app.json` | Moved from repo root (no content changes) |
| `wiki/.obsidian/appearance.json` | Moved from repo root (no content changes) |
| `wiki/workspaces/my-notes/.gitkeep` | Default human workspace |
| `wiki/concepts/.gitkeep` | Empty KB type directory |
| `wiki/people/.gitkeep` | Empty KB type directory |
| `wiki/tools/.gitkeep` | Empty KB type directory |
| `wiki/sources/.gitkeep` | Empty KB type directory |
| `wiki/_index.md` | Master index (empty scaffold) |
| `wiki/_backlinks.md` | Master backlinks (empty) |
| `.claude/skills/index/SKILL.md` | New `/index` skill |
| `_meta/prompts/structure-check.md` | Shared self-healing logic referenced by all skills |

## Files to Modify

| File | Change Summary |
|---|---|
| `.claude/skills/compile/SKILL.md` | `compiled/` -> `wiki/`, sources field to plain strings, index scans workspaces, add Step 0 structure check |
| `.claude/skills/rebuild/SKILL.md` | Scoped wipe (4 type dirs only), all compile path changes, workspace-safe, add Step 0 structure check |
| `.claude/skills/ingest/SKILL.md` | Context loading: `compiled/_index.md` -> `wiki/_index.md`, add Step 0 structure check |
| `.claude/skills/lint/SKILL.md` | `compiled/` -> `wiki/`, workspace light validation, remove raw/ wikilink handling, add Step 0 structure check |
| `_meta/schemas/frontmatter.yaml` | Add `workspace` section, `sources` from `list[wikilink]` to `list[string]` |
| `_meta/wiki.config.yaml` | Add `vault` section |
| `_meta/prompts/compile.md` | `compiled/` -> `wiki/`, sources format change |
| `_meta/prompts/index-update.md` | `compiled/` -> `wiki/`, add workspace section to index format |
| `_meta/prompts/ingest.md` | `compiled/_index.md` -> `wiki/_index.md` |
| `_meta/prompts/lint.md` | `compiled/` -> `wiki/` |
| `_meta/prompts/query.md` | `compiled/` -> `wiki/` |
| `hooks/pre-commit.sh` | Path changes, workspace-aware validation, simplified wikilink resolution |
| `hooks/token-count.sh` | `compiled` -> `wiki` in paths, variables, and output |
| `CLAUDE.md` | Path changes, workspace docs, add `/index` skill, update progressive loading |
| `AGENTS.md` | Path changes, workspace docs |
| `GEMINI.md` | Path changes, workspace docs |
| `README.md` | Full rewrite: structure, data flow, quick start, directory tree |
| `docs/index.md` | Update hero features, data flow diagram (`compiled/` -> `wiki/`) |
| `docs/getting-started.md` | Update setup (open `wiki/` as vault), directory structure, step 5 |
| `docs/skills.md` | Add `/index` skill, update all paths, update compiled type table |
| `docs/schema.md` | Add workspace schema section, update sources type, path references |
| `docs/obsidian.md` | Update vault setup (open `wiki/`), graph color queries, add workspace guidance |
| `docs/configuration.md` | Add `vault` config section |
| `docs/validation.md` | Update pre-commit paths, add Phase 0 structure guard docs, add workspace validation rules |
| `docs/providers.md` | Update any path references |
| `.gitignore` | Update Obsidian paths from `.obsidian/` to `wiki/.obsidian/` |

## Files to Delete

| File | Reason |
|---|---|
| `compiled/` (entire directory) | Replaced by `wiki/` type directories |
| `.obsidian/` (at repo root) | Moved to `wiki/.obsidian/` |

## Out of Scope

- **Automatic file-watcher hooks** — start with on-demand `/index`. Auto-detection can be added later.
- **Workspace adoption** (`/adopt` command to promote workspace content to KB) — future enhancement.
- **Workspace templates** (scaffold for new agent workspaces) — future enhancement.
- **Per-workspace access control** — not needed for current use case.

---

## End-to-End Evaluation Plan

After all changes are implemented, a fresh Claude session should follow these steps to validate the entire system works correctly. Each phase has explicit pass/fail criteria.

### Phase 1: Fresh Setup & Structure Validation

**Goal:** Verify the repo structure matches the spec and Obsidian setup works.

| Step | Action | Pass Criteria |
|---|---|---|
| 1.1 | Run `ls wiki/` | Shows: `.obsidian/`, `concepts/`, `people/`, `tools/`, `sources/`, `workspaces/`, `_index.md`, `_backlinks.md` |
| 1.2 | Run `ls wiki/workspaces/` | Shows: `my-notes/` (default human workspace) |
| 1.3 | Run `ls wiki/.obsidian/` | Shows: `graph.json`, `app.json`, `appearance.json` |
| 1.4 | Verify `raw/` exists at repo root | `raw/` directory present with subdirectories |
| 1.5 | Verify no backend files in `wiki/` | No `_meta/`, `hooks/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `docs/`, `output/` inside `wiki/` |
| 1.6 | Read `_meta/wiki.config.yaml` | Contains `vault.dir: wiki` and `vault.default_workspace: my-notes` |
| 1.7 | Read `_meta/schemas/frontmatter.yaml` | Contains `workspace` section with required fields: title, created, author, tags. `compiled_shared.sources` is `list[string]` (not `list[wikilink]`) |
| 1.8 | Read `.gitignore` | Obsidian paths reference `wiki/.obsidian/` (not `.obsidian/`) |

### Phase 2: Ingest & Compile Pipeline

**Goal:** Verify the core pipeline produces correct output in the new structure.

| Step | Action | Pass Criteria |
|---|---|---|
| 2.1 | Run `/ingest` with a real URL (e.g., a blog post) | Raw file created in `raw/<category>/` with valid frontmatter |
| 2.2 | Verify compile auto-triggered | Articles created in `wiki/<type>/` (e.g., `wiki/concepts/`, `wiki/sources/`) |
| 2.3 | Read a compiled article's frontmatter | `sources:` field uses plain strings (`"raw/blogs/foo.md"`), NOT wikilinks (`"[[raw/blogs/foo.md]]"`) |
| 2.4 | Read `wiki/_index.md` | Lists the new articles under correct type sections (Concepts, People, Tools, Sources) with wikilinks and summaries |
| 2.5 | Read `wiki/_backlinks.md` | Cross-references exist between the new articles |
| 2.6 | Check wikilinks in article bodies | All `[[type/name\|Display]]` links point to files that exist in `wiki/` |
| 2.7 | Run a second `/ingest` with a different URL | Merges into existing articles where applicable, no duplicates created |
| 2.8 | Verify `_index.md` updated | New entries added, existing entries preserved |

### Phase 3: Workspace Content

**Goal:** Verify user/agent workspace content is first-class in the system.

| Step | Action | Pass Criteria |
|---|---|---|
| 3.1 | Create `wiki/workspaces/my-notes/research-log.md` with light frontmatter (title, created, author, tags) | File created successfully |
| 3.2 | Add a wikilink to a KB article in the note: `[[concepts/some-concept\|Some Concept]]` | Wikilink syntax is valid |
| 3.3 | Run `/index` | `wiki/_index.md` now includes a "Workspaces" section with the new note listed under `my-notes` |
| 3.4 | Read `wiki/_backlinks.md` | The KB article referenced in 3.2 shows the workspace note as an inbound link |
| 3.5 | Create `wiki/workspaces/test-agent/drafts/blog-draft.md` with workspace frontmatter (`author: "test-agent"`) | Agent workspace auto-created |
| 3.6 | Run `/index` again | Both `my-notes` and `test-agent` workspaces appear in `_index.md` under Workspaces section |

### Phase 4: Rebuild Safety

**Goal:** Verify `/rebuild` wipes only KB content and preserves everything else.

| Step | Action | Pass Criteria |
|---|---|---|
| 4.1 | Record current workspace files: `ls -R wiki/workspaces/` | Note the file list |
| 4.2 | Record Obsidian config: `ls wiki/.obsidian/` | Note the file list |
| 4.3 | Delete a raw source file (e.g., `rm raw/blogs/some-article.md`) | File removed |
| 4.4 | Run `/rebuild` | Completes without errors |
| 4.5 | Verify KB regenerated | `wiki/concepts/`, `wiki/people/`, `wiki/tools/`, `wiki/sources/` contain recompiled articles (deleted source's unique articles are gone) |
| 4.6 | Verify workspaces UNTOUCHED | `ls -R wiki/workspaces/` output is identical to step 4.1 |
| 4.7 | Verify `.obsidian/` UNTOUCHED | `ls wiki/.obsidian/` output is identical to step 4.2 |
| 4.8 | Read `wiki/_index.md` | KB articles updated (deleted source removed), workspace entries STILL PRESENT |
| 4.9 | Read `wiki/_backlinks.md` | Workspace cross-references preserved |

### Phase 5: Structure Protection

**Goal:** Verify both defensive layers (hook guard + skill self-healing) prevent structural damage.

**5A: Pre-commit hook blocks structural deletion**

| Step | Action | Pass Criteria |
|---|---|---|
| 5A.1 | Delete `wiki/concepts/` directory, stage the deletion | `git add` succeeds |
| 5A.2 | Run `git commit` | Pre-commit hook FAILS with "BLOCKED: 'wiki/concepts' is missing" |
| 5A.3 | Restore `wiki/concepts/`, delete `wiki/_index.md`, stage | `git add` succeeds |
| 5A.4 | Run `git commit` | Pre-commit hook FAILS with "BLOCKED: 'wiki/_index.md' is missing" |
| 5A.5 | Restore `wiki/_index.md`, delete `wiki/workspaces/`, stage | `git add` succeeds |
| 5A.6 | Run `git commit` | Pre-commit hook FAILS with "BLOCKED: 'wiki/workspaces' is missing" |
| 5A.7 | Restore everything | All protected paths present again |

**5B: Skill self-healing recreates missing structure**

| Step | Action | Pass Criteria |
|---|---|---|
| 5B.1 | Delete `wiki/concepts/` directory (do NOT commit) | Directory gone |
| 5B.2 | Run `/compile` on an existing raw source | Skill recreates `wiki/concepts/` in Step 0 before compiling, then completes successfully |
| 5B.3 | Delete `wiki/_index.md` (do NOT commit) | File gone |
| 5B.4 | Run `/index` | Skill recreates empty `_index.md` scaffold in Step 0, then populates it |
| 5B.5 | Delete `wiki/workspaces/` (do NOT commit) | Directory gone |
| 5B.6 | Run `/lint` | Skill recreates `wiki/workspaces/` with `my-notes/.gitkeep` in Step 0, then lints |
| 5B.7 | Delete `wiki/_backlinks.md` (do NOT commit) | File gone |
| 5B.8 | Run `/compile` on an existing raw source | Skill recreates empty `_backlinks.md` in Step 0, then regenerates it with actual data |

### Phase 6: Pre-commit Hook Schema Validation

**Goal:** Verify the hook enforces correct schemas per zone.

| Step | Action | Pass Criteria |
|---|---|---|
| 6.1 | Stage a valid KB article (full frontmatter) in `wiki/concepts/` | `git add` succeeds |
| 6.2 | Run `git commit` | Pre-commit hook passes |
| 6.3 | Stage a KB article missing `sources:` field | `git add` succeeds |
| 6.4 | Run `git commit` | Pre-commit hook FAILS with "missing required field 'sources'" |
| 6.5 | Stage a valid workspace file (light frontmatter: title, created) in `wiki/workspaces/my-notes/` | `git add` succeeds |
| 6.6 | Run `git commit` | Pre-commit hook PASSES (light validation, no sources required) |
| 6.7 | Stage a workspace file missing `title:` | `git add` succeeds |
| 6.8 | Run `git commit` | Pre-commit hook FAILS with "missing required field 'title'" |
| 6.9 | Add a broken wikilink `[[concepts/nonexistent]]` to any wiki file, stage it | `git add` succeeds |
| 6.10 | Run `git commit` | Pre-commit hook FAILS with "broken wikilink" |

### Phase 7: Lint Validation

**Goal:** Verify `/lint` handles both KB and workspace content correctly.

| Step | Action | Pass Criteria |
|---|---|---|
| 7.1 | Run `/lint` | Report generated at `output/reports/lint-<date>.md` |
| 7.2 | Verify KB articles get full validation | Report checks: frontmatter, wikilinks, orphans, contradictions, staleness, missing concepts, duplicates |
| 7.3 | Verify workspace files get light validation | Report checks `title` and `created` only, no staleness or contradiction checks on workspace content |
| 7.4 | Verify broken wikilinks detected across zones | A broken link in a workspace file is reported |
| 7.5 | Verify orphan detection includes workspace files | Workspace files with zero inbound links are reported |

### Phase 8: Token Count

**Goal:** Verify the token count script works with new paths.

| Step | Action | Pass Criteria |
|---|---|---|
| 8.1 | Run `./hooks/token-count.sh` | Output shows `raw/` and `wiki/` word/token counts (not `compiled/`) |
| 8.2 | Verify wiki count includes workspace content | Word count for `wiki/` includes files in `wiki/workspaces/` |

### Phase 9: Obsidian Experience (Manual Verification)

**Goal:** Verify the Obsidian UI is clean and functional. These steps require opening Obsidian.

| Step | Action | Pass Criteria |
|---|---|---|
| 9.1 | Open Obsidian -> File -> Open folder as vault -> select `wiki/` | Vault opens successfully |
| 9.2 | Check file explorer sidebar | Shows ONLY: `concepts/`, `people/`, `tools/`, `sources/`, `workspaces/` — no `_meta/`, `raw/`, `hooks/`, `docs/`, `CLAUDE.md`, etc. |
| 9.3 | Open graph view (Cmd+G) | Nodes are color-coded: concepts=blue, people=green, tools=orange, sources=gray, workspaces=distinct color |
| 9.4 | Click a `[[wikilink]]` in any article | Navigates to the target article within the vault |
| 9.5 | Check backlinks panel on a KB article | Shows inbound links from both KB articles and workspace notes |
| 9.6 | Create a new note via Obsidian (Cmd+N) in `workspaces/my-notes/` | File created and visible in sidebar |
| 9.7 | Verify `_index.md` and `_backlinks.md` are hidden from sidebar | `userIgnoreFilters` still works |

### Phase 10: Documentation Accuracy

**Goal:** Verify all user-facing docs match the new system.

| Step | Action | Pass Criteria |
|---|---|---|
| 10.1 | Read `README.md` quick start | Step 5 says "Open `wiki/` as vault" (not the repo root). Directory tree shows new structure. Data flow diagram shows `wiki/` not `compiled/`. |
| 10.2 | Read `docs/getting-started.md` | Setup instructions reference `wiki/`, directory tree is updated, Obsidian setup points to `wiki/` |
| 10.3 | Read `docs/skills.md` | All 5 skills documented (`/ingest`, `/compile`, `/rebuild`, `/lint`, `/index`). All paths reference `wiki/`. `/rebuild` describes scoped wipe. Structure protection mentioned. |
| 10.4 | Read `docs/schema.md` | Workspace schema section present. `sources` described as `list[string]`. |
| 10.5 | Read `docs/obsidian.md` | Vault setup points to `wiki/`. Graph color queries updated. Workspace guidance included. |
| 10.6 | Read `docs/configuration.md` | `vault` config section documented. |
| 10.7 | Read `docs/validation.md` | Pre-commit hook docs describe Phase 0 structure guard + workspace-aware validation. Paths reference `wiki/`. |
| 10.8 | Read `CLAUDE.md` | Progressive loading references `wiki/_index.md`. Skills list includes `/index`. Paths reference `wiki/`. |
| 10.9 | Grep entire repo for stale `compiled/` references | `grep -r "compiled/" --include="*.md" --include="*.yaml" --include="*.sh" --include="*.yml"` returns zero matches (excluding this spec file and git history) |
