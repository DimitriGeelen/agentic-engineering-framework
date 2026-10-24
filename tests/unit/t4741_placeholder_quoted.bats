#!/usr/bin/env bats
# T-4741: a template stub QUOTED in prose (inline code of any backtick length,
# or a double-quoted string) is a mention, not an unfilled placeholder.
# Before the fix, lib/task-audit.sh stripped only single-backtick spans, so the
# double-backtick and double-quoted shapes refused `fw task review`, and
# lib/ac_placeholder.py stripped nothing at all. Both readers now share
# strip_quoted_spans; this file pins the verdict of each.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMP="$(mktemp -d)"
    # shellcheck source=/dev/null
    source "$FW_ROOT/lib/task-audit.sh"
}

teardown() {
    rm -rf "$TMP"
}

# Write one line as the Acceptance Criteria of a minimal task file.
_task() {
    printf '%s\n' "# T-9999: fixture" "" "## Acceptance Criteria" "" "$1" "" "## Updates" > "$TMP/t.md"
}

_py() {
    python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from ac_placeholder import is_placeholder_item as f; sys.exit(0 if f(sys.argv[2]) else 1)' "$FW_ROOT/lib" "$1"
}

@test "single-backtick quoted stub passes both readers" {
    line='- [x] the audit ignores `[First criterion]` in prose'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py "$line"
    [ "$status" -eq 1 ]
}

@test "double-backtick quoted stub passes both readers" {
    line='- [x] the audit ignores ``[First criterion]`` in prose'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py "$line"
    [ "$status" -eq 1 ]
}

@test "double-backtick span containing a backtick passes" {
    line='- [x] see ``a`[TODO]`` here'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py "$line"
    [ "$status" -eq 1 ]
}

@test "double-quoted stub passes both readers" {
    line='- [x] the audit ignores "[Criterion 1]" in prose'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py "$line"
    [ "$status" -eq 1 ]
}

@test "bare ordinal stub AC line is still flagged by both readers" {
    line='- [ ] [First criterion]'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 5:"* ]]
    run _py "$line"
    [ "$status" -eq 0 ]
}

@test "line with a quoted stub AND a bare stub is still flagged" {
    line='- [ ] [Second criterion] (see "[TODO]" and ``[PLACEHOLDER]``)'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    run _py "$line"
    [ "$status" -eq 0 ]
}

@test "an unmatched backtick run does not hide a bare stub" {
    line='- [ ] stray `` run then [TODO]'
    _task "$line"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    run _py "$line"
    [ "$status" -eq 0 ]
}

@test "without python3 the single-backtick fallback still runs" {
    _task '- [ ] [Third criterion] and `[TODO]`'
    mkdir "$TMP/bin"
    for t in sed grep dirname; do ln -s "$(command -v "$t")" "$TMP/bin/$t"; done
    run env PATH="$TMP/bin" /bin/bash -c "source '$FW_ROOT/lib/task-audit.sh'; audit_task_placeholders '$TMP/t.md'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 5:"* ]]
}

@test "Updates section stays exempt" {
    printf '%s\n' "# T-9999" "## Updates" "- [ ] [First criterion]" > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
}
