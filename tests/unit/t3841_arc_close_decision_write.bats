#!/usr/bin/env bats
# T-3841 — arc_close records the decision it is given.
#
# Scratch project only. Pins:
#   - an arc YAML with no `decision:` line still gets the decision (it was dropped:
#     re.sub matched nothing);
#   - a decision carrying `"`, `\` and a newline round-trips through yaml.safe_load
#     unchanged (a `\` used to be read as a regex escape in the replacement);
#   - the ordinary case (template `decision: null` line) still works.
# --i-am-human is the test-context override the close path documents (T-1671),
# as in arc_lifecycle_state_machine.bats.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    unset CLAUDECODE

    _arc withline arc-801 "decision: null"
    _arc noline   arc-802 ""

    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/arc.sh"
}

_arc() {
    {
        echo "id: $2"
        echo "slug: $1"
        echo "name: \"Probe $1\""
        echo "status: in-progress"
        echo "created: 2026-01-01T00:00:00Z"
        [ -n "$3" ] && echo "$3"
        echo "closed_at: null"
        echo "constituent_tasks: []"
    } > "$ARCS_DIR/$1.yaml"
}

_decision_of() {
    python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["decision"], end="")' "$ARCS_DIR/$1.yaml"
}

_close() {
    arc_close "$1" --demo none --justification "bats fixture — no runtime mechanic to demo here" \
        --decision "$2" --i-am-human
}

@test "T-3841: decision replaces the template decision: null line" {
    run _close withline "CLOSE — shipped (agent recommendation, T-902)"
    [ "$status" -eq 0 ]
    [ "$(_decision_of withline)" = "CLOSE — shipped (agent recommendation, T-902)" ]
    [ "$(grep -c '^decision:' "$ARCS_DIR/withline.yaml")" -eq 1 ]
}

@test "T-3841: decision is recorded when the arc YAML has no decision: line" {
    run _close noline "CLOSE — recorded although the field was absent"
    [ "$status" -eq 0 ]
    [ "$(_decision_of noline)" = "CLOSE — recorded although the field was absent" ]
}

@test "T-3841: quote, backslash and newline round-trip through yaml.safe_load" {
    d=$'CLOSE — the "gate" holds; path C:\\new\\d1 and \\1 stay literal\nsecond line'
    run _close withline "$d"
    [ "$status" -eq 0 ]
    [ "$(_decision_of withline)" = "$d" ]
}
