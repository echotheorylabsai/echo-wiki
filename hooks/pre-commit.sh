#!/usr/bin/env bash
# Echo Wiki — Pre-commit Hook
# Validates structural integrity of compiled/ markdown files.
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

# --- Get staged compiled files ---

STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '^compiled/.*\.md$' || true)

if [ -z "$STAGED" ]; then
    exit 0
fi

# --- Phase 1: Frontmatter validation ---

for file in $STAGED; do
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

# --- Phase 2: Wikilink resolution ---

for file in $STAGED; do
    fp="$WIKI_ROOT/$file"

    # Extract all [[link]] and [[link|alias]] patterns
    grep -oE '\[\[[^]]+\]\]' "$fp" 2>/dev/null | sed 's/\[\[//;s/\]\]//;s/|.*//' | sort -u | while IFS= read -r link; do
        [ -z "$link" ] && continue

        if [[ "$link" == raw/* ]]; then
            # Raw source link — resolve from wiki root
            target="$WIKI_ROOT/$link"
            [[ "$link" != *.md ]] && target="${target}.md"
        else
            # Compiled article link — resolve in compiled/
            target="$WIKI_ROOT/compiled/${link}.md"
        fi

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
