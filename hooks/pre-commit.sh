#!/usr/bin/env bash
# Echo Wiki — Pre-commit Hook
# Validates a materialized Git index so configuration and Markdown always come
# from the same staged snapshot.
# Install: ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
# Escape: git commit --no-verify
set -uo pipefail

WIKI_ROOT="$(git rev-parse --show-toplevel)"
STAGED_ROOT=$(mktemp -d)
trap 'rm -rf "$STAGED_ROOT"' EXIT

if ! git checkout-index --all --prefix="$STAGED_ROOT/"; then
    echo "Pre-commit validation failed: could not materialize the staged snapshot."
    exit 1
fi

OUT="$(ECHO_WIKI_ROOT="$STAGED_ROOT" "$WIKI_ROOT/hooks/validate.sh" --all 2>&1)"
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
