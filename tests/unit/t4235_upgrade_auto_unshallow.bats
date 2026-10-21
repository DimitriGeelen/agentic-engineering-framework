#!/usr/bin/env bats
# T-4235: fw upgrade from a SHALLOW clone used to refuse as foreign-source and
# tell the operator to run `git fetch --unshallow` (T-3714). Reported by 1409
# (msg eb27d14e, 1.8.3 -> 1.8.10). The remedy is one additive command on the
# source's own .git, so do_upgrade now runs it itself and says so.
#
# Contract: fetchable shallow source -> announced unshallow, precheck passes;
# unfetchable -> the T-3714 refusal and remedy, unchanged; --dry-run -> no fetch.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4235-XXXXXX)"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    REAL_FW="$FRAMEWORK_ROOT"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"

    local g=(git -c user.name=t4235 -c user.email=t4235@example.invalid)
    UP="$TEST_TEMP_DIR/up"
    mkdir -p "$UP/lib/templates"
    git init -q "$UP"
    echo "v1" > "$UP/lib/a.sh"
    cp "$REAL_FW/lib/templates/claude-project.md" "$UP/lib/templates/claude-project.md"
    "${g[@]}" -C "$UP" add -A
    "${g[@]}" -C "$UP" commit -q -m A
    A_SHA="$(git -C "$UP" rev-parse HEAD)"
    echo "v2" > "$UP/lib/a.sh"
    "${g[@]}" -C "$UP" add -A
    "${g[@]}" -C "$UP" commit -q -m B

    SRC="$TEST_TEMP_DIR/src"
    git clone -q --depth 1 "file://$UP" "$SRC"
    export FRAMEWORK_ROOT="$SRC"
    export FW_VERSION="1.0.1"

    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ"
    printf 'project_name: proj\nversion: 1.0.0\nversion_sha: %s\n' "$A_SHA" > "$PROJ/.framework.yaml"
    # Stop the run at step 1 (T-3150 unmatched project-owned marker), after the
    # version precheck, before any consumer rewrite.
    printf '# CLAUDE.md\n<!-- project-owned: begin -->\n\n## Core Principle\n' > "$PROJ/CLAUDE.md"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t4235: fixture — source is shallow and cannot see the consumer's sha" {
    run fw_source_is_shallow "$SRC"; [ "$status" -eq 0 ]
    run git -C "$SRC" rev-parse -q --verify "${A_SHA}^{commit}"
    [ "$status" -ne 0 ]
}

@test "t4235: shallow, fetchable source is unshallowed by fw upgrade, announced, and not refused" {
    run do_upgrade "$PROJ"
    [[ "$output" == *"shallow clone without the consumer's version_sha ${A_SHA:0:12}"* ]]
    [[ "$output" == *"fetch --unshallow"*"ok"* ]]
    [[ "$output" != *"REFUSED  Consumer"* ]]
    [[ "$output" != *"foreign-source"* ]]
    run fw_source_is_shallow "$SRC"; [ "$status" -ne 0 ]
}

@test "t4235: unfetchable shallow source keeps the T-3714 refusal and remedy" {
    git -C "$SRC" remote remove origin
    run do_upgrade "$PROJ"
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAILED"* ]]
    [[ "$output" == *"REFUSED  Consumer"* ]]
    [[ "$output" == *"foreign-source"* ]]
    [[ "$output" == *"Remedy: git -C $SRC fetch --unshallow"* ]]
    run fw_source_is_shallow "$SRC"; [ "$status" -eq 0 ]
}

@test "t4235: --dry-run does not fetch, and says a real run would" {
    run do_upgrade --dry-run "$PROJ"
    [[ "$output" == *"[dry-run] source is a shallow clone"* ]]
    [[ "$output" == *"a real run fetches its full history first"* ]]
    run fw_source_is_shallow "$SRC"; [ "$status" -eq 0 ]
}

@test "t4235: CONTROL — full-history source needs no fetch and prints no notice" {
    git -C "$SRC" fetch -q --unshallow
    run do_upgrade "$PROJ"
    [[ "$output" != *"shallow clone without"* ]]
    [[ "$output" != *"REFUSED  Consumer"* ]]
}
