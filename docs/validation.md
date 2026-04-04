# Validation & Linting

Echo Wiki uses two layers of validation: a structural pre-commit hook (no LLM required) and a semantic lint skill (LLM-powered).

## Pre-commit Hook

Automatically runs on every commit. Blocks commits with structural errors.

**Install:**
```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

**Checks:**

| Check | Method | Blocks commit? |
|---|---|---|
| Frontmatter exists | Regex for `---` header | Yes |
| Required fields present | `title`, `type`, `created`, `summary`, `sources` | Yes |
| `type` is valid enum | `concept \| person \| tool \| source-summary` | Yes |
| All `[[wikilinks]]` resolve | Target file must exist | Yes |
| `sources:` is non-empty | At least one entry | Yes |

**Escape hatch:** `git commit --no-verify` for WIP commits.

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
[2026-04-04] Wiki Token Estimate
  raw/        12,400 words  ~  16,120 tokens
  compiled/    8,200 words  ~  10,660 tokens
  TOTAL       20,600 words  ~  26,780 tokens

  Context usage: ~2.7% of 1M window
```
