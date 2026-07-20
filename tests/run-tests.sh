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

rebuild_token() { sed -n 's/^rebuild://p' "$1/.rebuild-lock/owner"; }

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
        assert_contains "$out" "Index updated. 5 KB articles, 6 workspace files indexed. 6 orphan(s)." "reindex populated: summary line"
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

test_reindex_parses_inline_yaml_comments() {
    new_fixture populated
    local out
    if ruby -0pi -e 'gsub(%q(title: "Event Sourcing"), %q(title: "Event Sourcing" # valid YAML comment)); gsub(%q(summary: "Sources are the log; the wiki is a projection."), %q(summary: "Sources are the log; the wiki is a projection." # valid YAML comment))' "$FX/wiki/concepts/event-sourcing.md" \
        && out="$(ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" 2>&1)" \
        && grep -Fq '[[concepts/event-sourcing|Event Sourcing]] — Sources are the log; the wiki is a projection.' "$FX/wiki/_index.md"; then
        ok "reindex: YAML inline comments do not leak into index metadata"
    else
        not_ok "reindex: YAML inline comments do not leak into index metadata" "$out"
    fi
}

test_reindex_rejects_incomplete_entity_metadata() {
    new_fixture empty
    ruby -ryaml -e 'config=YAML.load_file(ARGV[0]); config["entity_types"][0].delete("name"); File.write(ARGV[0], YAML.dump(config))' "$FX/_meta/wiki.config.yaml"
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" >/dev/null 2>&1; then
        not_ok "reindex: incomplete entity metadata is rejected" "reindex accepted an entity type without a name"
    else
        ok "reindex: incomplete entity metadata is rejected"
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
        assert_contains "$VOUT" "OK: 12 files validated" "validate populated --all: reports 12 clean files"
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

test_maintain_path_rendering_contract() {
    local skill="$REPO/.claude/skills/maintain/SKILL.md"
    if grep -Fq 'Use vault-relative `[[wikilinks]]` only for affected files under `wiki/`.' "$skill" \
        && grep -Fq 'Render `raw/` paths and structure-level targets as plain code-formatted paths, never as wikilinks.' "$skill"; then
        ok "maintain: distinguishes vault links from non-vault paths"
    else
        not_ok "maintain: distinguishes vault links from non-vault paths" "missing path-rendering contract"
    fi
}

test_ingest_heading_contract() {
    local ingest="$REPO/.claude/skills/ingest/SKILL.md"
    local compile="$REPO/.claude/skills/compile/SKILL.md"
    if grep -Fq 'If the cleaned body has no Markdown heading, add `## Content` before writing the new raw file.' "$ingest" \
        && grep -Fq 'If a raw source has no visible Markdown heading, stop before writing KB content.' "$compile"; then
        ok "skills: ingestion guarantees citable headings"
    else
        not_ok "skills: ingestion guarantees citable headings" "missing headingless-source contract"
    fi
}

test_core_skill_contracts() {
    local context="$REPO/.claude/skills/context/SKILL.md"
    local query="$REPO/.claude/skills/query/SKILL.md"
    local maintain="$REPO/.claude/skills/maintain/SKILL.md"
    local rebuild="$REPO/.claude/skills/rebuild/SKILL.md"
    local compile="$REPO/.claude/skills/compile/SKILL.md"

    if grep -Fq 'Build the complete replacement in a staging root before deleting any live KB file.' "$rebuild" \
        && grep -Fq 'Validate the staging root with `./hooks/validate.sh --all` before replacing live files.' "$rebuild" \
        && grep -Fq 'If staging or validation fails, remove the staging root and leave the live wiki unchanged.' "$rebuild" \
        && grep -Fq 'Any source replay failure aborts the staged rebuild' "$rebuild"; then
        ok "skills: rebuild stages and validates before destructive work"
    else
        not_ok "skills: rebuild stages and validates before destructive work" "missing transactional staging contract"
    fi
    if grep -Fq 'Every factual Key Points list must be followed immediately by its supporting `Evidence:` line or lines.' "$compile"; then
        ok "skills: source-summary key points require adjacent evidence"
    else
        not_ok "skills: source-summary key points require adjacent evidence" "missing list evidence contract"
    fi
    if grep -Fq 'Write the selected collision-safe path under `wiki/workspaces/knowledge-maintenance/context/`' "$context" \
        && grep -Fq 'Run `./hooks/validate.sh wiki/workspaces/knowledge-maintenance/context/<file>.md`, then `./hooks/reindex.sh`.' "$context" \
        && grep -Fq 'Never write to KB type directories, `raw/`, or another actor' "$context"; then
        ok "skills: context output, validation, and mutation boundaries are explicit"
    else
        not_ok "skills: context output, validation, and mutation boundaries are explicit" "incomplete context contract"
    fi
    if grep -Fq 'For a matching existing gap, preserve its original `created` date and append:' "$query" \
        && grep -Fq 'Validate and reindex every new or updated gap note.' "$query" \
        && grep -Fq '`/query` may write only its deduplicated gap note' "$query" \
        && grep -Fq 'Compare the normalized `## Question` text before treating a candidate as a repeat.' "$query" \
        && grep -Fq 'If no candidate matches, use the first unused numeric suffix' "$query"; then
        ok "skills: query gap update, validation, and mutation boundaries are explicit"
    else
        not_ok "skills: query gap update, validation, and mutation boundaries are explicit" "incomplete query contract"
    fi
    if grep -Fq 'Resolve the actor from trusted session identity or `default_workspace`; never use a question-supplied path.' "$query" \
        && grep -Fq 'Reject `knowledge-maintenance` and require the actor to be one kebab-case path component.' "$query" \
        && grep -Fq 'Compare normalized answer identity before overwriting a candidate' "$query" \
        && grep -Fq 'first unused numeric suffix' "$query"; then
        ok "skills: query actor and durable-answer paths are collision-safe and contained"
    else
        not_ok "skills: query actor and durable-answer paths are collision-safe and contained" "unsafe actor or answer filename contract"
    fi
    if grep -Fq 'only `_index.md`, `_backlinks.md`, `maintenance-queue.md`, and `_log.md` may change during `/maintain`' "$maintain" \
        && grep -Fq 'Include all deterministic validation failures in the first section' "$maintain" \
        && grep -Fq 'all gap notes in the third ordered by recurrence' "$maintain"; then
        ok "skills: maintenance inputs, ordering, and mutation boundaries are explicit"
    else
        not_ok "skills: maintenance inputs, ordering, and mutation boundaries are explicit" "incomplete maintenance contract"
    fi
}

test_context_filename_contract() {
    local context="$REPO/.claude/skills/context/SKILL.md"
    if grep -Fq 'Compare normalized product-area identity before overwriting a candidate' "$context" \
        && grep -Fq 'first unused numeric suffix' "$context" \
        && grep -Fq 'complete filename remains at most 60 characters' "$context"; then
        ok "skills: context filenames preserve identity across slug collisions"
    else
        not_ok "skills: context filenames preserve identity across slug collisions" "missing context collision contract"
    fi
}

test_rebuild_recovery_contract() {
    local rebuild="$REPO/.claude/skills/rebuild/SKILL.md"
    if grep -Fq 'Acquire an exclusive rebuild lock before snapshotting' "$rebuild" \
        && grep -Fq 'Recompute and compare the snapshot manifest immediately before commit.' "$rebuild" \
        && grep -Fq 'Write and fsync a recovery marker before the first directory rename.' "$rebuild" \
        && grep -Fq 'replace the entire `wiki/` directory as one unit' "$rebuild" \
        && grep -Fq 'Do not run recovery automatically' "$rebuild" \
        && grep -Fq 'recover --force' "$rebuild"; then
        ok "skills: rebuild has lock, stale-snapshot detection, and crash recovery"
    else
        not_ok "skills: rebuild has lock, stale-snapshot detection, and crash recovery" "missing executable recovery protocol"
    fi
}

test_rebuild_staging_failure_preserves_live_kb() {
    new_fixture populated
    local stage live_before live_after
    stage="$(mktemp -d "${TMPDIR:-/tmp}/echo-wiki-stage-test.XXXXXX")"
    CLEANUP="$CLEANUP $stage"
    cp "$REPO/tests/fixtures/invalid/raw/blogs/alternate.md" "$FX/raw/blogs/alternate.md"
    rm "$FX/raw/blogs/sample-post.md"
    live_before="$(find "$FX/wiki/concepts" "$FX/wiki/decisions" "$FX/wiki/people" "$FX/wiki/sources" "$FX/wiki/tools" -type f -name '*.md' -exec cksum {} \; | sort)"

    cp -R "$FX/." "$stage/"
    find "$stage/wiki/concepts" "$stage/wiki/decisions" "$stage/wiki/people" "$stage/wiki/sources" "$stage/wiki/tools" -type f -name '*.md' -delete
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    run_validate "$stage" --all
    live_after="$(find "$FX/wiki/concepts" "$FX/wiki/decisions" "$FX/wiki/people" "$FX/wiki/sources" "$FX/wiki/tools" -type f -name '*.md' -exec cksum {} \; | sort)"

    if [ "$VRC" -ne 0 ] && [ "$live_before" = "$live_after" ]; then
        ok "workflow: failed staged rebuild preserves live KB"
    else
        not_ok "workflow: failed staged rebuild preserves live KB" "staging_rc=$VRC or live KB changed"
    fi
}

test_rebuild_transaction_recovery() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token before after rc
    before="$(find "$FX/wiki" -type f -exec cksum {} \; | sort)"
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    ECHO_REBUILD_FAIL_AFTER_BACKUP=1 ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" commit >/dev/null 2>&1
    rc=$?
    ECHO_WIKI_ROOT="$FX" "$helper" recover --force
    after="$(find "$FX/wiki" -type f -exec cksum {} \; | sort)"
    if [ "$rc" -eq 75 ] && [ "$before" = "$after" ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "workflow: interrupted directory swap restores complete previous wiki"
    else
        not_ok "workflow: interrupted directory swap restores complete previous wiki" "rc=$rc or recovery mismatch"
    fi
}

test_rebuild_rejects_unsafe_entity_dir() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    cp "$REPO/tests/fixtures/malicious-entity-config.yaml" "$FX/_meta/wiki.config.yaml"
    mkdir "$FX/sentinel"
    : > "$FX/sentinel/keep"
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -f "$FX/sentinel/keep" ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: unsafe entity directory is rejected before staging mutation"
    else
        not_ok "rebuild: unsafe entity directory is rejected before staging mutation" "rc=$rc or sentinel/state changed"
    fi
}

