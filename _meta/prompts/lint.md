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
