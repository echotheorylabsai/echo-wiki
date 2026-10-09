# Plan — 2026-10-09-troubleshooting-doc

## Goal

Add a docs-site page `docs/troubleshooting.md` titled "Troubleshooting Validation" that explains the most
common failures reported by `hooks/validate.sh` and how to fix each one, with every message and rule
derived from `hooks/validate.sh` and `_meta/schemas/frontmatter.yaml`, and link it in the VitePress
sidebar under "Reference" directly after "Provider Support". No other docs page changes.

## Outcome

A reader who sees a `validate.sh` failure line can find that message on the new page, learn which rule
produced it and in which zone (KB, raw, workspace), and apply a concrete fix. The page appears in the
sidebar's Reference group after Provider Support, and the VitePress site still builds with its dead-link
check passing.

## Acceptance checks

### C1 — Page exists with the exact title
Expected: `docs/troubleshooting.md` exists and its H1 is "Troubleshooting Validation".
```sh
grep -q '^# Troubleshooting Validation$' docs/troubleshooting.md
```

### C2 — Sidebar entry sits in Reference directly after Provider Support
Expected: the line after the Provider Support item in `docs/.vitepress/config.mts` links to `/troubleshooting`.
```sh
grep -A1 "link: '/providers'" docs/.vitepress/config.mts | grep -q "link: '/troubleshooting'"
```

### C3 — Every message on the page is literally emitted by validate.sh
Expected: each message template on the page (first-column code span of a table row, with `<placeholder>` parts removed) has all of its fixed text fragments present verbatim in `hooks/validate.sh`; prints the first offending fragment otherwise.
```sh
awk -F'`' '/^\| `/ { s=$2; gsub(/\\\|/, "|", s); gsub(/<[^>]*>/, "\n", s); print s }' docs/troubleshooting.md \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort -u \
  | while IFS= read -r frag; do grep -qF -- "$frag" hooks/validate.sh || { echo "not in validate.sh: $frag"; exit 1; }; done
```

### C4 — The five requested failure families are documented
Expected: the page contains the literal message prefixes for missing required fields, tags outside config domains, non-kebab-case filenames, broken wikilinks, and missing source paths.
```sh
for frag in "missing required field '" "' not in config domains (expected: " "filename not kebab-case (expected: lowercase-with-hyphens.md)" "broken wikilink [[" "source path does not exist: "; do grep -qF -- "$frag" docs/troubleshooting.md || { echo "missing from page: $frag"; exit 1; }; done
```

### C5 — No other docs page changed
Expected: relative to the merge base with `origin/main`, the only changed paths under `docs/` are the new page and the sidebar config.
```sh
test -z "$(git diff --name-only "$(git merge-base origin/main HEAD)" -- docs | grep -v -e '^docs/troubleshooting.md$' -e '^docs/.vitepress/config.mts$')"
```

### C6 — Docs site builds
Expected: a clean dependency install and `vitepress build docs` succeed, including VitePress's dead-link check for the new page's links.
```sh
npm ci --no-audit --no-fund && npm run docs:build
```

## Tier

S — the diff is one new Markdown page plus one sidebar line in an existing config. All checks are runnable.

## Source

prompt

## Friction

- 2026-10-09 10:05 · claude/fable-5.1 · triage — Running `hooks/validate.sh` and `tests/run-tests.sh` needs an approval this non-interactive session cannot grant. [Why: messages derived from the script's `err` literals (`hooks/validate.sh`) and the expected substrings in `tests/run-tests.sh:854-885` instead.] [Cites: hooks/validate.sh:148]