test_rebuild_rejects_unparseable_config_before_mutation() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    printf 'entity_types: [\n' > "$FX/_meta/wiki.config.yaml"
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: unparseable config is rejected before transaction mutation"
    else
        not_ok "rebuild: unparseable config is rejected before transaction mutation" "rc=$rc or transaction state exists"
    fi
}

test_rebuild_rejects_incomplete_entity_metadata_before_mutation() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    ruby -ryaml -e 'config=YAML.load_file(ARGV[0]); config["entity_types"][0].delete("label"); File.write(ARGV[0], YAML.dump(config))' "$FX/_meta/wiki.config.yaml"
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: incomplete entity metadata is rejected before transaction mutation"
    else
        not_ok "rebuild: incomplete entity metadata is rejected before transaction mutation" "rc=$rc or transaction state exists"
    fi
}

test_validate_rejects_unparseable_config() {
    new_fixture empty
    printf 'entity_types: [\n' > "$FX/_meta/wiki.config.yaml"
    run_validate "$FX" --all
    if [ "$VRC" -ne 0 ]; then
        assert_contains "$VOUT" "invalid _meta/wiki.config.yaml" "validate: unparseable config is rejected"
    else
        not_ok "validate: unparseable config is rejected" "malformed config was accepted"
    fi
}

