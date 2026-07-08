#!/usr/bin/env bash
# Echo Wiki — Deterministic Schema Validation
# Enforces _meta/schemas/frontmatter.yaml mechanically, so the LLM never
# spends tokens on checks a script can do (and the schema stops being prose).
#
# Usage:
#   ./hooks/validate.sh              # same as --all
#   ./hooks/validate.sh --all        # every .md under wiki/ and raw/
#   ./hooks/validate.sh --staged     # staged .md files under wiki/ and raw/
#   ./hooks/validate.sh <path>...    # explicit paths (relative to repo root)
#
# Zones by path: wiki/workspaces/ -> workspace (light schema);
# wiki/<entity dir>/ -> KB (full schema); raw/ -> raw schema.
# _index.md, _backlinks.md, _log.md, .obsidian/, non-.md files are skipped.
#
# Exit 0 with "OK: N files validated", or exit 1 after listing violations
# ("<file>: <problem>") and "Validation failed: N issue(s)".
#
# Root resolution: $ECHO_WIKI_ROOT if set, else `git rev-parse --show-toplevel`.
# Bash 3.2 compatible. LC_ALL=C.
set -uo pipefail
export LC_ALL=C

WIKI_ROOT="${ECHO_WIKI_ROOT:-$(git rev-parse --show-toplevel)}"
CONFIG="$WIKI_ROOT/_meta/wiki.config.yaml"

ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

err() { # relpath message
    echo "$1: $2" >> "$ERR_FILE"
}

# --- Config extraction (with schema-default fallbacks) ---

frontmatter() {
    awk 'BEGIN{c=0}/^---$/{c++;next}c==1{print}c==2{exit}' "$1"
}

extract_valid_types() {
    awk '
      /^entity_types:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /- name:/ {
        sub(/.*- name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); gsub(/^"|"$/, "")
        types = (types ? types "|" : "") $0
      }
      END { print types ? types : "concept|person|tool|source-summary" }
    ' "$CONFIG" 2>/dev/null || echo "concept|person|tool|source-summary"
}

extract_kb_dirs() { # pipe-delimited dir names
    awk '
      /^entity_types:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /^[[:space:]]+dir:/ {
        sub(/.*dir:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); gsub(/^"|"$/, "")
        dirs = (dirs ? dirs "|" : "") $0
      }
      END { print dirs ? dirs : "concepts|people|tools|sources" }
    ' "$CONFIG" 2>/dev/null || echo "concepts|people|tools|sources"
}

extract_domains() { # pipe-delimited; empty means "allow any"
    awk '
      /^domains:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /- name:/ {
        sub(/.*- name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); gsub(/^"|"$/, "")
        d = (d ? d "|" : "") $0
      }
      END { print d }
    ' "$CONFIG" 2>/dev/null || true
}

extract_source_types() {
    awk '
      /^source_types:/ { in_block=1; next }
      /^[^ ]/ && in_block { in_block=0 }
      in_block && /^[[:space:]]+-[[:space:]]*/ {
        sub(/^[[:space:]]+-[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); gsub(/^"|"$/, "")
        s = (s ? s "|" : "") $0
      }
      END { print s ? s : "blog|paper|tweet|substack|github|podcast|video" }
    ' "$CONFIG" 2>/dev/null || echo "blog|paper|tweet|substack|github|podcast|video"
}

VALID_TYPES=$(extract_valid_types)
KB_DIRS=$(extract_kb_dirs)
DOMAINS=$(extract_domains)
SOURCE_TYPES=$(extract_source_types)

in_list() { # value pipe-list -> 0 if member
    case "|$2|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac
}

# --- Field helpers (operate on a frontmatter blob in $FM) ---

fm_has() { printf '%s\n' "$FM" | grep -q "^$1:"; }

fm_get() { # key -> value with surrounding quotes stripped
    printf '%s\n' "$FM" | awk -v k="$1" '
      $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); sub(/[[:space:]]*$/, ""); gsub(/^"|"$/, ""); print; exit }
    '
}

