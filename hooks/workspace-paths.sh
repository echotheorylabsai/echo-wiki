#!/usr/bin/env bash
# Guard system-managed workspace paths before a skill creates or writes them.
# Usage: workspace-paths.sh system
set -euo pipefail

WIKI_ROOT="${ECHO_WIKI_ROOT:-$(git rev-parse --show-toplevel)}"
WORKSPACES="$WIKI_ROOT/wiki/workspaces"
SYSTEM="$WORKSPACES/knowledge-maintenance"
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
trap 'release_write_lock' EXIT

"$SCRIPT_DIR/repository-roots.sh"
acquire_write_lock

require_real_child() { # parent child-name
    local parent="$1" name="$2" path="$1/$2" parent_real path_real
    [ -d "$parent" ] && [ ! -L "$parent" ] || {
        echo "ERROR: workspace parent is missing or symlinked: $parent" >&2
        return 1
    }
    parent_real=$(cd "$parent" && pwd -P)
    if [ -e "$path" ] || [ -L "$path" ]; then
        [ -d "$path" ] && [ ! -L "$path" ] || {
            echo "ERROR: workspace path is not a real directory: $path" >&2
            return 1
        }
    else
        mkdir "$path"
    fi
    path_real=$(cd "$path" && pwd -P)
    [ "$path_real" = "$parent_real/$name" ] || {
        echo "ERROR: workspace path escapes its parent: $path" >&2
        return 1
    }
}

case "${1:-}" in
    system)
        require_real_child "$WORKSPACES" knowledge-maintenance
        require_real_child "$SYSTEM" context
        require_real_child "$SYSTEM" gaps
        if find "$SYSTEM/context" "$SYSTEM/gaps" -type l -print -quit | grep -q . || [ -L "$SYSTEM/maintenance-queue.md" ]; then
            echo "ERROR: generated system workspace output may not be a symlink" >&2
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 system" >&2
        exit 2
        ;;
esac
