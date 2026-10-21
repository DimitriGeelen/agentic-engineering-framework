#!/usr/bin/env bats
# T-3861 — the vector index (.context/working/fw-vec-index.db, GiB-sized) and its
# build/reindex scratch must be gitignored in consumers. The framework repo ignored
# them in its ROOT .gitignore, which consumers never inherit; `fw init` wrote a
# .context/working/.gitignore that named none of them and `fw upgrade` never
# touched it (ring20-dashboard T-2462 finding 9: 1.2 GB blob in .git).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/vec-index-gitignore.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_repo() {
    local p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.context/working"
    git -C "$p" init -q
    echo "$p"
}

_index_names() {
    printf '%s\n' fw-vec-index.db fw-vec-index.db-wal fw-vec-index.db-shm \
        fw-vec-index.db-journal fw-vec-index.db.manifest.json fw-vec-index.db.reindex.lock \
        fw-vec-index.db.reindex.resume fw-vec-index.db.reindex.123.tmp \
        fw-vec-index.db.reindex.123.tmp-journal fw-vec-index.db.123.building \
        fw-vec-index.db.building fw-vec-index.db.building.manifest.json
}

@test "negative control: a pre-T-3861 working/.gitignore leaves the index committable" {
    p=$(_repo)
    printf '.tool-counter\nsession.yaml\nfocus.yaml\n.fw-secret-key\n' > "$p/.context/working/.gitignore"
    : > "$p/.context/working/fw-vec-index.db"
    run fw_vec_index_unignored "$p"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "not gitignored"
}

@test "ensure_ignored covers the index and every scratch sibling" {
    p=$(_repo)
    printf '.tool-counter\n' > "$p/.context/working/.gitignore"
    [ "$(fw_vec_index_ensure_ignored "$p")" -eq 3 ]
    while IFS= read -r n; do
        : > "$p/.context/working/$n"
        git -C "$p" check-ignore -q ".context/working/$n" || { echo "not ignored: $n"; false; }
    done < <(_index_names)
    # unrelated files in the same directory stay visible to git status
    : > "$p/.context/working/focus-other.yaml"
    ! git -C "$p" check-ignore -q ".context/working/focus-other.yaml" || false
    run fw_vec_index_unignored "$p"
    [ "$status" -eq 0 ]
}

@test "ensure_ignored is idempotent and creates a missing file" {
    p=$(_repo)
    [ ! -f "$p/.context/working/.gitignore" ]
    [ "$(fw_vec_index_ensure_ignored "$p")" -eq 3 ]
    cp "$p/.context/working/.gitignore" "$TEST_TEMP_DIR/first"
    [ "$(fw_vec_index_ensure_ignored "$p")" -eq 0 ]
    cmp "$p/.context/working/.gitignore" "$TEST_TEMP_DIR/first"
}

@test "ensure_ignored --dry-run counts but writes nothing" {
    p=$(_repo)
    printf 'session.yaml' > "$p/.context/working/.gitignore"   # no trailing newline
    [ "$(fw_vec_index_ensure_ignored "$p" --dry-run)" -eq 3 ]
    [ "$(cat "$p/.context/working/.gitignore")" = "session.yaml" ]
    fw_vec_index_ensure_ignored "$p" >/dev/null
    grep -qx 'session.yaml' "$p/.context/working/.gitignore"
    grep -qx 'fw-vec-index.db' "$p/.context/working/.gitignore"
}

@test "unignored reports a TRACKED index even when a rule now exists" {
    p=$(_repo)
    : > "$p/.context/working/fw-vec-index.db"
    git -C "$p" add .context/working/fw-vec-index.db
    fw_vec_index_ensure_ignored "$p" >/dev/null
    run fw_vec_index_unignored "$p"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q TRACKED
}

@test "fw init and fw upgrade both call the shared helper" {
    grep -q 'fw_vec_index_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_vec_index_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q '^check_vec_index_ignored$' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "end-to-end: a fresh fw init ignores the vector index" {
    proj="$TEST_TEMP_DIR/fresh"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ -f "$proj/.context/working/.gitignore" ] || { echo "$output" | tail -20; false; }
    : > "$proj/.context/working/fw-vec-index.db"
    : > "$proj/.context/working/fw-vec-index.db.reindex.99.tmp"
    git -C "$proj" check-ignore -q .context/working/fw-vec-index.db
    git -C "$proj" check-ignore -q .context/working/fw-vec-index.db.reindex.99.tmp
}