fm_list() { # key -> one item per line (inline [a, b] or block "- a" form)
    printf '%s\n' "$FM" | awk -v k="$1" '
      $0 ~ "^"k":" {
        line = $0; sub("^"k":[[:space:]]*", "", line)
        if (line ~ /^\[/) {
          gsub(/[\[\]]/, "", line)
          n = split(line, a, ",")
          for (i = 1; i <= n; i++) {
            t = a[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", t); gsub(/^"|"$/, "", t)
            if (t != "") print t
          }
          exit
        }
        inblock = 1; next
      }
      inblock && /^[[:space:]]+-[[:space:]]*/ {
        t = $0; sub(/^[[:space:]]+-[[:space:]]*/, "", t)
        sub(/[[:space:]]*$/, "", t); gsub(/^"|"$/, "", t)
        if (t != "") print t; next
      }
      inblock && /^[^[:space:]]/ { exit }
    '
}

check_date() { # relpath field-name
    local v
    v=$(fm_get "$2")
    if [ -n "$v" ]; then
        case "$v" in
            [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
            *) err "$1" "invalid date format in '$2' (expected YYYY-MM-DD, got '$v')" ;;
        esac
    fi
}

check_required() { # relpath field...
    local rel="$1" f
    shift
    for f in "$@"; do
        fm_has "$f" || err "$rel" "missing required field '$f'"
    done
}

check_tags() { # relpath
    local t
    [ -z "$DOMAINS" ] && return 0
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        in_list "$t" "$DOMAINS" || err "$1" "tag '$t' not in config domains (expected: $DOMAINS)"
    done < <(fm_list tags)
}

check_filename() { # relpath
    local bn
    bn=$(basename "$1")
    case "$bn" in
        *[!a-z0-9.-]*|-*|*-.md|*--*) err "$1" "filename not kebab-case (expected: lowercase-with-hyphens.md)" ;;
        *) echo "$bn" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*\.md$' || err "$1" "filename not kebab-case (expected: lowercase-with-hyphens.md)" ;;
    esac
    if [ "${#bn}" -gt 60 ]; then
        err "$1" "filename exceeds 60 characters"
    fi
}

check_wikilinks() { # relpath
    local link
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        if [ ! -f "$WIKI_ROOT/wiki/${link}.md" ]; then
            err "$1" "broken wikilink [[$link]]"
        fi
    done < <({ grep -oE '\[\[[^]]+\]\]' "$WIKI_ROOT/$1" 2>/dev/null || true; } | sed 's/^\[\[//; s/\]\]$//; s/|.*//' | sort -u)
}

check_frontmatter_shape() { # relpath -> 1 if unusable
    local fp="$WIKI_ROOT/$1"
    if ! head -1 "$fp" | grep -q '^---$'; then
        err "$1" "missing frontmatter"
        return 1
    fi
    if [ "$(grep -c '^---$' "$fp")" -lt 2 ]; then
        err "$1" "unclosed frontmatter"
        return 1
    fi
    return 0
}

# --- Zone validators ---

validate_kb() { # relpath
    local rel="$1" type_val decay conf src cat stype
    check_frontmatter_shape "$rel" || return 0
    FM=$(frontmatter "$WIKI_ROOT/$rel")

    check_required "$rel" title type created last_updated last_verified decay_rate confidence tags sources related summary

    type_val=$(fm_get type)
    if [ -n "$type_val" ] && ! in_list "$type_val" "$VALID_TYPES"; then
        err "$rel" "invalid type '$type_val' (expected: $VALID_TYPES)"
    fi

    decay=$(fm_get decay_rate)
    if [ -n "$decay" ] && ! in_list "$decay" "fast|medium|slow"; then
        err "$rel" "invalid decay_rate '$decay' (expected: fast|medium|slow)"
    fi

    conf=$(fm_get confidence)
    if [ -n "$conf" ] && ! in_list "$conf" "high|medium|speculative"; then
        err "$rel" "invalid confidence '$conf' (expected: high|medium|speculative)"
    fi

    check_date "$rel" created
    check_date "$rel" last_updated
    check_date "$rel" last_verified
    check_tags "$rel"

    if fm_has sources; then
        if [ -z "$(fm_list sources)" ]; then
            err "$rel" "sources list is empty"
        else
            while IFS= read -r src; do
                [ -z "$src" ] && continue
                [ -f "$WIKI_ROOT/$src" ] || err "$rel" "source path does not exist: $src"
            done < <(fm_list sources)
        fi
    fi

    # Type-specific required fields (built-in types only; custom types are
    # lenient — add kb_type_specific entries in frontmatter.yaml to tighten).
    case "$type_val" in
        concept)
            fm_has domain || err "$rel" "missing type-specific field 'domain' for type 'concept'"
            ;;
        person)
            fm_has role || err "$rel" "missing type-specific field 'role' for type 'person'"
            ;;
        tool)
            fm_has category || err "$rel" "missing type-specific field 'category' for type 'tool'"
            fm_has maintained || err "$rel" "missing type-specific field 'maintained' for type 'tool'"
            cat=$(fm_get category)
            if [ -n "$cat" ] && ! in_list "$cat" "framework|platform|service|product"; then
                err "$rel" "invalid category '$cat' (expected: framework|platform|service|product)"
            fi
            ;;
        source-summary)
            fm_has source_url || err "$rel" "missing type-specific field 'source_url' for type 'source-summary'"
            fm_has source_type || err "$rel" "missing type-specific field 'source_type' for type 'source-summary'"
            fm_has author || err "$rel" "missing type-specific field 'author' for type 'source-summary'"
            fm_has source_date || err "$rel" "missing type-specific field 'source_date' for type 'source-summary'"
            stype=$(fm_get source_type)
            if [ -n "$stype" ] && ! in_list "$stype" "$SOURCE_TYPES"; then
                err "$rel" "invalid source_type '$stype' (expected: $SOURCE_TYPES)"
            fi
            check_date "$rel" source_date
            ;;
    esac

    check_filename "$rel"
    check_wikilinks "$rel"
}