test_rebuild_rejects_reserved_workspace_entity_dir() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    cp "$REPO/tests/fixtures/reserved-workspaces-config.yaml" "$FX/_meta/wiki.config.yaml"
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    run_validate "$FX" --all
    if [ "$rc" -ne 0 ] && [ "$VRC" -ne 0 ] && [ -d "$FX/wiki/workspaces/my-notes" ]; then
        ok "rebuild: workspaces cannot be configured as a KB directory"
    else
        not_ok "rebuild: workspaces cannot be configured as a KB directory" "rc=$rc validate_rc=$VRC or workspace was altered"
    fi
}

test_rebuild_rejects_symlinked_live_wiki() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    mv "$FX/wiki" "$FX/external-wiki"
    : > "$FX/external-wiki/concepts/sentinel"
    ln -s external-wiki "$FX/wiki"
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -f "$FX/external-wiki/concepts/sentinel" ] && [ -L "$FX/wiki" ]; then
        ok "rebuild: symlinked live wiki is rejected before staging mutation"
    else
        not_ok "rebuild: symlinked live wiki is rejected before staging mutation" "rc=$rc or external sentinel changed"
    fi
}

test_validate_rejects_symlinked_roots() {
    new_fixture populated
    local rc
    mv "$FX/raw" "$FX/outside-raw"
    ln -s outside-raw "$FX/raw"
    run_validate "$FX" wiki/concepts/event-sourcing.md
    rc=$VRC
    if [ "$rc" -ne 0 ]; then
        assert_contains "$VOUT" "repository root path must be a real directory: raw" "validate: symlinked raw root is rejected"
    else
        not_ok "validate: symlinked raw root is rejected" "symlinked raw root accepted"
    fi

    new_fixture populated
    mv "$FX/wiki" "$FX/outside-wiki"
    ln -s outside-wiki "$FX/wiki"
    run_validate "$FX" wiki/concepts/event-sourcing.md
    rc=$VRC
    if [ "$rc" -ne 0 ]; then
        assert_contains "$VOUT" "repository root path must be a real directory: wiki" "validate: symlinked wiki root is rejected"
    else
        not_ok "validate: symlinked wiki root is rejected" "symlinked wiki root accepted"
    fi

    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" >/dev/null 2>&1; then
        not_ok "reindex: symlinked wiki root is rejected" "symlinked wiki root accepted"
    else
        ok "reindex: symlinked wiki root is rejected"
    fi
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/workspace-paths.sh" system >/dev/null 2>&1; then
        not_ok "workspace: symlinked wiki root is rejected" "symlinked wiki root accepted"
    else
        ok "workspace: symlinked wiki root is rejected"
    fi
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/repository-roots.sh" >/dev/null 2>&1; then
        not_ok "roots: symlinked wiki root is rejected" "symlinked wiki root accepted"
    else
        ok "roots: symlinked wiki root is rejected"
    fi
}

