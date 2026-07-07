#!/usr/bin/env bash
# Echo Wiki — Pre-commit Hook
# Thin wrapper: all validation logic lives in hooks/validate.sh (full
# frontmatter schema, enums, dates, tags, source paths, wikilinks).
# Install: ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
# Escape: git commit --no-verify
set -uo pipefail

WIKI_ROOT="$(git rev-parse --show-toplevel)"

OUT="$("$WIKI_ROOT/hooks/validate.sh" --staged 2>&1)"
RC=$?

if [ "$RC" -ne 0 ]; then
    echo "Pre-commit validation failed:"
    echo ""
    printf '%s\n' "$OUT" | sed 's/^/  - /'
    echo ""
    echo "Fix errors or use 'git commit --no-verify' for WIP commits."
    exit 1
fi

echo "Pre-commit validation passed"
