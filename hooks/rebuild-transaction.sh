#!/usr/bin/env bash
# Crash-recoverable commit boundary for /rebuild.
# Usage: rebuild-transaction.sh prepare|commit|abort|recover|writer-acquire|writer-release
# Test-only failure injection: ECHO_REBUILD_FAIL_AFTER_BACKUP=1.
set -euo pipefail
export LC_ALL=C

WIKI_ROOT="${ECHO_WIKI_ROOT:-$(git rev-parse --show-toplevel)}"
STATE="$WIKI_ROOT/.rebuild-state"
LOCK="$WIKI_ROOT/.rebuild-lock"
STAGE="$STATE/stage"
BACKUP="$STATE/wiki.backup"
MARKER="$STATE/phase"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

tree_manifest() { # root paths...
    local root="$1"
    shift
    (cd "$root" && find "$@" \( -type d -o -type f -o -type l \) -print 2>/dev/null | sort | while IFS= read -r path; do
        if [ -L "$path" ]; then
            printf 'L %s %s\n' "$path" "$(readlink "$path")"
        elif [ -d "$path" ]; then
            printf 'D %s\n' "$path"
        else
            printf 'F '
            cksum "$path"
        fi
    done)
}

all_manifest() { # root
    tree_manifest "$1" _meta raw wiki
}

wiki_manifest() { # wiki directory
    tree_manifest "$1" .
}

preserved_manifest() { # root
    local root="$1" paths=""
    [ ! -e "$root/wiki/workspaces" ] && [ ! -L "$root/wiki/workspaces" ] || paths="$paths wiki/workspaces"
    [ ! -e "$root/wiki/.obsidian" ] && [ ! -L "$root/wiki/.obsidian" ] || paths="$paths wiki/.obsidian"
    [ ! -e "$root/wiki/_log.md" ] && [ ! -L "$root/wiki/_log.md" ] || paths="$paths wiki/_log.md"
    [ -z "$paths" ] || tree_manifest "$root" $paths
}

kb_dirs() {
    ruby -rdate -ryaml -e '
      config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
      abort "wiki config must be a mapping" unless config.is_a?(Hash)
      entries=config["entity_types"]
      abort "wiki config requires a non-empty entity_types list" unless entries.is_a?(Array) && !entries.empty?
      entries.each do |entry|
        abort "each entity type requires a dir" unless entry.is_a?(Hash) && entry["dir"].is_a?(String)
        puts entry["dir"]
      end
    ' "$WIKI_ROOT/_meta/wiki.config.yaml"
}

