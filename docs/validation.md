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
  raw/        12400 words  ~  16120 tokens
  wiki/       8200 words   ~  10660 tokens
  TOTAL       20600 words  ~  26780 tokens

  Context usage: ~2.7% of 1M window
```
