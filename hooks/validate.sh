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

root_child_is_real_dir() { # direct directory under canonical repository root
    local name="$1" root_real child_real
    [ -d "$WIKI_ROOT/$name" ] && [ ! -L "$WIKI_ROOT/$name" ] || return 1
    root_real=$(cd "$WIKI_ROOT" && pwd -P) || return 1
    child_real=$(cd "$WIKI_ROOT/$name" && pwd -P) || return 1
    [ "$child_real" = "$root_real/$name" ]
}

wiki_child_is_real_dir() { # direct configured KB directory under wiki
    local name="$1" wiki_real child_real
    [ -d "$WIKI_ROOT/wiki/$name" ] && [ ! -L "$WIKI_ROOT/wiki/$name" ] || return 1
    wiki_real=$(cd "$WIKI_ROOT/wiki" && pwd -P) || return 1
    child_real=$(cd "$WIKI_ROOT/wiki/$name" && pwd -P) || return 1
    [ "$child_real" = "$wiki_real/$name" ]
}

safe_kb_dir() { # exactly one non-reserved kebab-case component
    case "$1" in
        ""|.|..|workspaces|*/*|*\\*|*[!a-z0-9-]*|-*|*-) return 1 ;;
        *) return 0 ;;
    esac
}

# --- Config extraction (with schema-default fallbacks) ---

frontmatter() {
    awk 'BEGIN{c=0}/^---$/{c++;next}c==1{print}c==2{exit}' "$1"
}

valid_config() {
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      abort "wiki config must be a mapping" unless config.is_a?(Hash)
      entries=config["entity_types"]
      abort "wiki config requires a non-empty entity_types list" unless entries.is_a?(Array) && !entries.empty?
      names={}; dirs={}
      entries.each do |entry|
        abort "each entity type requires name, dir, and label" unless entry.is_a?(Hash) && ["name", "dir", "label"].all? { |key| entry[key].is_a?(String) && !entry[key].empty? && !entry[key].match?(/[\x00-\x1f]/) }
        abort "duplicate entity type name" if names[entry["name"]]
        abort "duplicate entity type dir" if dirs[entry["dir"]]
        names[entry["name"]]=true; dirs[entry["dir"]]=true
      end
    ' "$CONFIG" >/dev/null 2>&1
}

extract_valid_types() {
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      values=Array(config["entity_types"]).map { |entry| entry["name"] if entry.is_a?(Hash) }.compact
      puts(values.empty? ? "concept|person|tool|source-summary" : values.join("|"))
    ' "$CONFIG" 2>/dev/null || echo "concept|person|tool|source-summary"
}

extract_kb_dirs() { # pipe-delimited dir names
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      values=Array(config["entity_types"]).map { |entry| entry["dir"] if entry.is_a?(Hash) }.compact
      puts(values.empty? ? "concepts|people|tools|sources" : values.join("|"))
    ' "$CONFIG" 2>/dev/null || echo "concepts|people|tools|sources"
}

extract_domains() { # pipe-delimited; empty means "allow any"
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      puts(Array(config["domains"]).map { |entry| entry["name"] if entry.is_a?(Hash) }.compact.join("|"))
    ' "$CONFIG" 2>/dev/null || true
}

extract_source_types() {
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      values=Array(config["source_types"]).map(&:to_s)
      puts(values.empty? ? "blog|paper|tweet|substack|github|podcast|video" : values.join("|"))
    ' "$CONFIG" 2>/dev/null || echo "blog|paper|tweet|substack|github|podcast|video"
}

VALID_TYPES=$(extract_valid_types)
KB_DIRS=$(extract_kb_dirs)
DOMAINS=$(extract_domains)
SOURCE_TYPES=$(extract_source_types)

in_list() { # value pipe-list -> 0 if member
    case "|$2|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac
}

# --- Field helpers (operate on the parsed frontmatter cache in $FM_CACHE) ---

fm_has() { # key exists in the parsed YAML mapping
    printf '%s\n' "$FM_CACHE" | awk -F '\037' -v key="$1" '$1 == "K" && $2 == key { found=1 } END { exit found ? 0 : 1 }'
}

fm_get() { # key -> first scalar value
    printf '%s\n' "$FM_CACHE" | awk -F '\037' -v key="$1" '$1 == "V" && $2 == key { print $3; exit }'
}

fm_list() { # key -> one parsed YAML sequence item per line
    printf '%s\n' "$FM_CACHE" | awk -F '\037' -v key="$1" '$1 == "V" && $2 == key { print $3 }'
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

wikilink_within_wiki() { # vault-relative link without anchor
    local target="$WIKI_ROOT/wiki/$1.md" wiki_dir target_dir
    [ ! -L "$target" ] || return 1
    wiki_dir=$(cd "$WIKI_ROOT/wiki" && pwd -P) || return 1
    target_dir=$(cd "$(dirname "$target")" 2>/dev/null && pwd -P) || return 1
    case "$target_dir/$(basename "$target")" in
        "$wiki_dir"/*) return 0 ;;
        *) return 1 ;;
    esac
}

check_wikilinks() { # relpath
    local rendered link target
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        rendered="$link"
        link="${link%%#*}"
        [ -z "$link" ] && continue # anchor within the current note
        case "/$link/" in
            //*|*/../*|*/./*)
                err "$1" "wikilink escapes wiki/: [[$rendered]]"
                continue
                ;;
        esac
        target="$WIKI_ROOT/wiki/${link}.md"
        if [ ! -f "$target" ]; then
            err "$1" "broken wikilink [[$link]]"
        elif ! wikilink_within_wiki "$link"; then
            err "$1" "wikilink escapes wiki/: [[$rendered]]"
        fi
    done < <({ frontmatter "$WIKI_ROOT/$1"; body "$WIKI_ROOT/$1" | visible_markdown; } | grep -oE '\[\[[^]]+\]\]' 2>/dev/null | sed 's/^\[\[//; s/\]\]$//; s/|.*//' | sort -u || true)
}