test_validate_rejects_symlinked_managed_children() {
    new_fixture populated
    local rc
    mv "$FX/wiki/concepts" "$FX/external-concepts"
    ln -s ../external-concepts "$FX/wiki/concepts"
    run_validate "$FX" wiki/concepts/event-sourcing.md
    rc=$VRC
    if [ "$rc" -ne 0 ]; then
        assert_contains "$VOUT" "configured KB directory must be a real direct child: wiki/concepts" "validate: symlinked configured KB directory is rejected"
    else
        not_ok "validate: symlinked configured KB directory is rejected" "symlinked KB directory accepted"
    fi

    new_fixture empty
    mkdir "$FX/wiki/workspaces/knowledge-maintenance"
    mkdir "$FX/wiki/workspaces/knowledge-maintenance/context" "$FX/wiki/workspaces/knowledge-maintenance/gaps"
    ln -s /tmp "$FX/wiki/workspaces/knowledge-maintenance/gaps/future-gap.md"
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/workspace-paths.sh" system >/dev/null 2>&1; then
        not_ok "workspace: symlinked generated output is rejected" "symlinked output accepted"
    else
        ok "workspace: symlinked generated output is rejected"
    fi
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/repository-roots.sh" >/dev/null 2>&1; then
        not_ok "roots: symlinked managed child is rejected" "symlinked output accepted"
    else
        ok "roots: symlinked managed child is rejected"
    fi
}

test_rebuild_empty_directory_snapshot() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token rc
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    mkdir "$FX/wiki/workspaces/concurrent-empty"
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" commit >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -d "$FX/wiki/workspaces/concurrent-empty" ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: empty workspace directory change aborts stale snapshot"
    else
        not_ok "rebuild: empty workspace directory change aborts stale snapshot" "rc=$rc or directory was lost"
    fi
}

test_rebuild_writer_lock() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" owner_token rc
    owner_token="$(ECHO_WIKI_ROOT="$FX" "$helper" writer-acquire)"
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_WRITER_TOKEN=wrong "$helper" writer-release >/dev/null 2>&1
    rc=$?
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    if [ "$rc" -ne 0 ] && [ -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: only the writer that acquired a lock can release it"
    else
        not_ok "rebuild: only the writer that acquired a lock can release it" "unauthorized release succeeded"
    fi
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null 2>&1
    rc=$?
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_WRITER_TOKEN="$owner_token" "$helper" writer-release >/dev/null
    if [ "$rc" -ne 0 ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: cooperative writer lock blocks a rebuild snapshot"
    else
        not_ok "rebuild: cooperative writer lock blocks a rebuild snapshot" "rc=$rc or lock remained"
    fi
}

test_recovery_preserves_active_writer_lock() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" owner_token rc
    owner_token="$(ECHO_WIKI_ROOT="$FX" "$helper" writer-acquire)"
    ECHO_WIKI_ROOT="$FX" "$helper" recover >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -d "$FX/.rebuild-lock" ] && [ "$(cat "$FX/.rebuild-lock/owner")" = "writer:$owner_token" ]; then
        ok "rebuild: recovery preserves an active ordinary writer lock"
    else
        not_ok "rebuild: recovery preserves an active ordinary writer lock" "rc=$rc or writer lock was removed"
    fi
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_WRITER_TOKEN="$owner_token" "$helper" writer-release >/dev/null
}

test_recovery_preserves_active_rebuild() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token rc
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$FX" "$helper" recover >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -d "$FX/.rebuild-state" ] && [ -d "$FX/.rebuild-lock" ] && [ -d "$stage/wiki" ]; then
        ok "rebuild: recovery preserves an active rebuild transaction"
    else
        not_ok "rebuild: recovery preserves an active rebuild transaction" "rc=$rc or rebuild state was removed"
    fi
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" abort >/dev/null
}

