#!/usr/bin/env bats
# T-5053 — concerns without a `title` must not break the Gaps Register.
#
# 050-email-archive: 41 watching concerns carry name/summary but no title. The
# handover block raised KeyError and stopped listing; the audit's trigger check
# read gap['title'] inside a bare except and dropped a triggered concern unseen.
# Both tests run the real heredoc bodies extracted from the scripts.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    GAPS_FILE="$TEST_TEMP_DIR/concerns.yaml"
    cat > "$GAPS_FILE" <<'EOF'
concerns:
  - id: G-001
    status: watching
    severity: high
    title: Has a title
  - id: G-002
    status: watching
    name: Only a name
  - id: G-003
    status: watching
    summary: Only a summary
    trigger_check:
      type: auto
      check: echo 5
      threshold: ">= 3"
  - id: G-004
    status: watching
  - status: watching
    title: No id here
  - id: G-005
    status: closed
    title: Closed one
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Body of the first `python3 << PYEOF` heredoc after the line matching $2 in file $1.
_heredoc_after() {
    awk -v anchor="$2" '
        index($0, anchor) { seen = 1 }
        seen && !inside && /python3 << PYEOF/ { inside = 1; next }
        inside && /^PYEOF$/ { exit }
        inside { print }
    ' "$1"
}

_run_heredoc() {
    # $1: heredoc body file. Re-run it as an unquoted heredoc, as the script does.
    {
        echo "GAPS_FILE='$GAPS_FILE'"
        echo "PROJECT_ROOT='$TEST_TEMP_DIR'"
        echo "python3 << PYEOF"
        cat "$1"
        echo "PYEOF"
    } > "$TEST_TEMP_DIR/run.sh"
    run bash "$TEST_TEMP_DIR/run.sh"
}

@test "handover Gaps Register lists title-less concerns by name, summary or (untitled) (T-5053)" {
    _heredoc_after "$FRAMEWORK_ROOT/agents/handover/handover.sh" 'echo "## Gaps Register"' > "$TEST_TEMP_DIR/body.py"
    [ -s "$TEST_TEMP_DIR/body.py" ]
    _run_heredoc "$TEST_TEMP_DIR/body.py"
    [ "$status" -eq 0 ]
    [[ "$output" != *"KeyError"* ]]
    [[ "$output" == *"**G-001** [high]: Has a title"* ]]
    [[ "$output" == *"**G-002** [unknown]: Only a name"* ]]
    [[ "$output" == *"**G-003** [unknown]: Only a summary"* ]]
    [[ "$output" == *"**G-004** [unknown]: (untitled)"* ]]
    [[ "$output" == *"1 watching concern(s) have no \`id\`"* ]]
    [[ "$output" != *"G-005"* ]]
}

@test "audit trigger check reports a triggered concern that has no title (T-5053)" {
    awk '
        /triggered_gaps=\$\(python3 << PYEOF/ { inside = 1; next }
        inside && /^PYEOF$/ { exit }
        inside { print }
    ' "$FRAMEWORK_ROOT/agents/audit/audit.sh" > "$TEST_TEMP_DIR/audit.py"
    [ -s "$TEST_TEMP_DIR/audit.py" ]
    _run_heredoc "$TEST_TEMP_DIR/audit.py"
    [ "$status" -eq 0 ]
    [[ "$output" == *"TRIGGERED: G-003 — Only a summary"* ]]
    [ "$(echo "$output" | tail -1)" = "1" ]
}
