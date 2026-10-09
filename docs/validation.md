# Validation & Linting

Echo Wiki uses two layers of validation: deterministic scripts (no LLM required) and a semantic lint skill (LLM-powered). The scripts are authoritative for everything mechanical; the LLM is spent only on checks a script cannot do.

## validate.sh — Deterministic Schema Enforcement

Enforces `_meta/schemas/frontmatter.yaml` mechanically:

```bash
./hooks/validate.sh              # same as --all
./hooks/validate.sh --all        # every .md under wiki/ and raw/
./hooks/validate.sh --staged     # staged files (what the pre-commit hook runs)
./hooks/validate.sh <path>...    # explicit paths
./hooks/validate.sh --json [...] # any form above, as one JSON object
```

### JSON output

Add `--json` anywhere in the arguments to get machine-readable output. It combines with `--all`, `--staged`, explicit paths, or no mode (`--json` alone means `--all`). Stdout is exactly one line holding one JSON object:

```json
{"files_validated":2,"violations":[{"file":"wiki/concepts/bad-date.md","message":"invalid date format in 'created' (expected YYYY-MM-DD, got '07-01-2026')"}]}
```

- `files_validated` — files checked, reported on success and failure.
- `violations` — one entry per problem, in the same order as text mode; empty when clean. Each `file` and `message` matches the `<file>: <message>` line text mode prints.
- Wiki-wide structure problems use the pseudo-file `structure`.
- Exit codes are unchanged: 0 when clean, 1 when there are violations. `NOTE:` lines still go to stderr.
- Producing JSON needs no extra tools; parse it with any JSON reader, e.g. `./hooks/validate.sh --json | jq .violations`.

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

Instances created before the `internal` source type existed keep working unchanged. To file team-authored documents as `internal`, add `- internal` to `source_types` in `_meta/wiki.config.yaml`, add `internal` to the three `source_type` lists in `_meta/schemas/frontmatter.yaml`, and create `raw/internal/images/`. Until the config lists it, `/ingest` stops and asks rather than writing an `internal` file.

## reindex.sh — Deterministic Index & Backlinks

```bash
./hooks/reindex.sh
```

Regenerates `wiki/_index.md` and `wiki/_backlinks.md` from the files on disk — config-driven sections, title-sorted entries, workspace grouping, cross-zone backlinks, and an explicit `_No inbound links._` marker for every orphan (which makes orphan detection a `grep`, not an LLM pass).

Skills call this script; neither humans nor LLMs ever hand-write the two index files.

## Pre-commit Hook

Validates the complete staged snapshot with `validate.sh --all`. Blocks commits containing schema violations.

**Install in an ordinary clone with no existing hook or custom `core.hooksPath`:**
```bash
ln -s ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

For existing hooks, hook managers or linked worktrees, use `/onboard` to inspect integration first; do not overwrite shared hooks.

**Escape hatch:** `git commit --no-verify` for WIP commits.

## Skill Self-Healing

Wiki operations include a structure-check step for missing generated paths. Onboarding creates the initial layout separately. Existing path conflicts and active writer/rebuild locks require resolution before proceeding.

## Semantic Lint

Run on-demand via `/lint`. Requires an LLM agent. Produces detailed reports in `output/reports/`.

The deterministic layer (check 1) is delegated to `validate.sh`; the LLM handles orphan triage, contradictions, staleness, missing entities, duplicates, and sampled source fidelity. See [Skills → /lint](/skills#lint) for the full list of 7 checks.

For the routine, non-destructive maintenance loop, run `/maintain`. It refreshes indexes, the lint report, and the maintenance queue when you invoke it; it is not a background scheduler and does not rewrite factual KB content. See [Keeping Content Fresh](/keeping-fresh).

## Tests

Run these fixture-based tests from the upstream Echo Wiki checkout (development tests are not copied into customer instances):

```bash
bash tests/run-tests.sh
ruby tests/onboarding-test.rb
```

Golden-file assertions for `reindex.sh` (populated + empty wikis), one fixture per validation error class for `validate.sh`, and a git-integration test that installs the pre-commit hook in a throwaway repo.

The onboarding suite checks preview/apply behavior, artifact and Git visibility preservation, path collisions, safe reruns, and exclusion of source knowledge/secrets.

GitHub Actions runs `.github/workflows/ci.yml` on every pull request and every push to `main`: `bash tests/run-tests.sh` on Ubuntu and on macOS (forced to the system Bash 3.2), `./hooks/validate.sh --all` on the shipped wiki skeleton, and `npm ci && npm run docs:build`. The onboarding suite is not part of CI; run it locally.

## Token Count

Track wiki size over time:

```bash
./hooks/token-count.sh    # Run manually
```

**Install as post-commit hook only when absent and using the ordinary clone hook path (informational):**
```bash
ln -s ../../hooks/token-count.sh .git/hooks/post-commit
```

Sample output:
```
[2026-04-05] Wiki Token Estimate
  raw/        12400 words  ~  16120 tokens
  wiki/       8200 words   ~  10660 tokens
  TOTAL       20600 words  ~  26780 tokens

  Context usage: ~2.7% of 1M window
```