test_rebuild_commit_requires_owner_token() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token rc
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    ECHO_WIKI_ROOT="$FX" "$helper" commit >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ -d "$FX/.rebuild-state" ] && [ -d "$FX/.rebuild-lock" ] && [ -d "$FX/wiki/concepts" ]; then
        ok "rebuild: commit requires the prepare owner's token"
    else
        not_ok "rebuild: commit requires the prepare owner's token" "rc=$rc or live wiki/state changed"
    fi
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" abort >/dev/null
}

test_rebuild_invalid_stage_cleans_up_transaction() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token rc
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    printf -- '---\ntitle: "Bad"\n---\n' > "$stage/wiki/concepts/bad.md"
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" commit >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ] && [ -d "$FX/wiki/concepts" ]; then
        ok "rebuild: invalid staging cleanup preserves live wiki"
    else
        not_ok "rebuild: invalid staging cleanup preserves live wiki" "rc=$rc or transaction state remained"
    fi
}

test_direct_writers_respect_rebuild_lock() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" token
    ECHO_WIKI_ROOT="$FX" "$helper" prepare >/dev/null
    token="$(rebuild_token "$FX")"
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" >/dev/null 2>&1; then
        not_ok "reindex: direct write is blocked by an active rebuild" "reindex bypassed rebuild lock"
    else
        ok "reindex: direct write is blocked by an active rebuild"
    fi
    if ECHO_WIKI_ROOT="$FX" "$REPO/hooks/workspace-paths.sh" system >/dev/null 2>&1; then
        not_ok "workspace: direct write is blocked by an active rebuild" "workspace helper bypassed rebuild lock"
    else
        ok "workspace: direct write is blocked by an active rebuild"
    fi
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" abort >/dev/null
}

test_rebuild_rejects_symlinked_recovery_child() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token rc
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    ECHO_REBUILD_FAIL_AFTER_BACKUP=1 ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" commit >/dev/null 2>&1
    rm -rf "$FX/.rebuild-state/wiki.backup"
    ln -s /tmp "$FX/.rebuild-state/wiki.backup"
    ECHO_WIKI_ROOT="$FX" "$helper" recover --force >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ ! -L "$FX/wiki" ]; then
        ok "rebuild: symlinked transaction child is never installed during recovery"
    else
        not_ok "rebuild: symlinked transaction child is never installed during recovery" "rc=$rc or live wiki became symlink"
    fi
}

test_rebuild_recovers_over_dangling_live_wiki_link() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" rc
    mkdir "$FX/.rebuild-state" "$FX/.rebuild-lock"
    mv "$FX/wiki" "$FX/.rebuild-state/wiki.backup"
    : > "$FX/.rebuild-lock/owner"
    printf '%s\n' rebuild > "$FX/.rebuild-lock/owner"
    ln -s /private/tmp/echo-wiki-missing "$FX/wiki"
    ECHO_WIKI_ROOT="$FX" "$helper" recover --force >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && [ -d "$FX/wiki" ] && [ ! -L "$FX/wiki" ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "rebuild: recovery replaces a dangling live wiki symlink"
    else
        not_ok "rebuild: recovery replaces a dangling live wiki symlink" "rc=$rc or recovery state remained"
    fi
}

test_system_workspace_path_guard() {
    new_fixture empty
    local guard="$REPO/hooks/workspace-paths.sh" rc
    ln -s /tmp "$FX/wiki/workspaces/knowledge-maintenance"
    ECHO_WIKI_ROOT="$FX" "$guard" system >/dev/null 2>&1
    rc=$?
    if [ -x "$guard" ] && [ "$rc" -ne 0 ]; then
        ok "workspace: system-generated paths reject symlink escape"
    else
        not_ok "workspace: system-generated paths reject symlink escape" "symlinked system workspace accepted"
    fi
}

test_writer_lock_skill_contracts() {
    local skill
    for skill in "$REPO/.claude/skills/ingest/SKILL.md" "$REPO/.claude/skills/compile/SKILL.md" "$REPO/.claude/skills/index/SKILL.md" "$REPO/.claude/skills/lint/SKILL.md" "$REPO/.claude/skills/query/SKILL.md" "$REPO/.claude/skills/context/SKILL.md" "$REPO/.claude/skills/maintain/SKILL.md"; do
        if ! grep -Fq 'repository-roots.sh || stop' "$skill" || ! grep -Fq 'rebuild-transaction.sh writer-acquire' "$skill" || ! grep -Fq 'rebuild-transaction.sh writer-release' "$skill"; then
            not_ok "skills: all wiki writers use the shared rebuild lock" "missing lock contract in $skill"
            return
        fi
    done
    if grep -Fq 'workspace-paths.sh system' "$REPO/.claude/skills/query/SKILL.md" \
        && grep -Fq 'workspace-paths.sh system' "$REPO/.claude/skills/context/SKILL.md" \
        && grep -Fq 'workspace-paths.sh system' "$REPO/.claude/skills/maintain/SKILL.md"; then
        ok "skills: all system-generated workspace paths are guarded"
    else
        not_ok "skills: all system-generated workspace paths are guarded" "missing system workspace containment contract"
    fi
}

