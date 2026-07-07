#!/usr/bin/env bash
# Echo Wiki — hook test harness
# Runs reindex.sh and validate.sh against fixture wikis and asserts on
# golden files, violation messages, and exit codes.
# Usage: bash tests/run-tests.sh
# Bash 3.2 compatible. LC_ALL=C for deterministic sorting.
set -uo pipefail
export LC_ALL=C

REPO="$(cd "$(dirname "$0")/.." && pwd)"
GOLD="$REPO/tests/goldens"
PASS=0
FAIL=0
CLEANUP=""
trap 'rm -rf $CLEANUP' EXIT

ok()     { PASS=$((PASS+1)); printf 'ok - %s\n' "$1"; }
not_ok() { FAIL=$((FAIL+1)); printf 'not ok - %s\n' "$1"; if [ -n "${2:-}" ]; then printf '  # %s\n' "$2"; fi; }

# Copies tests/fixtures/$1 into a temp dir; sets global FX to its path.
new_fixture() {
    FX="$(mktemp -d "${TMPDIR:-/tmp}/echo-wiki-test.XXXXXX")"
    CLEANUP="$CLEANUP $FX"
    cp -R "$REPO/tests/fixtures/$1/." "$FX/"
}

assert_diff() { # golden actual label
    if diff -u "$1" "$2" >/dev/null 2>&1; then
        ok "$3"
    else
        not_ok "$3" "$(diff "$1" "$2" 2>&1 | head -6 | tr '\n' '|')"
    fi
}

assert_contains() { # haystack needle label
    case "$1" in
        *"$2"*) ok "$3" ;;
        *)      not_ok "$3" "output was: $(printf '%s' "$1" | head -4 | tr '\n' '|')" ;;
    esac
}

# --- reindex.sh cases -------------------------------------------------------

test_reindex_populated() {
    new_fixture populated
    local out
    if out="$(ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" 2>&1)"; then
        assert_diff "$GOLD/populated_index.md" "$FX/wiki/_index.md" "reindex populated: _index.md matches golden"
        assert_diff "$GOLD/populated_backlinks.md" "$FX/wiki/_backlinks.md" "reindex populated: _backlinks.md matches golden"
        assert_contains "$out" "Index updated. 5 KB articles, 1 workspace files indexed. 2 orphan(s)." "reindex populated: summary line"
    else
        not_ok "reindex populated: script runs" "$out"
        not_ok "reindex populated: _index.md matches golden" "skipped"
        not_ok "reindex populated: _backlinks.md matches golden" "skipped"
    fi
}

test_reindex_empty() {
    new_fixture empty
    local out
    if out="$(ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" 2>&1)"; then
        assert_diff "$GOLD/empty_index.md" "$FX/wiki/_index.md" "reindex empty: scaffold reproduced byte-for-byte"
        assert_diff "$GOLD/empty_backlinks.md" "$FX/wiki/_backlinks.md" "reindex empty: backlinks header reproduced"
        assert_contains "$out" "Index updated. 0 KB articles, 0 workspace files indexed. 0 orphan(s)." "reindex empty: summary line"
    else
        not_ok "reindex empty: script runs" "$out"
        not_ok "reindex empty: scaffold reproduced byte-for-byte" "skipped"
        not_ok "reindex empty: backlinks header reproduced" "skipped"
    fi
}

# --- validate.sh cases ------------------------------------------------------

VOUT=""
VRC=0
run_validate() { # fixture-root args...
    local root="$1"
    shift
    VOUT="$(cd "$root" && ECHO_WIKI_ROOT="$root" "$REPO/hooks/validate.sh" "$@" 2>&1)"
    VRC=$?
}

test_validate_all_populated() {
    new_fixture populated
    run_validate "$FX" --all
    if [ "$VRC" -eq 0 ]; then
        assert_contains "$VOUT" "OK: 7 files validated" "validate populated --all: reports 7 clean files"
    else
        not_ok "validate populated --all: exits 0" "rc=$VRC out=$VOUT"
    fi
}

