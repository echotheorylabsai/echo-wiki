#!/usr/bin/env bash
# Echo Wiki — Pre-commit Hook
# Validates structural integrity of wiki/ markdown files.
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

# Extract entity_types from config (returns pipe-delimited type names)
extract_valid_types() {
    awk '
      /^entity_types:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /- name:/ {
        sub(/.*- name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, "")
        types = (types ? types "|" : "") $0
      }
      END { print types ? types : "concept|person|tool|source-summary" }
    ' "$WIKI_ROOT/_meta/wiki.config.yaml"
}

# Extract entity_types dirs from config (one per line, prefixed with wiki/)
extract_kb_dirs() {
    awk '
      /^entity_types:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /dir:/ {
        sub(/.*dir:[[:space:]]*/, ""); sub(/[[:space:]]*$/, "")
        print "wiki/" $0
      }
    ' "$WIKI_ROOT/_meta/wiki.config.yaml"
}

# --- Phase 0: Structure integrity check ---

PROTECTED_PATHS=("wiki" "wiki/_index.md" "wiki/_backlinks.md" "wiki/workspaces")
while IFS= read -r d; do
    [ -n "$d" ] && PROTECTED_PATHS+=("$d")
done <<< "$(extract_kb_dirs)"

for path in "${PROTECTED_PATHS[@]}"; do
  if [ ! -e "$WIKI_ROOT/$path" ]; then
    echo "BLOCKED: '$path' is missing. This path is required by the wiki system." >> "$ERR_FILE"
    echo "  If you renamed or deleted it, restore it or run a skill to recreate it." >> "$ERR_FILE"
  fi
done

if [ -s "$ERR_FILE" ]; then
    echo "Pre-commit validation failed:"
    echo ""
    sed 's/^/  - /' "$ERR_FILE"
    echo ""
    echo "Restore missing paths or use 'git commit --no-verify' for WIP commits."
    exit 1
fi

# --- Get staged wiki files ---

# Build KB dir regex from config
KB_DIR_REGEX=$(extract_kb_dirs | sed 's|wiki/||' | paste -sd'|' -)
KB_DIR_REGEX=${KB_DIR_REGEX:-"concepts|people|tools|sources"}

STAGED_KB=()
while IFS= read -r f; do
    [ -n "$f" ] && STAGED_KB+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E "^wiki/(${KB_DIR_REGEX})/.*\\.md\$" || true)

STAGED_WS=()
while IFS= read -r f; do
    [ -n "$f" ] && STAGED_WS+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '^wiki/workspaces/.*\.md$' || true)

# On Bash 3.2 (macOS default), empty arrays + set -u = "unbound variable".
# Use ${arr[@]+"${arr[@]}"} pattern to safely expand potentially-empty arrays.
if [ ${#STAGED_KB[@]} -eq 0 ] && [ ${#STAGED_WS[@]} -eq 0 ]; then
    exit 0
fi

# --- Phase 1: KB file validation (full schema) ---

for file in ${STAGED_KB[@]+"${STAGED_KB[@]}"}; do
    [ -z "$file" ] && continue
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
        VALID_TYPES=$(extract_valid_types)
        if ! printf '%s' "|${VALID_TYPES}|" | grep -q "|${type_val}|"; then
            echo "$file: invalid type '$type_val' (expected: ${VALID_TYPES})" >> "$ERR_FILE"
        fi
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

# --- Phase 1b: Workspace file validation (light schema) ---

for file in ${STAGED_WS[@]+"${STAGED_WS[@]}"}; do
    [ -z "$file" ] && continue
    fp="$WIKI_ROOT/$file"
    bn=$(basename "$file")

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

    # Required fields for workspace: title, created
    for field in title created; do
        if ! echo "$fm" | grep -q "^${field}:"; then
            echo "$file: missing required field '$field'" >> "$ERR_FILE"
        fi
    done
done

# --- Phase 2: Wikilink resolution ---

ALL_STAGED=(${STAGED_KB[@]+"${STAGED_KB[@]}"} ${STAGED_WS[@]+"${STAGED_WS[@]}"})

for file in ${ALL_STAGED[@]+"${ALL_STAGED[@]}"}; do
    [ -z "$file" ] && continue
    fp="$WIKI_ROOT/$file"

    # Extract all [[link]] and [[link|alias]] patterns
    # Use process substitution to keep the while loop in the current shell,
    # so writes to $ERR_FILE are not lost in a subshell.
    while IFS= read -r link; do
        [ -z "$link" ] && continue

        # All wikilinks resolve within wiki/
        target="$WIKI_ROOT/wiki/${link}.md"

        if [ ! -f "$target" ]; then
            echo "$file: broken wikilink [[$link]]" >> "$ERR_FILE"
        fi
    done < <(grep -oE '\[\[[^]]+\]\]' "$fp" 2>/dev/null | sed 's/\[\[//;s/\]\]//;s/|.*//' | sort -u)
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
