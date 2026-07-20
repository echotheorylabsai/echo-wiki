#!/usr/bin/env bash
# Echo Wiki — Deterministic Index/Backlinks Generator
# Regenerates wiki/_index.md and wiki/_backlinks.md from the files on disk.
# No LLM involvement: index and backlink generation is mechanical, so it is
# done here — cheaply, reproducibly, and without silent-corruption risk.
#
# Usage: ./hooks/reindex.sh
#   Root resolution: $ECHO_WIKI_ROOT if set, else `git rev-parse --show-toplevel`.
#   Reads entity_types (name/dir/label) from _meta/wiki.config.yaml; an empty
#   entity_types list uses the four built-in defaults.
#
# Output formats (this script is the format spec):
#   _index.md      — "# Wiki Index", one "## <label>" section per configured
#                    type (config order), entries "- [[<dir>/<name>|<Title>]] — <summary>"
#                    sorted by title (case-insensitive); then "## Workspaces"
#                    with "### <workspace>" groups (blank line between groups).
#                    Entries without a summary omit the " — <summary>" tail.
#   _backlinks.md  — "# Backlinks", one "## [[<path>]]" section per indexed
#                    file (path-sorted), listing "Linked from:" entries or the
#                    explicit orphan marker "_No inbound links._".
#
# Exclusions: _index.md, _backlinks.md, _log.md, wiki/.obsidian/.
# Bash 3.2 compatible. LC_ALL=C for deterministic sorting.
set -euo pipefail
export LC_ALL=C

WIKI_ROOT="${ECHO_WIKI_ROOT:-$(git rev-parse --show-toplevel)}"
CONFIG="$WIKI_ROOT/_meta/wiki.config.yaml"
WIKI_DIR="$WIKI_ROOT/wiki"
TAB="$(printf '\t')"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK_HELPER="$SCRIPT_DIR/rebuild-transaction.sh"
OWNED_WRITER_LOCK=0

acquire_write_lock() {
    local owner token
    if [ -d "$WIKI_ROOT/.rebuild-lock" ]; then
        owner=$(cat "$WIKI_ROOT/.rebuild-lock/owner" 2>/dev/null || true)
        case "$owner" in
            writer:*) token="${owner#writer:}"; [ "${ECHO_WIKI_WRITER_TOKEN:-}" = "$token" ] ;;
            rebuild:*) token="${owner#rebuild:}"; [ "${ECHO_WIKI_REBUILD_TOKEN:-}" = "$token" ] ;;
            *) false ;;
        esac || { echo "ERROR: a different writer or rebuild owns the lock" >&2; return 1; }
    else
        ECHO_WIKI_WRITER_TOKEN="$(ECHO_WIKI_ROOT="$WIKI_ROOT" "$LOCK_HELPER" writer-acquire)" || return 1
        export ECHO_WIKI_WRITER_TOKEN
        OWNED_WRITER_LOCK=1
    fi
}

release_write_lock() {
    [ "$OWNED_WRITER_LOCK" -eq 1 ] || return 0
    ECHO_WIKI_ROOT="$WIKI_ROOT" "$LOCK_HELPER" writer-release >/dev/null || true
}

"$SCRIPT_DIR/repository-roots.sh"
acquire_write_lock
trap 'release_write_lock' EXIT

TMP_TYPES=$(mktemp)
TMP_RECORDS=$(mktemp)
TMP_PATHS=$(mktemp)
TMP_PAIRS=$(mktemp)
TMP_INDEX=$(mktemp)
TMP_BL=$(mktemp)
TMP_ORPHANS=$(mktemp)
trap 'rm -f "$TMP_TYPES" "$TMP_RECORDS" "$TMP_PATHS" "$TMP_PAIRS" "$TMP_INDEX" "$TMP_BL" "$TMP_ORPHANS"; release_write_lock' EXIT

# --- Entity types: "name<TAB>dir<TAB>label" per line, config order ---

extract_entity_types() {
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      Array(config["entity_types"]).each do |entry|
        next unless entry.is_a?(Hash)
        puts [entry["name"], entry["dir"], entry["label"]].map { |value| value.to_s.gsub("\t", " ") }.join("\t")
      end
    ' "$CONFIG" 2>/dev/null || true
}

extract_entity_types > "$TMP_TYPES"
if [ ! -s "$TMP_TYPES" ]; then
    echo "WARN: could not read entity_types from config; using built-in defaults" >&2
    printf 'concept\tconcepts\tConcepts\nperson\tpeople\tPeople\ntool\ttools\tTools\nsource-summary\tsources\tSources\n' > "$TMP_TYPES"
fi

# --- Scan wiki/: records are "zone<TAB>group<TAB>path<TAB>title<TAB>summary" ---

fm_title_summary() { # file -> "title<TAB>summary"
    awk 'BEGIN{c=0}/^---$/{c++;next}c==1{print}c==2{exit}' "$1" |
        ruby -rdate -ryaml -e '
          data=YAML.safe_load(STDIN.read, permitted_classes: [Date], aliases: false)
          abort "frontmatter must be a mapping" unless data.is_a?(Hash)
          values=[data["title"], data["summary"]].map { |value| value.nil? ? "" : value.to_s.gsub(/[\t\r\n]/, " ") }
          puts values.join("\t")
        '
}