test_rebuild_stale_snapshot_abort() {
    new_fixture empty
    local helper="$REPO/hooks/rebuild-transaction.sh" stage token before after rc
    before="$(find "$FX/wiki" -type f -exec cksum {} \; | sort)"
    stage="$(ECHO_WIKI_ROOT="$FX" "$helper" prepare)"
    token="$(rebuild_token "$FX")"
    ECHO_WIKI_ROOT="$stage" "$REPO/hooks/reindex.sh" >/dev/null
    cp "$REPO/tests/fixtures/invalid/raw/blogs/alternate.md" "$FX/raw/alternate.md"
    ECHO_WIKI_ROOT="$FX" ECHO_WIKI_REBUILD_TOKEN="$token" "$helper" commit >/dev/null 2>&1
    rc=$?
    after="$(find "$FX/wiki" -type f -exec cksum {} \; | sort)"
    if [ "$rc" -ne 0 ] && [ "$before" = "$after" ] && [ ! -e "$FX/.rebuild-state" ] && [ ! -e "$FX/.rebuild-lock" ]; then
        ok "workflow: stale rebuild snapshot aborts before live replacement"
    else
        not_ok "workflow: stale rebuild snapshot aborts before live replacement" "rc=$rc or live wiki changed"
    fi
}

test_hash_and_indented_heading_evidence() {
    new_fixture invalid
    run_validate "$FX" raw/blogs/csharp.md wiki/concepts/csharp.md
    if [ "$VRC" -eq 0 ]; then
        ok "validate: indented heading containing hash is citable"
    else
        not_ok "validate: indented heading containing hash is citable" "rc=$VRC out=$VOUT"
    fi
}

test_engineering_workflow_artifacts() {
    new_fixture populated
    local queue="$FX/wiki/workspaces/knowledge-maintenance/maintenance-queue.md"
    local before after kb_before kb_after gap_count repeats collisions fix review learn improve

    kb_before="$(find "$FX/wiki/concepts" "$FX/wiki/decisions" "$FX/wiki/people" "$FX/wiki/sources" "$FX/wiki/tools" -type f -name '*.md' -exec cksum {} \; | sort)"
    ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" >/dev/null
    run_validate "$FX" --all
    kb_after="$(find "$FX/wiki/concepts" "$FX/wiki/decisions" "$FX/wiki/people" "$FX/wiki/sources" "$FX/wiki/tools" -type f -name '*.md' -exec cksum {} \; | sort)"
    before="$(find "$FX/wiki/workspaces/knowledge-maintenance" -type f -name '*.md' -exec cksum {} \; | sort)"
    find "$FX/wiki/concepts" "$FX/wiki/decisions" "$FX/wiki/people" "$FX/wiki/sources" "$FX/wiki/tools" -type f -name '*.md' -delete
    ECHO_WIKI_ROOT="$FX" "$REPO/hooks/reindex.sh" >/dev/null
    after="$(find "$FX/wiki/workspaces/knowledge-maintenance" -type f -name '*.md' -exec cksum {} \; | sort)"
    gap_count="$(find "$FX/wiki/workspaces/knowledge-maintenance/gaps" -type f -name '*.md' | wc -l | tr -d ' ')"
    repeats="$(grep -c '^## Repeated On$' "$FX/wiki/workspaces/knowledge-maintenance/gaps/how-do-we-replay-events.md")"
    fix="$(grep -n '^## Fix First' "$queue" | cut -d: -f1)"
    review="$(grep -n '^## Review Next' "$queue" | cut -d: -f1)"
    learn="$(grep -n '^## Learn Next' "$queue" | cut -d: -f1)"
    improve="$(grep -n '^## Improve Later' "$queue" | cut -d: -f1)"

    if [ "$before" = "$after" ]; then
        ok "workflow: rebuild simulation preserves system workspace content"
    else
        not_ok "workflow: rebuild simulation preserves system workspace content" "workspace hashes changed"
    fi
    if [ "$VRC" -eq 0 ] && [ "$kb_before" = "$kb_after" ]; then
        ok "workflow: maintenance rails preserve factual KB content"
    else
        not_ok "workflow: maintenance rails preserve factual KB content" "validation failed or KB hashes changed"
    fi
    if [ "$repeats" -eq 2 ]; then
        ok "workflow: repeated query gap remains deduplicated"
    else
        not_ok "workflow: repeated query gap remains deduplicated" "repeated_on=$repeats"
    fi
    collisions="$(grep -h -A2 '^## Question$' "$FX/wiki/workspaces/knowledge-maintenance/gaps/what-does-c-require.md" "$FX/wiki/workspaces/knowledge-maintenance/gaps/what-does-c-require-2.md" | grep '^What does C[#]* require?$' | sort -u | wc -l | tr -d ' ')"
    if [ "$gap_count" -eq 3 ] && [ "$collisions" -eq 2 ]; then
        ok "workflow: colliding query slugs preserve distinct questions"
    else
        not_ok "workflow: colliding query slugs preserve distinct questions" "files=$gap_count distinct_questions=$collisions"
    fi
    if [ "$fix" -lt "$review" ] && [ "$review" -lt "$learn" ] && [ "$learn" -lt "$improve" ]; then
        ok "workflow: maintenance queue preserves priority order"
    else
        not_ok "workflow: maintenance queue preserves priority order" "section order is incorrect"
    fi
}

