#!/usr/bin/env bats
# T-3843 (ported from 055 T-454) — fw arc review refuses without a close recommendation.
#
# Scratch project only. Pins:
#   - no substantive ## Recommendation in close_task (or, failing that, anchor_task)
#     → exit 1, no URL, names the task and the CLOSE|KEEP-OPEN format;
#   - close_task carrying one → URL emitted; anchor_task as fallback → URL emitted;
#   - a task id with no file on disk → refusal, not an abort (the `ls | head` class);
#   - FW_ALLOW_EMPTY_RECOMMENDATION=1 → emitted, NOTE, Tier-2 bypass-log entry.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    unset FW_ALLOW_EMPTY_RECOMMENDATION

    _task T-901 completed "anchor text"
    _task T-902 completed "close-out text"
    _task T-903 completed "anchor fallback"
    _template_task T-904 completed
    _template_task T-905 active

    _arc withrec  arc-901 T-901 T-902
    _arc fallback arc-902 T-903
    _arc norec    arc-903 T-904 T-905
    _arc ghost    arc-904 T-999
    _arc anchoronly arc-905 T-904

    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/arc.sh"
}

_task() {
    cat > "$PROJECT_ROOT/.tasks/$2/$1-probe.md" <<MD
---
id: $1
name: probe
---

## Recommendation

**Recommendation:** CLOSE

**Rationale:** $3

**Evidence:**
- docs/reports/probe-close.md

## Updates
MD
}

_template_task() {
    cat > "$PROJECT_ROOT/.tasks/$2/$1-probe.md" <<MD
---
id: $1
name: probe
---

## Recommendation

<!-- **Recommendation:** GO / NO-GO / DEFER (template only) -->

## Updates
MD
}

_arc() {
    {
        echo "id: $2"
        echo "slug: $1"
        echo "name: \"Probe $1\""
        echo "status: in-progress"
        echo "anchor_task: $3"
        [ -n "${4:-}" ] && echo "close_task: $4"
        echo "constituent_tasks: []"
    } > "$ARCS_DIR/$1.yaml"
}

@test "T-3843: refuses without a recommendation, names close_task and format, no URL" {
    run arc_review norec
    [ "$status" -eq 1 ]
    [[ "$output" == *"no close recommendation"* ]]
    [[ "$output" == *"T-905"* ]]
    [[ "$output" == *"close_task"* ]]
    [[ "$output" == *"**Recommendation:** CLOSE | KEEP-OPEN"* ]]
    [[ "$output" != *"/arcs/norec/close"* ]]
}

@test "T-3843: emits the URL when close_task carries a recommendation" {
    run arc_review withrec
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/withrec/close"* ]]
    [[ "$output" == *"Close-out: T-902"* ]]
}

@test "T-3843: anchor_task is the fallback when close_task is unset" {
    run arc_review fallback
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/fallback/close"* ]]
}

@test "T-3843: anchor-only refusal suggests setting close_task" {
    run arc_review anchoronly
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-904 (anchor_task)"* ]]
    [[ "$output" == *"set close_task:"* ]]
}

@test "T-3843: a task id with no file refuses cleanly under set -euo pipefail" {
    run bash -c 'set -euo pipefail; source "$FRAMEWORK_ROOT/lib/arc.sh"; arc_review ghost; echo "unreachable"'
    [ "$status" -eq 1 ]
    [[ "$output" == *"no close recommendation"* ]]
    [[ "$output" == *"T-999"* ]]
}

@test "T-3843: FW_ALLOW_EMPTY_RECOMMENDATION=1 emits, notes it, and logs Tier-2" {
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run arc_review norec
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/norec/close"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "flag: 'FW_ALLOW_EMPTY_RECOMMENDATION'" "$log"
    grep -q "caller: 'arc_review'" "$log"
    grep -q "task: 'T-905'" "$log"
}
