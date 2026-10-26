#!/usr/bin/env bats
# T-4762: a code span that opens on one line and closes on the next (a wrapped
# paragraph, or a YAML folded scalar such as `description: >`) quotes the stubs
# inside it. T-4741's strip_quoted_spans matched spans one line at a time, so
# the closing backtick on the second line paired with the NEXT span's opener and
# left the quoted stubs bare (TermLink T-1899, lines 7-8). Spans are now matched
# per block; line numbers and bare-stub detection are unchanged.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMP="$(mktemp -d)"
    # shellcheck source=/dev/null
    source "$FW_ROOT/lib/task-audit.sh"
}

teardown() {
    rm -rf "$TMP"
}

# Python reader verdict on the whole file: exit 0 = placeholder found.
_py_file() {
    python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from ac_placeholder import is_placeholder_item as f; sys.exit(0 if f(open(sys.argv[2]).read()) else 1)' "$FW_ROOT/lib" "$1"
}

# TermLink T-1899 shape: the span opens on line 7 and closes on line 8.
_folded() {
    printf '%s\n' '---' 'id: T-1899' 'name: "fixture"' "description: $1" \
        '  Peer report from 050: the gate refused.' \
        '  More context on this line of the scalar.' \
        '  The agent typed `fw task create --name foo' \
        '  --type build`, the task file landed with `[First criterion]` / `[Second criterion]` stubs.' \
        'status: started-work' '---' '' '# T-1899: fixture' '' \
        '## Acceptance Criteria' '' '- [x] a real criterion' '' '## Updates' > "$TMP/t.md"
}

@test "span split across a folded description (>) passes both readers" {
    _folded '>'
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py_file "$TMP/t.md"
    [ "$status" -eq 1 ]
}

@test "span split across a block scalar (|) passes both readers" {
    _folded '|'
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py_file "$TMP/t.md"
    [ "$status" -eq 1 ]
}

@test "span split across a body paragraph passes both readers" {
    printf '%s\n' '# T-9999: fixture' '' '## Context' '' \
        'The agent ran `fw task create --name foo' \
        '--type build`, and the file landed with `[First criterion]` and ``[TODO]`` in it.' \
        '' '## Acceptance Criteria' '' '- [x] a real criterion' > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 0 ]
    run _py_file "$TMP/t.md"
    [ "$status" -eq 1 ]
}

@test "bare stub AC after a split span is flagged at its own line" {
    printf '%s\n' '---' 'id: T-1899' 'description: >' \
        '  The agent typed `fw task create' \
        '  --type build`, and saw `[First criterion]`.' \
        '---' '' '## Acceptance Criteria' '' '- [ ] [Second criterion]' > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 10: - [ ] [Second criterion]"* ]]
    [[ "$output" != *"Line 5:"* ]]
    run _py_file "$TMP/t.md"
    [ "$status" -eq 0 ]
}

@test "a stray backtick in one AC item does not hide a bare stub in the next" {
    printf '%s\n' '## Acceptance Criteria' '' \
        '- [x] stray ` backtick here' \
        '- [ ] [Third criterion] and `quoted`' > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 4:"* ]]
    run _py_file "$TMP/t.md"
    [ "$status" -eq 0 ]
}

@test "a stray backtick on a frontmatter key does not pair into the next key" {
    printf '%s\n' '---' 'name: "a ` b"' 'description: >' '  see `x' 'status: [TODO]' '---' > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 5:"* ]]
}

@test "fence backticks never pair with a span outside the fence" {
    printf '%s\n' '## Context' '' 'text with ` stray' '```' 'code' '```' 'tail [TODO] here' > "$TMP/t.md"
    run audit_task_placeholders "$TMP/t.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line 7:"* ]]
}

@test "--strip preserves the line count and keeps lines in place" {
    _folded '>'
    run bash -c "python3 '$FW_ROOT/lib/ac_placeholder.py' --strip < '$TMP/t.md' | wc -l"
    [ "$output" -eq "$(wc -l < "$TMP/t.md")" ]
    run bash -c "python3 '$FW_ROOT/lib/ac_placeholder.py' --strip < '$TMP/t.md' | sed -n 9p"
    [ "$output" = "status: started-work" ]
}