test_symlink_evidence_escape() {
    new_fixture invalid
    ln -s ../../wiki/_index.md "$FX/raw/blogs/symlink.md"
    run_validate "$FX" wiki/concepts/symlink-evidence.md
    if [ "$VRC" -ne 0 ]; then
        assert_contains "$VOUT" "evidence source escapes raw/: raw/blogs/symlink.md" "validate: symlink evidence escape"
    else
        not_ok "validate: symlink evidence escape" "expected non-zero exit, got 0; out=$VOUT"
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
        printf 'entity_types: [\n' > _meta/wiki.config.yaml
        git add _meta/wiki.config.yaml
        git show HEAD:_meta/wiki.config.yaml > _meta/wiki.config.yaml
        hooks/pre-commit.sh >/dev/null 2>&1
    )
    if [ $? -ne 0 ]; then
        ok "pre-commit integration: staged malformed config is blocked"
    else
        not_ok "pre-commit integration: staged malformed config is blocked" "hook read the working-tree config instead of the staged config"
    fi
    (
        cd "$FX" || exit 1
        git reset -q HEAD
        cp _meta/wiki.config.yaml staged-config-before-test.yaml
        ruby -ryaml -e 'config=YAML.load_file(ARGV[0]); config["source_types"]=["paper"]; File.write(ARGV[0], YAML.dump(config))' _meta/wiki.config.yaml
        git add _meta/wiki.config.yaml
        cp staged-config-before-test.yaml _meta/wiki.config.yaml
        rm staged-config-before-test.yaml
        hooks/pre-commit.sh >/dev/null 2>&1
    )
    if [ $? -ne 0 ]; then
        ok "pre-commit integration: staged config semantics validate staged content"
    else
        not_ok "pre-commit integration: staged config semantics validate staged content" "hook mixed staged config with working-tree content"
    fi
    (
        cd "$FX" || exit 1
        git reset -q HEAD
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
test_reindex_parses_inline_yaml_comments
test_reindex_rejects_incomplete_entity_metadata
test_validate_all_populated
expect_violation "missing required field"        wiki/concepts/missing-summary.md "missing required field 'summary'"
expect_violation "bad decay_rate enum"           wiki/concepts/bad-decay.md       "invalid decay_rate 'sometimes'"
expect_violation "bad date format"               wiki/concepts/bad-date.md        "invalid date format in 'created'"
expect_violation "tag outside domains"           wiki/concepts/bad-tag.md         "tag 'quantum' not in config domains"
expect_violation "empty sources"                 wiki/concepts/empty-sources.md   "sources list is empty"
expect_violation "nonexistent source path"       wiki/concepts/ghost-source.md    "source path does not exist: raw/blogs/nope.md"
expect_violation "source path traversal"         wiki/concepts/traversal-source.md "source path escapes raw/: raw/../wiki/_index.md"
expect_violation "broken wikilink"               wiki/concepts/broken-link.md     "broken wikilink [[concepts/does-not-exist]]"
expect_violation "traversal wikilink"            wiki/concepts/traversal-wikilink.md "wikilink escapes wiki/: [[../raw/blogs/present]]"
expect_violation "non-kebab filename"            wiki/concepts/Bad_Name.md        "filename not kebab-case"
expect_violation "missing type-specific field"   wiki/concepts/missing-domain.md  "missing type-specific field 'domain' for type 'concept'"
expect_violation "raw missing source_url"        raw/blogs/missing-url.md         "missing required field 'source_url'"
expect_violation "malformed frontmatter"         wiki/concepts/malformed-frontmatter.md "invalid frontmatter syntax"
expect_violation "unclosed quoted frontmatter"   wiki/concepts/unclosed-quoted-frontmatter.md "invalid frontmatter syntax"
expect_violation "invalid YAML escape"           wiki/concepts/invalid-yaml-escape.md "invalid frontmatter syntax"
expect_violation "invalid YAML flow"             wiki/concepts/invalid-flow-frontmatter.md "invalid frontmatter syntax"
expect_violation "raw bad ingestion_tool"        raw/blogs/bad-tool.md            "invalid ingestion_tool 'scraper'"
expect_violation "raw missing citable heading"   raw/blogs/headingless.md          "missing citable Markdown heading"
expect_violation "missing evidence locator"      wiki/concepts/missing-evidence.md "missing evidence locator"
expect_violation "bad evidence heading"          wiki/concepts/bad-evidence-heading.md "evidence heading does not exist: raw/blogs/present.md#Missing Heading"
expect_violation "bad context evidence path"     wiki/workspaces/knowledge-maintenance/context/bad-evidence-path.md "evidence source does not exist: raw/blogs/missing.md"
expect_violation "traversal evidence path"       wiki/concepts/traversal-evidence.md "evidence source escapes raw/: raw/../wiki/_index.md"
expect_violation "fenced evidence locator"       wiki/concepts/fenced-evidence.md "missing evidence locator"
expect_violation "fenced raw heading"            wiki/concepts/fenced-heading.md "evidence heading does not exist: raw/blogs/fenced-heading.md#Example Only"
expect_violation "frontmatter evidence heading"  wiki/concepts/frontmatter-heading.md "evidence heading does not exist: raw/blogs/hidden-headings.md#Frontmatter Only"
expect_violation "HTML-comment evidence heading" wiki/concepts/html-comment-heading.md "evidence heading does not exist: raw/blogs/hidden-headings.md#Comment Only"
expect_violation "HTML-comment evidence locator" wiki/concepts/html-comment-evidence.md "missing evidence locator"
expect_violation "HTML-comment block heading"   wiki/concepts/comment-block-heading.md "evidence heading does not exist: raw/blogs/comment-block-heading.md#Hidden Heading"
expect_violation "HTML-block raw heading"       raw/blogs/html-block-heading.md "missing citable Markdown heading"
expect_violation "HTML-block evidence locator"  wiki/concepts/html-block-evidence.md "missing evidence locator"
expect_violation "unlisted evidence source"      wiki/concepts/unlisted-evidence-source.md "evidence source not listed in sources: raw/blogs/alternate.md"
expect_violation "answer traversal evidence"     wiki/workspaces/my-notes/answers/escaping-evidence.md "evidence source escapes raw/: raw/../../etc/passwd.md"
test_symlink_evidence_escape
test_validate_all_invalid
test_hash_and_indented_heading_evidence
new_fixture invalid
run_validate "$FX" wiki/concepts/inline-comment-frontmatter.md
if [ "$VRC" -eq 0 ]; then ok "validate: YAML inline comment remains valid"; else not_ok "validate: YAML inline comment remains valid" "$VOUT"; fi
test_precommit_integration
test_maintain_path_rendering_contract
test_ingest_heading_contract
test_core_skill_contracts
test_context_filename_contract
test_rebuild_recovery_contract
test_rebuild_staging_failure_preserves_live_kb
test_rebuild_transaction_recovery
test_rebuild_stale_snapshot_abort
test_rebuild_rejects_unsafe_entity_dir
test_rebuild_rejects_unparseable_config_before_mutation
test_rebuild_rejects_incomplete_entity_metadata_before_mutation
test_validate_rejects_unparseable_config
test_rebuild_rejects_reserved_workspace_entity_dir
test_rebuild_rejects_symlinked_live_wiki
test_validate_rejects_symlinked_roots
test_validate_rejects_symlinked_managed_children
test_rebuild_empty_directory_snapshot
test_rebuild_writer_lock
test_recovery_preserves_active_writer_lock
test_recovery_preserves_active_rebuild
test_rebuild_commit_requires_owner_token
test_rebuild_invalid_stage_cleans_up_transaction
test_direct_writers_respect_rebuild_lock
test_rebuild_rejects_symlinked_recovery_child
test_rebuild_recovers_over_dangling_live_wiki_link
test_system_workspace_path_guard
test_writer_lock_skill_contracts
test_engineering_workflow_artifacts

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
