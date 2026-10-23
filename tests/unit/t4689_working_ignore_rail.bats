#!/usr/bin/env bats
# T-4689 — every file the framework writes under .context/working/ is either
# gitignored in a consumer or on the deliberate keep-tracked list. 1023 patched
# their ignore by hand four times (sidecar b3fcf74f) because nothing compared
# the T-4231 list against the writers. tools/working-ignore-rail.py is that
# comparison; these tests pin it and the two names that were missing.

load ../test_helper

RAIL="$FRAMEWORK_ROOT/tools/working-ignore-rail.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/working-gitignore.sh"
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

@test "the two reported runtime files are ignored after ensure_ignored" {
    p=$(_repo)
    fw_working_ensure_ignored "$p" >/dev/null
    for n in .fleet-failure-state.json vector-index-health.json; do
        : > "$p/.context/working/$n"
        git -C "$p" check-ignore -q ".context/working/$n" || { echo "not ignored: $n"; false; }
    done
}

@test "keep-tracked records are not ignored" {
    p=$(_repo)
    fw_working_ensure_ignored "$p" >/dev/null
    while IFS= read -r n; do
        : > "$p/.context/working/$n"
        ! git -C "$p" check-ignore -q ".context/working/$n" || { echo "record ignored: $n"; false; }
    done < <(fw_working_keep_tracked)
}

@test "upgrade path: a consumer ignore that predates T-4689 gets exactly the new rules, then 0" {
    p=$(_repo)
    gi="$p/.context/working/.gitignore"
    # The T-4231 list as it shipped: every current rule except the T-4689 additions.
    fw_working_ignore_rules | grep -vxF -e '.fleet-failure-state.json' -e 'vector-index-health.json' \
        > "$gi"
    printf 'my-local-rule\n' >> "$gi"
    cp "$gi" "$TEST_TEMP_DIR/before"
    [ "$(fw_working_ensure_ignored "$p")" -eq 2 ]
    # append-only: the old content is a prefix of the new file
    head -c "$(wc -c < "$TEST_TEMP_DIR/before")" "$gi" | cmp - "$TEST_TEMP_DIR/before"
    grep -qx '.fleet-failure-state.json' "$gi"
    grep -qx 'vector-index-health.json' "$gi"
    [ "$(fw_working_ensure_ignored "$p")" -eq 0 ]
}

@test "rail is clean on the framework tree" {
    run timeout 120 python3 "$RAIL"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [[ "$output" == *"working-ignore-rail: clean"* ]]
}

@test "rail bites: a new unignored writer is reported with its file:line" {
    mkdir -p "$TEST_TEMP_DIR/scan/lib"
    printf '#!/bin/bash\necho 1 > "$PROJECT_ROOT/.context/working/brand-new-state.json"\n' \
        > "$TEST_TEMP_DIR/scan/lib/new-writer.sh"
    printf 'p = root / ".context" / "working" / "py-new-thing.db"\n' \
        > "$TEST_TEMP_DIR/scan/lib/new_writer.py"
    run timeout 120 python3 "$RAIL" --scan-root "$TEST_TEMP_DIR/scan"
    [ "$status" -eq 1 ]
    [[ "$output" == *"UNIGNORED brand-new-state.json"*"lib/new-writer.sh:2"* ]]
    [[ "$output" == *"UNIGNORED py-new-thing.db"* ]]
}

@test "rail resolves variables and directory rules (no false positive)" {
    mkdir -p "$TEST_TEMP_DIR/scan/lib"
    printf 'f="$CONTEXT_DIR/working/.reviewed-${task_id}"\nd=".context/working/decide/run1"\n' \
        > "$TEST_TEMP_DIR/scan/lib/known.sh"
    run timeout 120 python3 "$RAIL" --scan-root "$TEST_TEMP_DIR/scan"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "rail classifies a keep-tracked directory as keep-tracked, not unignored" {
    mkdir -p "$TEST_TEMP_DIR/scan/lib"
    printf 'x=".context/working/observations/a.md"\n' > "$TEST_TEMP_DIR/scan/lib/obs.sh"
    run timeout 120 python3 "$RAIL" --scan-root "$TEST_TEMP_DIR/scan" --list
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [[ "$output" == *"keep-tracked  observations"* ]]
}