body() { # file path
    awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$1"
}

visible_markdown() { # filter hidden/non-rendered Markdown from stdin
    awk '
        function starts_block_tag(s) {
            return s ~ /^<\/?(address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)([[:space:]\/>]|$)/
        }
        {
            line=$0
            indent=0
            while (substr(line, indent+1, 1) == " ") indent++
            if (indent <= 3) {
                text=substr(line, indent+1)
                char=substr(text, 1, 1)
                if (in_fence) {
                    if (char == fence_char) {
                        run_length=0
                        while (substr(text, run_length+1, 1) == char) run_length++
                        rest=substr(text, run_length+1)
                        if (run_length >= fence_length && rest ~ /^[[:space:]]*$/) in_fence=0
                    }
                    next
                }
            }
            if (in_html) {
                lower=tolower(line)
                if (html_end == "blank") {
                    if (line ~ /^[[:space:]]*$/) in_html=0
                } else if (index(lower, html_end) > 0) {
                    in_html=0
                }
                next
            }

            visible=""
            remaining=line
            if (in_comment) {
                if (index(line, "-->") > 0) in_comment=0
                next
            }
            block_text=line
            sub(/^[ ]{0,3}/, "", block_text)
            if (block_text ~ /^<!--/) {
                if (index(block_text, "-->") == 0) in_comment=1
                next
            }
            while ((comment_start=index(remaining, "<!--")) > 0) {
                visible=visible substr(remaining, 1, comment_start-1)
                remaining=substr(remaining, comment_start+4)
                comment_end=index(remaining, "-->")
                if (comment_end == 0) {
                    in_comment=1
                    remaining=""
                    break
                }
                remaining=substr(remaining, comment_end+3)
            }
            line=visible remaining

            indent=0
            while (substr(line, indent+1, 1) == " ") indent++
            if (indent <= 3) {
                text=substr(line, indent+1)
                char=substr(text, 1, 1)
                lower=tolower(text)
                if (lower ~ /^<(script|pre|style|textarea)([[:space:]>]|$)/) {
                    if (lower ~ /^<script([[:space:]>]|$)/) html_end="</script>"
                    else if (lower ~ /^<pre([[:space:]>]|$)/) html_end="</pre>"
                    else if (lower ~ /^<style([[:space:]>]|$)/) html_end="</style>"
                    else html_end="</textarea>"
                    if (index(lower, html_end) == 0) in_html=1
                    next
                }
                if (text ~ /^<\?/) {
                    if (index(text, "?>") == 0) { in_html=1; html_end="?>" }
                    next
                }
                if (text ~ /^<!\[CDATA\[/) {
                    if (index(text, "]]>") == 0) { in_html=1; html_end="]]>" }
                    next
                }
                if (text ~ /^<![A-Z]/) {
                    if (index(text, ">") == 0) { in_html=1; html_end=">" }
                    next
                }
                if (starts_block_tag(lower) || lower ~ /^<\/?[a-z][a-z0-9-]*([[:space:]][^>]*)?\/?>[[:space:]]*$/) {
                    in_html=1
                    html_end="blank"
                    next
                }
                if (char == "`" || char == "~") {
                    run_length=0
                    while (substr(text, run_length+1, 1) == char) run_length++
                    rest=substr(text, run_length+1)
                    if (run_length >= 3 && (char == "~" || rest !~ /`/)) {
                        in_fence=1
                        fence_char=char
                        fence_length=run_length
                        next
                    }
                }
            }
            print line
        }
    '
}

raw_heading_exists() { # absolute raw file, exact heading
    body "$1" | visible_markdown | awk -v wanted="$2" '
        /^[ ]{0,3}#{1,6}[[:space:]]+/ {
            line=$0
            sub(/^[ ]{0,3}#+[[:space:]]*/, "", line)
            sub(/[[:space:]]+#+[[:space:]]*$/, "", line)
            if (line == wanted) found=1
        }
        END { exit found ? 0 : 1 }
    '
}

source_within_raw() { # raw-relative source path
    local source_path="$WIKI_ROOT/$1" raw_dir source_dir
    [ ! -L "$source_path" ] || return 1
    raw_dir=$(cd "$WIKI_ROOT/raw" && pwd -P) || return 1
    source_dir=$(cd "$(dirname "$source_path")" 2>/dev/null && pwd -P) || return 1
    case "$source_dir/$(basename "$source_path")" in
        "$raw_dir"/*) return 0 ;;
        *) return 1 ;;
    esac
}

check_citable_heading() { # relpath
    if ! body "$WIKI_ROOT/$1" | visible_markdown | awk '
        /^[ ]{0,3}#{1,6}[[:space:]]+/ { found=1 }
        END { exit found ? 0 : 1 }
    '; then
        err "$1" "missing citable Markdown heading"
    fi
}

check_evidence() { # relpath [require-listed-source]
    local rel="$1" require_listed="${2:-0}" line locator source heading found=0

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        found=1
        locator="${line#Evidence: }"
        if ! printf '%s\n' "$locator" | grep -qE '^raw/[^#]+\.md#.+$'; then
            err "$rel" "invalid evidence locator '$line' (expected: Evidence: raw/<path>.md#<exact heading>)"
            continue
        fi
        source="${locator%%#*}"
        heading="${locator#*#}"
        case "/$source/" in
            */../*|*/./*)
                err "$rel" "evidence source escapes raw/: $source"
                continue
                ;;
        esac
        if [ ! -f "$WIKI_ROOT/$source" ]; then
            err "$rel" "evidence source does not exist: $source"
            continue
        fi
        if ! source_within_raw "$source"; then
            err "$rel" "evidence source escapes raw/: $source"
            continue
        fi
        if [ "$require_listed" -eq 1 ] && ! fm_list sources | awk -v wanted="$source" '
            $0 == wanted { found=1 }
            END { exit found ? 0 : 1 }
        '; then
            err "$rel" "evidence source not listed in sources: $source"
            continue
        fi
        if ! raw_heading_exists "$WIKI_ROOT/$source" "$heading"; then
            err "$rel" "evidence heading does not exist: $source#$heading"
        fi
    done < <(body "$WIKI_ROOT/$rel" | visible_markdown | grep '^Evidence:' || true)

    if [ "$found" -eq 0 ]; then
        err "$rel" "missing evidence locator"
    fi
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
    if ! command -v ruby >/dev/null 2>&1; then
        err "$1" "YAML parser unavailable (ruby is required)"
        return 1
    fi
    if ! FM_CACHE=$(frontmatter "$fp" | ruby -rdate -ryaml -e '
        data=YAML.safe_load(STDIN.read, permitted_classes: [Date], aliases: false)
        abort "frontmatter must be a mapping" unless data.is_a?(Hash)
        stringify=lambda { |value| value.is_a?(Date) ? value.iso8601 : value.to_s }
        data.each do |key, value|
          key=key.to_s
          abort "frontmatter key contains a control character" if key.match?(/[\x00-\x1f]/)
          puts ["K", key].join("\x1f")
          Array(value).each do |item|
            text=stringify.call(item)
            abort "frontmatter value contains a control character" if text.match?(/[\x00-\x1f]/)
            puts ["V", key, text].join("\x1f")
          end
        end
    ' 2>/dev/null); then
        err "$1" "invalid frontmatter syntax"
        return 1
    fi
    return 0
}

# --- Zone validators ---

validate_kb() { # relpath
    local rel="$1" type_val decay conf src cat stype
    check_frontmatter_shape "$rel" || return 0
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
                if [ ! -f "$WIKI_ROOT/$src" ]; then
                    err "$rel" "source path does not exist: $src"
                elif ! source_within_raw "$src"; then
                    err "$rel" "source path escapes raw/: $src"
                fi
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
    check_evidence "$rel" 1
}

validate_raw() { # relpath
    local rel="$1" stype itool
    check_frontmatter_shape "$rel" || return 0
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
    check_citable_heading "$rel"
}

validate_workspace() { # relpath
    local rel="$1"
    check_frontmatter_shape "$rel" || return 0
    check_required "$rel" title created
    check_date "$rel" created
    check_wikilinks "$rel"
    case "$rel" in
        wiki/workspaces/knowledge-maintenance/context/*.md) check_evidence "$rel" ;;
        wiki/workspaces/*/answers/*.md) check_evidence "$rel" ;;
    esac
}

# --- Structure integrity (always runs) ---

STRUCT_OK=1
if ! valid_config; then
    err "structure" "invalid _meta/wiki.config.yaml"
    STRUCT_OK=0
fi
for path in "_meta" "raw" "wiki"; do
    if ! root_child_is_real_dir "$path"; then
        err "structure" "repository root path must be a real directory: $path"
        STRUCT_OK=0
    fi
done
for path in "wiki" "wiki/_index.md" "wiki/_backlinks.md" "wiki/workspaces"; do
    if [ ! -e "$WIKI_ROOT/$path" ]; then
        err "structure" "required path missing: $path"
        STRUCT_OK=0
    fi
done
OLD_IFS="$IFS"; IFS='|'
for d in $KB_DIRS; do
    if ! safe_kb_dir "$d"; then
        err "structure" "unsafe configured KB directory: $d"
        STRUCT_OK=0
    elif [ ! -e "$WIKI_ROOT/wiki/$d" ]; then
        err "structure" "required path missing: wiki/$d"
        STRUCT_OK=0
    elif ! wiki_child_is_real_dir "$d"; then
        err "structure" "configured KB directory must be a real direct child: wiki/$d"
        STRUCT_OK=0
    fi
done
IFS="$OLD_IFS"
while IFS= read -r symlink; do
    [ -z "$symlink" ] || { err "$symlink" "managed path may not be a symlink"; STRUCT_OK=0; }
done < <(cd "$WIKI_ROOT" && find -P wiki raw -type l -print 2>/dev/null || true)

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
            if [ -L "$WIKI_ROOT/$p" ]; then
                err "$p" "managed path may not be a symlink"
                continue
            elif [ ! -f "$WIKI_ROOT/$p" ]; then
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