expect_violation() { # label path substring
    new_fixture invalid
    run_validate "$FX" "$2"
    if [ "$VRC" -ne 0 ]; then
        assert_contains "$VOUT" "$3" "validate: $1"
    else
        not_ok "validate: $1" "expected non-zero exit, got 0; out=$VOUT"
    fi
}

test_validate_all_invalid() {
    new_fixture invalid
    run_validate "$FX" --all
    if [ "$VRC" -ne 0 ]; then
        assert_contains "$VOUT" "Validation failed:" "validate invalid --all: fails with summary"
    else
        not_ok "validate invalid --all: fails with summary" "expected non-zero exit, got 0"
    fi
}

# --- pre-commit integration (added in Task 4) -------------------------------

test_precommit_integration() {
    if [ ! -f "$REPO/hooks/validate.sh" ]; then
        not_ok "pre-commit integration: validate.sh exists" "missing"
        return
    fi
    new_fixture populated
    mkdir -p "$FX/hooks"
    cp "$REPO/hooks/pre-commit.sh" "$FX/hooks/pre-commit.sh"
    cp "$REPO/hooks/validate.sh" "$FX/hooks/validate.sh"
    chmod +x "$FX/hooks/pre-commit.sh" "$FX/hooks/validate.sh"
    (
        cd "$FX" || exit 1
        git init -q .
        git config user.email test@example.com
        git config user.name Test
        ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
        git add -A
        git commit -q -m "valid fixture commit" >/dev/null 2>&1
    )
    if [ $? -eq 0 ]; then
        ok "pre-commit integration: valid staged files commit"
    else
        not_ok "pre-commit integration: valid staged files commit" "commit blocked unexpectedly"
    fi
    (
        cd "$FX" || exit 1
        printf -- '---\ntitle: "Bad"\ntype: concept\ncreated: 2026-07-01\nlast_updated: 2026-07-01\nlast_verified: 2026-07-01\ndecay_rate: sometimes\nconfidence: medium\ntags: [ai]\ndomain: [ai]\nsources: ["raw/blogs/sample-post.md"]\nrelated: []\nsummary: "Bad decay enum."\n---\n\nBody.\n' > wiki/concepts/bad.md
        git add wiki/concepts/bad.md
        git commit -q -m "invalid fixture commit" >/dev/null 2>&1
    )
    if [ $? -ne 0 ]; then
        ok "pre-commit integration: invalid staged file is blocked"
    else
        not_ok "pre-commit integration: invalid staged file is blocked" "commit passed but should have been blocked"
    fi
}

# --- run --------------------------------------------------------------------

test_reindex_populated
test_reindex_empty
test_validate_all_populated
expect_violation "missing required field"        wiki/concepts/missing-summary.md "missing required field 'summary'"
expect_violation "bad decay_rate enum"           wiki/concepts/bad-decay.md       "invalid decay_rate 'sometimes'"
expect_violation "bad date format"               wiki/concepts/bad-date.md        "invalid date format in 'created'"
expect_violation "tag outside domains"           wiki/concepts/bad-tag.md         "tag 'quantum' not in config domains"
expect_violation "empty sources"                 wiki/concepts/empty-sources.md   "sources list is empty"
expect_violation "nonexistent source path"       wiki/concepts/ghost-source.md    "source path does not exist: raw/blogs/nope.md"
expect_violation "broken wikilink"               wiki/concepts/broken-link.md     "broken wikilink [[concepts/does-not-exist]]"
expect_violation "non-kebab filename"            wiki/concepts/Bad_Name.md        "filename not kebab-case"
expect_violation "missing type-specific field"   wiki/concepts/missing-domain.md  "missing type-specific field 'domain' for type 'concept'"
expect_violation "raw missing source_url"        raw/blogs/missing-url.md         "missing required field 'source_url'"
expect_violation "raw bad ingestion_tool"        raw/blogs/bad-tool.md            "invalid ingestion_tool 'scraper'"
test_validate_all_invalid
test_precommit_integration

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