safe_kb_dir() { # exactly one kebab-case component
    case "$1" in
        ""|.|..|workspaces|*/*|*\\*|*[!a-z0-9-]*|-*|*-) return 1 ;;
        *) return 0 ;;
    esac
}

safe_transaction_paths() {
    [ ! -L "$STATE" ] && [ ! -L "$LOCK" ] || {
        echo "ERROR: rebuild transaction state or lock may not be a symlink" >&2
        return 1
    }
}

safe_live_directory() { # direct child of repository root
    local name="$1" root_real path_real
    [ -d "$WIKI_ROOT/$name" ] && [ ! -L "$WIKI_ROOT/$name" ] || {
        echo "ERROR: required live path is missing or symlinked: $name" >&2
        return 1
    }
    root_real=$(cd "$WIKI_ROOT" && pwd -P)
    path_real=$(cd "$WIKI_ROOT/$name" && pwd -P)
    [ "$path_real" = "$root_real/$name" ] || {
        echo "ERROR: required live path escapes repository root: $name" >&2
        return 1
    }
}

safe_live_roots() {
    safe_live_directory _meta
    safe_live_directory raw
    safe_live_directory wiki
}

safe_state_children() {
    local path
    for path in "$STAGE" "$STAGE/wiki" "$BACKUP" "$MARKER" "$STATE/wiki.failed" \
        "$STATE/live.manifest" "$STATE/current.manifest" "$STATE/wiki.manifest" \
        "$STATE/moved-wiki.manifest" "$STATE/preserved.manifest" "$STATE/staged-preserved.manifest"; do
        [ ! -L "$path" ] || {
            echo "ERROR: rebuild transaction child may not be a symlink: $path" >&2
            return 1
        }
    done
}

require_rebuild_owner() {
    [ -n "${ECHO_WIKI_REBUILD_TOKEN:-}" ] && [ -f "$LOCK/owner" ] \
        && [ "$(cat "$LOCK/owner")" = "rebuild:$ECHO_WIKI_REBUILD_TOKEN" ] || {
            echo "ERROR: no matching rebuild lock is held" >&2
            return 1
        }
}

validate_kb_dirs() {
    local dir dirs
    if ! dirs=$(kb_dirs); then
        echo "ERROR: could not parse entity_types from _meta/wiki.config.yaml" >&2
        return 1
    fi
    while IFS= read -r dir; do
        safe_kb_dir "$dir" || {
            echo "ERROR: unsafe entity_types dir '$dir' (expected one kebab-case component)" >&2
            return 1
        }
    done <<< "$dirs"
    KB_DIR_LIST="$dirs"
}

cleanup_state() {
    if [ -L "$STATE" ]; then rm -f "$STATE"; else rm -rf "$STATE"; fi
    if [ -L "$LOCK" ]; then rm -f "$LOCK"; else rm -rf "$LOCK"; fi
}

recover() { # pass force only from an intentional abort or failed commit
    local mode="${1:-}"
    safe_transaction_paths
    safe_state_children
    if [ -f "$LOCK/owner" ]; then
        case "$(cat "$LOCK/owner")" in
            writer:*)
                echo "ERROR: an ordinary wiki writer holds the lock; do not recover its active operation" >&2
                return 1
                ;;
            rebuild:*)
                if [ "$mode" != force ]; then
                    echo "ERROR: a rebuild transaction is active; verify it is abandoned, then run '$0 recover --force'" >&2
                    return 1
                fi
                ;;
            *)
                if [ "$mode" != force ]; then
                    echo "ERROR: rebuild lock owner is unknown; verify it is abandoned, then run '$0 recover --force'" >&2
                    return 1
                fi
                ;;
        esac
    elif [ -e "$LOCK" ] && [ "$mode" != force ]; then
        echo "ERROR: rebuild lock owner is missing; verify it is abandoned, then run '$0 recover --force'" >&2
        return 1
    fi
    if [ -d "$BACKUP" ]; then
        if [ -e "$WIKI_ROOT/wiki" ] || [ -L "$WIKI_ROOT/wiki" ]; then
            rm -rf "$STATE/wiki.failed"
            mv "$WIKI_ROOT/wiki" "$STATE/wiki.failed"
        fi
        mv "$BACKUP" "$WIKI_ROOT/wiki"
    fi
    cleanup_state
}

case "${1:-}" in
    prepare)
        "$SCRIPT_DIR/repository-roots.sh"
        safe_transaction_paths
        safe_state_children
        safe_live_roots
        validate_kb_dirs
        [ ! -e "$STATE" ] || { echo "ERROR: rebuild transaction state exists; run '$0 recover' before starting" >&2; exit 1; }
        if ! mkdir "$LOCK" 2>/dev/null; then
            echo "ERROR: wiki writer or rebuild lock exists; wait for it to finish" >&2
            exit 1
        fi
        rebuild_token="rebuild-$$-$RANDOM-$(date +%s)"
        printf 'rebuild:%s\n' "$rebuild_token" > "$LOCK/owner"
        mkdir -p "$STAGE"
        all_manifest "$WIKI_ROOT" > "$STATE/live.manifest"
        wiki_manifest "$WIKI_ROOT/wiki" > "$STATE/wiki.manifest"
        preserved_manifest "$WIKI_ROOT" > "$STATE/preserved.manifest"
        cp -pR "$WIKI_ROOT/_meta" "$STAGE/_meta"
        cp -pR "$WIKI_ROOT/raw" "$STAGE/raw"
        cp -pR "$WIKI_ROOT/wiki" "$STAGE/wiki"
        while IFS= read -r dir; do
            safe_kb_dir "$dir" || { cleanup_state; exit 1; }
            rm -rf "$STAGE/wiki/$dir"
            mkdir -p "$STAGE/wiki/$dir"
        done <<< "$KB_DIR_LIST"
        rm -f "$STAGE/wiki/_index.md" "$STAGE/wiki/_backlinks.md"
        printf '%s\n' "$STAGE"
        ;;
    commit)
        safe_transaction_paths
        safe_state_children
        safe_live_roots
        require_rebuild_owner
        [ -d "$LOCK" ] && [ -d "$STAGE/wiki" ] || { echo "ERROR: no prepared rebuild transaction" >&2; exit 1; }
        if ! ECHO_WIKI_ROOT="$STAGE" "$SCRIPT_DIR/validate.sh" --all; then
            echo "ERROR: staged rebuild failed validation; live wiki was not modified" >&2
            cleanup_state
            exit 1
        fi
        all_manifest "$WIKI_ROOT" > "$STATE/current.manifest"
        if ! cmp -s "$STATE/live.manifest" "$STATE/current.manifest"; then
            echo "ERROR: raw, configuration, or live wiki changed during rebuild; live wiki was not modified" >&2
            cleanup_state
            exit 1
        fi
        preserved_manifest "$STAGE" > "$STATE/staged-preserved.manifest"
        if ! cmp -s "$STATE/preserved.manifest" "$STATE/staged-preserved.manifest"; then
            echo "ERROR: staged rebuild modified preserved workspace, Obsidian, or log content" >&2
            cleanup_state
            exit 1
        fi
        printf '%s\n' prepared > "$MARKER"
        sync
        mv "$WIKI_ROOT/wiki" "$BACKUP"
        wiki_manifest "$BACKUP" > "$STATE/moved-wiki.manifest"
        if ! cmp -s "$STATE/wiki.manifest" "$STATE/moved-wiki.manifest"; then
            recover force
            echo "ERROR: live wiki changed during replacement; previous wiki restored" >&2
            exit 1
        fi
        printf '%s\n' old-moved > "$MARKER"
        sync
        if [ "${ECHO_REBUILD_FAIL_AFTER_BACKUP:-0}" = "1" ]; then
            echo "ERROR: injected failure after backup; run '$0 recover'" >&2
            exit 75
        fi
        if [ -e "$WIKI_ROOT/wiki" ] || [ -L "$WIKI_ROOT/wiki" ]; then
            recover force
            echo "ERROR: live wiki was recreated during replacement; previous wiki restored" >&2
            exit 1
        fi
        mv "$STAGE/wiki" "$WIKI_ROOT/wiki"
        printf '%s\n' new-installed > "$MARKER"
        sync
        if ! ECHO_WIKI_ROOT="$WIKI_ROOT" "$SCRIPT_DIR/validate.sh" --all; then
            recover force
            echo "ERROR: installed wiki failed validation; previous wiki restored" >&2
            exit 1
        fi
        cleanup_state
        ;;
    abort)
        require_rebuild_owner
        recover force
        ;;
    recover)
        case "${2:-}" in
            "") recover ;;
            --force) recover force ;;
            *) echo "Usage: $0 recover [--force]" >&2; exit 2 ;;
        esac
        ;;
    writer-acquire)
        safe_transaction_paths
        safe_state_children
        [ ! -e "$STATE" ] || { echo "ERROR: rebuild transaction state exists; do not write until recovery completes" >&2; exit 1; }
        if ! mkdir "$LOCK" 2>/dev/null; then
            echo "ERROR: wiki writer or rebuild lock exists" >&2
            exit 1
        fi
        writer_token="writer-$$-$RANDOM-$(date +%s)"
        printf 'writer:%s\n' "$writer_token" > "$LOCK/owner"
        printf '%s\n' "$writer_token"
        ;;
    writer-release)
        safe_transaction_paths
        safe_state_children
        [ -n "${ECHO_WIKI_WRITER_TOKEN:-}" ] && [ -f "$LOCK/owner" ] \
            && [ "$(cat "$LOCK/owner")" = "writer:$ECHO_WIKI_WRITER_TOKEN" ] || {
            echo "ERROR: no matching writer lock is held" >&2
            exit 1
        }
        rm -rf "$LOCK"
        ;;
    *)
        echo "Usage: $0 prepare|commit|abort|recover [--force]|writer-acquire|writer-release" >&2
        exit 2
        ;;
esac