is_kb_dir() { # dir-name -> 0 if configured
    awk -F'\t' -v d="$1" '$2==d { found=1 } END { exit found ? 0 : 1 }' "$TMP_TYPES"
}

while IFS= read -r f; do
    rel="${f#"$WIKI_DIR"/}"
    case "$rel" in
        _index.md|_backlinks.md|_log.md) continue ;;
        .obsidian/*) continue ;;
    esac
    top="${rel%%/*}"
    if [ "$top" = "$rel" ]; then
        echo "WARN: skipping unindexed file at wiki root: $rel" >&2
        continue
    fi
    ts="$(fm_title_summary "$f")"
    title="${ts%%"$TAB"*}"
    summary="${ts#*"$TAB"}"
    if [ -z "$title" ]; then
        echo "WARN: no title in frontmatter, skipping: wiki/$rel" >&2
        continue
    fi
    path="${rel%.md}"
    if [ "$top" = "workspaces" ]; then
        rest="${rel#workspaces/}"
        ws="${rest%%/*}"
        if [ "$ws" = "$rest" ]; then
            echo "WARN: workspace file outside a workspace dir, skipping: wiki/$rel" >&2
            continue
        fi
        printf 'ws\t%s\t%s\t%s\t%s\n' "$ws" "$path" "$title" "$summary" >> "$TMP_RECORDS"
    elif is_kb_dir "$top"; then
        printf 'kb\t%s\t%s\t%s\t%s\n' "$top" "$path" "$title" "$summary" >> "$TMP_RECORDS"
    else
        echo "WARN: directory not in entity_types config, skipping: wiki/$rel" >&2
    fi
done < <(find "$WIKI_DIR" -type f -name '*.md' | sort)

touch "$TMP_RECORDS"

# --- Generate _index.md ---

emit_entries() { # stdin: records sorted by title -> index lines
    while IFS="$TAB" read -r _ _ p t s; do
        if [ -n "$s" ]; then
            printf -- '- [[%s|%s]] — %s\n' "$p" "$t" "$s"
        else
            printf -- '- [[%s|%s]]\n' "$p" "$t"
        fi
    done
}

{
    printf '# Wiki Index\n'
    while IFS="$TAB" read -r _ dir label; do
        printf '\n## %s\n' "$label"
        awk -F'\t' -v d="$dir" '$1=="kb" && $2==d' "$TMP_RECORDS" | sort -f -t "$TAB" -k4,4 | emit_entries
    done < "$TMP_TYPES"
    printf '\n## Workspaces\n'
    first=1
    while IFS= read -r ws; do
        [ -z "$ws" ] && continue
        if [ "$first" -eq 1 ]; then first=0; else printf '\n'; fi
        printf '### %s\n' "$ws"
        awk -F'\t' -v w="$ws" '$1=="ws" && $2==w' "$TMP_RECORDS" | sort -f -t "$TAB" -k4,4 | emit_entries
    done < <(awk -F'\t' '$1=="ws" { print $2 }' "$TMP_RECORDS" | sort -u)
} > "$TMP_INDEX"

# --- Generate _backlinks.md ---

awk -F'\t' '{ print $3 }' "$TMP_RECORDS" | sort > "$TMP_PATHS"

while IFS="$TAB" read -r _ _ p _ _; do
    { grep -oE '\[\[[^]]+\]\]' "$WIKI_DIR/$p.md" 2>/dev/null || true; } \
        | sed 's/^\[\[//; s/\]\]$//; s/|.*//' \
        | sort -u \
        | while IFS= read -r target; do
            [ -z "$target" ] && continue
            [ "$target" = "$p" ] && continue
            printf '%s\t%s\n' "$target" "$p"
        done
done < "$TMP_RECORDS" > "$TMP_PAIRS"

sort -t "$TAB" -k1,1 -k2,2 "$TMP_PAIRS" | awk -F'\t' \
    -v pathsfile="$TMP_PATHS" -v orphansfile="$TMP_ORPHANS" '
    BEGIN {
        while ((getline p < pathsfile) > 0) { order[++n] = p; indexed[p] = 1 }
        close(pathsfile)
    }
    ($1 in indexed) && ($2 in indexed) { links[$1] = links[$1] "- [[" $2 "]]\n" }
    END {
        printf "# Backlinks\n"
        orphans = 0
        for (i = 1; i <= n; i++) {
            p = order[i]
            printf "\n## [[%s]]\n", p
            if (p in links) printf "Linked from:\n%s", links[p]
            else { printf "_No inbound links._\n"; orphans++ }
        }
        print orphans > orphansfile
    }
' > "$TMP_BL"

# --- Install atomically and report ---

mv "$TMP_INDEX" "$WIKI_DIR/_index.md"
mv "$TMP_BL" "$WIKI_DIR/_backlinks.md"
chmod 644 "$WIKI_DIR/_index.md" "$WIKI_DIR/_backlinks.md"

KB_COUNT=$(awk -F'\t' '$1=="kb"' "$TMP_RECORDS" | wc -l | tr -d ' ')
WS_COUNT=$(awk -F'\t' '$1=="ws"' "$TMP_RECORDS" | wc -l | tr -d ' ')
ORPHANS=$(cat "$TMP_ORPHANS" 2>/dev/null || echo 0)

echo "Index updated. $KB_COUNT KB articles, $WS_COUNT workspace files indexed. $ORPHANS orphan(s)."
