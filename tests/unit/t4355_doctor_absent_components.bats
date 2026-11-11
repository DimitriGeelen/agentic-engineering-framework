#!/usr/bin/env bats
# T-4355 (GitHub #98) — a project that leaves out an optional component on purpose
# got a permanent `fw doctor` WARN for it. ABSENT_COMPONENTS lists such components;
# doctor then reports OK "absent by choice". An undeclared missing component still
# WARNs, and an unknown name in the list WARNs, so a typo cannot silence anything.
#
# TermLink and Node.js are hidden with a PATH that links every host command except
# those two (same technique as t4332).

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup_file() {
    export BIN="$BATS_FILE_TMPDIR/bin"
    mkdir -p "$BIN"
    local d f name
    IFS=: read -ra dirs <<< "$PATH"
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            name=${f##*/}
            case "$name" in termlink|node) continue ;; esac
            if [ -x "$f" ] && [ ! -e "$BIN/$name" ]; then ln -s "$f" "$BIN/$name"; fi
        done
    done
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    printf 'project_name: t4355\nversion: 1.0\n' > "$PROJ/.framework.yaml"
}

teardown() { [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"; return 0; }

doctor() {
    env -u FW_ABSENT_COMPONENTS PATH="$BIN" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" "$@" \
        "$(ROOT)/bin/fw" doctor --quick 2>&1
}

@test "the stripped PATH really has no termlink and no node" {
    run env PATH="$BIN" bash -c 'command -v termlink || command -v node'
    [ "$status" -ne 0 ]
}

@test "T-4355: an undeclared missing component still WARNs" {
    run doctor
    [[ "$output" == *"TermLink not installed (cargo install termlink)"* ]]
    [[ "$output" != *"absent by choice"* ]]
}

@test "T-4355: a declared component reads OK, absent by choice" {
    run doctor FW_ABSENT_COMPONENTS="termlink, node"
    echo "$output" | grep -E 'TermLink|Node' >&2
    [[ "$output" == *"OK"*"TermLink not installed — absent by choice (ABSENT_COMPONENTS)"* ]]
    [[ "$output" != *"TermLink not installed (cargo install termlink)"* ]]
}

@test "T-4355: an unknown name in the list WARNs instead of silencing anything" {
    run doctor FW_ABSENT_COMPONENTS="termlnk"
    [[ "$output" == *"ABSENT_COMPONENTS names 'termlnk', which is not an optional component"* ]]
    [[ "$output" == *"TermLink not installed (cargo install termlink)"* ]]
}

@test "T-4355: the setting is registered (fw config can read and describe it)" {
    run grep -c '"ABSENT_COMPONENTS||' "$(ROOT)/lib/config.sh"
    [ "$output" = "1" ]
}
