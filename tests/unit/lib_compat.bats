#!/usr/bin/env bats
# Unit tests for lib/compat.sh
#
# Tests _sed_i() — portable in-place sed edit

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/compat.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "compat: _sed_i replaces text in file" {
    echo "hello world" > "$TEST_TEMP_DIR/test.txt"
    _sed_i 's/world/earth/' "$TEST_TEMP_DIR/test.txt"
    [ "$(cat "$TEST_TEMP_DIR/test.txt")" = "hello earth" ]
}

@test "compat: _sed_i handles multiple lines" {
    printf "line1\nline2\nline3\n" > "$TEST_TEMP_DIR/multi.txt"
    _sed_i 's/line2/replaced/' "$TEST_TEMP_DIR/multi.txt"
    grep -q "replaced" "$TEST_TEMP_DIR/multi.txt"
    grep -q "line1" "$TEST_TEMP_DIR/multi.txt"
    grep -q "line3" "$TEST_TEMP_DIR/multi.txt"
}

@test "compat: _sed_i errors on missing file" {
    run _sed_i 's/a/b/' "$TEST_TEMP_DIR/nonexistent.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"file not found"* ]]
}

@test "compat: _sed_i preserves file when no match" {
    echo "original content" > "$TEST_TEMP_DIR/nomatch.txt"
    _sed_i 's/nonexistent/replacement/' "$TEST_TEMP_DIR/nomatch.txt"
    [ "$(cat "$TEST_TEMP_DIR/nomatch.txt")" = "original content" ]
}

@test "compat: _sed_i handles special characters in content" {
    echo 'path: /foo/bar' > "$TEST_TEMP_DIR/special.txt"
    _sed_i 's|/foo/bar|/baz/qux|' "$TEST_TEMP_DIR/special.txt"
    [ "$(cat "$TEST_TEMP_DIR/special.txt")" = "path: /baz/qux" ]
}

@test "compat: _sed_i does not leave temp files on success" {
    echo "clean" > "$TEST_TEMP_DIR/clean.txt"
    _sed_i 's/clean/done/' "$TEST_TEMP_DIR/clean.txt"
    # No .XXXXXX temp files should remain
    local temp_count
    temp_count=$(ls "$TEST_TEMP_DIR"/clean.txt.* 2>/dev/null | wc -l)
    [ "$temp_count" -eq 0 ]
}

@test "compat: _sed_i handles delete expression" {
    printf "keep\ndelete_me\nkeep_too\n" > "$TEST_TEMP_DIR/delete.txt"
    _sed_i '/delete_me/d' "$TEST_TEMP_DIR/delete.txt"
    if grep -q "delete_me" "$TEST_TEMP_DIR/delete.txt"; then false; fi
    grep -q "keep" "$TEST_TEMP_DIR/delete.txt"
}