validate_raw() { # relpath
    local rel="$1" stype itool
    check_frontmatter_shape "$rel" || return 0
    FM=$(frontmatter "$WIKI_ROOT/$rel")

    check_required "$rel" title source_url source_type source_date author ingested ingestion_tool tags

    stype=$(fm_get source_type)
    if [ -n "$stype" ] && ! in_list "$stype" "$SOURCE_TYPES"; then
        err "$rel" "invalid source_type '$stype' (expected: $SOURCE_TYPES)"
    fi

    itool=$(fm_get ingestion_tool)
    if [ -n "$itool" ] && ! in_list "$itool" "tavily|firecrawl|local"; then
        err "$rel" "invalid ingestion_tool '$itool' (expected: tavily|firecrawl|local)"
    fi

    check_date "$rel" source_date
    check_date "$rel" ingested
    check_tags "$rel"
    check_filename "$rel"
}

validate_workspace() { # relpath
    local rel="$1"
    check_frontmatter_shape "$rel" || return 0
    FM=$(frontmatter "$WIKI_ROOT/$rel")
    check_required "$rel" title created
    check_date "$rel" created
    check_wikilinks "$rel"
}

# --- Structure integrity (always runs) ---

STRUCT_OK=1
for path in "wiki" "wiki/_index.md" "wiki/_backlinks.md" "wiki/workspaces"; do
    if [ ! -e "$WIKI_ROOT/$path" ]; then
        err "structure" "required path missing: $path"
        STRUCT_OK=0
    fi
done
OLD_IFS="$IFS"; IFS='|'
for d in $KB_DIRS; do
    if [ ! -e "$WIKI_ROOT/wiki/$d" ]; then
        err "structure" "required path missing: wiki/$d"
        STRUCT_OK=0
    fi
done
IFS="$OLD_IFS"

# --- Collect target files (relative to WIKI_ROOT) ---

TARGETS=$(mktemp)
trap 'rm -f "$ERR_FILE" "$TARGETS"' EXIT

MODE="${1:---all}"
case "$MODE" in
    --all)
        (cd "$WIKI_ROOT" && find wiki raw -type f -name '*.md' 2>/dev/null | sort) > "$TARGETS"
        ;;
    --staged)
        (cd "$WIKI_ROOT" && git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '^(wiki|raw)/.*\.md$' | sort) > "$TARGETS" || true
        ;;
    *)
        for p in "$@"; do
            p="${p#"$WIKI_ROOT"/}"
            if [ ! -f "$WIKI_ROOT/$p" ]; then
                err "$p" "path not found"
                continue
            fi
            echo "$p"
        done > "$TARGETS"
        ;;
esac

# --- Validate each target by zone ---

VALIDATED=0
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    bn=$(basename "$rel")
    case "$rel" in
        wiki/_index.md|wiki/_backlinks.md|wiki/_log.md) continue ;;
        wiki/.obsidian/*) continue ;;
    esac
    [ "$bn" = ".gitkeep" ] && continue

    case "$rel" in
        wiki/workspaces/*.md)
            validate_workspace "$rel"; VALIDATED=$((VALIDATED+1)) ;;
        wiki/*.md)
            top="${rel#wiki/}"; top="${top%%/*}"
            if in_list "$top" "$KB_DIRS"; then
                validate_kb "$rel"; VALIDATED=$((VALIDATED+1))
            else
                echo "NOTE: not a KB or workspace path, skipping: $rel" >&2
            fi
            ;;
        raw/*.md)
            validate_raw "$rel"; VALIDATED=$((VALIDATED+1)) ;;
        *)
            echo "NOTE: outside wiki/ and raw/, skipping: $rel" >&2 ;;
    esac
done < "$TARGETS"

# --- Report ---

if [ -s "$ERR_FILE" ]; then
    cat "$ERR_FILE"
    echo "Validation failed: $(wc -l < "$ERR_FILE" | tr -d ' ') issue(s)"
    exit 1
fi

echo "OK: $VALIDATED files validated"
