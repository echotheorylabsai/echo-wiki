#!/usr/bin/env bash
# Refuse redirected repository roots before any skill reads or writes managed data.
set -euo pipefail

WIKI_ROOT="${ECHO_WIKI_ROOT:-$(git rev-parse --show-toplevel)}"
ROOT_REAL=$(cd "$WIKI_ROOT" && pwd -P)

for name in _meta raw wiki; do
    path="$WIKI_ROOT/$name"
    if [ ! -d "$path" ] || [ -L "$path" ] || [ "$(cd "$path" 2>/dev/null && pwd -P)" != "$ROOT_REAL/$name" ]; then
        echo "ERROR: repository root path must be a real directory: $name" >&2
        exit 1
    fi
done

if ! command -v ruby >/dev/null 2>&1; then
    echo "ERROR: YAML parser unavailable (ruby is required)" >&2
    exit 1
fi

ruby -rdate -ryaml -e '
  config=YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date], aliases: false)
  abort "wiki config must be a mapping" unless config.is_a?(Hash)
  entries=config["entity_types"]
  abort "wiki config requires a non-empty entity_types list" unless entries.is_a?(Array) && !entries.empty?
  names={}; dirs={}
  entries.each do |entry|
    abort "each entity type requires name, dir, and label" unless entry.is_a?(Hash) && ["name", "dir", "label"].all? { |key| entry[key].is_a?(String) && !entry[key].empty? && !entry[key].match?(/[\x00-\x1f]/) }
    abort "duplicate entity type name: #{entry["name"]}" if names[entry["name"]]
    abort "duplicate entity type dir: #{entry["dir"]}" if dirs[entry["dir"]]
    names[entry["name"]]=true; dirs[entry["dir"]]=true
    puts entry["dir"]
  end
' "$WIKI_ROOT/_meta/wiki.config.yaml" | while IFS= read -r dir; do
    case "$dir" in
        ""|.|..|workspaces|*/*|*\\*|*[!a-z0-9-]*|-*|*-) echo "ERROR: unsafe configured KB directory: $dir" >&2; exit 1 ;;
    esac
    path="$WIKI_ROOT/wiki/$dir"
    if [ -e "$path" ] || [ -L "$path" ]; then
        if [ ! -d "$path" ] || [ -L "$path" ] || [ "$(cd "$path" 2>/dev/null && pwd -P)" != "$ROOT_REAL/wiki/$dir" ]; then
            echo "ERROR: configured KB directory must be a real direct child: wiki/$dir" >&2
            exit 1
        fi
    fi
done

if find "$WIKI_ROOT/raw" "$WIKI_ROOT/wiki" -type l -print -quit | grep -q .; then
    echo "ERROR: managed raw/ and wiki/ trees may not contain symlinks" >&2
    exit 1
fi
