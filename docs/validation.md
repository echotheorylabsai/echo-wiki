# Validation & Linting

Echo Wiki uses two layers of validation: deterministic scripts (no LLM required) and a semantic lint skill (LLM-powered). The scripts are authoritative for everything mechanical; the LLM is spent only on checks a script cannot do.

## validate.sh — Deterministic Schema Enforcement

Enforces `_meta/schemas/frontmatter.yaml` mechanically:

```bash
./hooks/validate.sh              # same as --all
./hooks/validate.sh --all        # every .md under wiki/ and raw/
./hooks/validate.sh --staged     # staged files (what the pre-commit hook runs)
./hooks/validate.sh <path>...    # explicit paths
```

`validate.sh` uses Ruby's standard `YAML` parser for frontmatter syntax; Ruby is available by default on supported macOS setups and requires no gem installation.

Zones are inferred from paths: KB articles (`wiki/<entity dir>/`) get the full schema, `raw/` files get the raw schema, `wiki/workspaces/` files get the light schema.

| Check | KB | raw/ | workspace |
|---|---|---|---|
| Frontmatter opens/closes | ✓ | ✓ | ✓ |
| Required fields (full / raw / light schema) | 11 fields | 8 fields | `title`, `created` |
| `type` matches `entity_types` in config | ✓ | — | — |
| `decay_rate`, `confidence` enums | ✓ | — | — |
| Dates are `YYYY-MM-DD` | ✓ | ✓ | ✓ |
| `tags` values exist in config domains | ✓ | ✓ | — |
| `sources` non-empty; every path exists and remains inside `raw/` | ✓ | — | — |
| `source_type` / `ingestion_tool` enums | — | ✓ | — |
| At least one visible, citable Markdown heading | — | ✓ | — |
| Type-specific fields (built-in types) | ✓ | — | — |
| Filename kebab-case, ≤ 60 chars | ✓ | ✓ | — |
| Every `[[wikilink]]` resolves within `wiki/` | ✓ | — | ✓ |
| At least one valid `Evidence:` locator | ✓ | — | System context packs and generated `answers/` |

Custom entity types (beyond concept/person/tool/source-summary) are validated against the shared KB schema only — add entries to `kb_type_specific` in `_meta/schemas/frontmatter.yaml` and extend the script if you want stricter checks.

A structure guard always runs first: `_meta/`, `raw/`, and `wiki/` must be real directories directly beneath the repository root; `wiki/_index.md`, `wiki/_backlinks.md`, `wiki/workspaces/`, and every configured KB type directory must also exist.

An evidence locator has the form `Evidence: raw/<path>.md#<exact heading>`. Validation confirms that the raw file remains inside `raw/`, appears in the KB article's `sources:` list, and has that heading in rendered Markdown content. Frontmatter, fenced code, HTML comments, and raw HTML blocks cannot satisfy evidence checks. KB articles, system context packs, and generated actor `answers/` require locators; the script verifies their shape and targets without attempting to infer whether prose is factual.

### Upgrading an Existing Wiki

Evidence validation intentionally tightens the schema for existing content. Run `./hooks/validate.sh --all`; for each legacy raw source reported as headingless, make a deliberate one-time migration by adding `## Content` before its body. Then run `/rebuild` so KB articles are regenerated with evidence locators. Normal `/ingest` and `/compile` operations continue treating existing raw files as append-only.

## reindex.sh — Deterministic Index & Backlinks

```bash
./hooks/reindex.sh
```

Regenerates `wiki/_index.md` and `wiki/_backlinks.md` from the files on disk — config-driven sections, title-sorted entries, workspace grouping, cross-zone backlinks, and an explicit `_No inbound links._` marker for every orphan (which makes orphan detection a `grep`, not an LLM pass).

Skills call this script; neither humans nor LLMs ever hand-write the two index files.

## Pre-commit Hook

A thin wrapper around `validate.sh --staged`. Blocks commits containing schema violations.

**Install:**
```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

**Escape hatch:** `git commit --no-verify` for WIP commits.

## Skill Self-Healing

Every skill runs a structure check (Step 0) before any work. If a required path is missing, the skill recreates it silently. This means you can always recover by running any skill — even if you accidentally deleted a directory.

## Semantic Lint

Run on-demand via `/lint`. Requires an LLM agent. Produces detailed reports in `output/reports/`.

The deterministic layer (check 1) is delegated to `validate.sh`; the LLM handles orphan triage, contradictions, staleness, missing entities, duplicates, and sampled source fidelity. See [Skills → /lint](/skills#lint) for the full list of 7 checks.

## Tests

The scripts are covered by fixture-based tests:

```bash
bash tests/run-tests.sh
```

Golden-file assertions for `reindex.sh` (populated + empty wikis), one fixture per validation error class for `validate.sh`, and a git-integration test that installs the pre-commit hook in a throwaway repo.

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
