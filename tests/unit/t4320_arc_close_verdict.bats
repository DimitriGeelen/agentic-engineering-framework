#!/usr/bin/env bats
# T-4320 (peer report from 1023, arc vault-mvp) — fw arc review accepts only a
# CLOSE or KEEP-OPEN recommendation as a close verdict.
#
# Scratch project only. Pins:
#   - anchor holds only GO, no close_task → refused, names the GO and the agent
#     action (set close_task, write CLOSE with demo evidence), no URL;
#   - close_task holds GO → refused, points at the close_task;
#   - neither close_task nor anchor_task → refused, names close_task;
#   - close_task with KEEP-OPEN, bold or bulleted CLOSE → URL emitted.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    unset FW_ALLOW_EMPTY_RECOMMENDATION
    export WATCHTOWER_URL="http://wt.test:3999"

    _task T-911 completed "GO"
    _task T-912 active "KEEP-OPEN"
    _task T-913 active "**CLOSE**"
    _task T-914 active "NO_GO"
    _bullet_task T-915 active

    _arc goanchor  arc-911 T-911
    _arc goclose   arc-912 T-911 T-911
    _arc nothing   arc-913 ""
    _arc keepopen  arc-914 T-911 T-912
    _arc boldclose arc-915 T-911 T-913
    _arc nogo      arc-916 T-914
    _arc bullet    arc-917 T-911 T-915

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

<!-- **Recommendation:** CLOSE (template only — must not count) -->

**Recommendation:** $3

**Rationale:** probe

**Evidence:**
- docs/reports/probe.md

## Updates
MD
}

_bullet_task() {
    cat > "$PROJECT_ROOT/.tasks/$2/$1-probe.md" <<MD
---
id: $1
name: probe
---

## Recommendation

- **Recommendation:** CLOSE — demo fired
- **Rationale:** probe

## Updates
MD
}

_arc() {
    {
        echo "id: $2"
        echo "slug: $1"
        echo "name: \"Probe $1\""
        echo "status: in-progress"
        [ -n "$3" ] && echo "anchor_task: $3"
        [ -n "${4:-}" ] && echo "close_task: $4"
        echo "constituent_tasks: []"
    } > "$ARCS_DIR/$1.yaml"
}

@test "T-4320: an anchor's opening GO is not a close recommendation" {
    run arc_review goanchor
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"T-911 holds **Recommendation:** GO"* ]]
    [[ "$output" == *"Agent action: set close_task: T-XXX"* ]]
    [[ "$output" == *"**Recommendation:** CLOSE | KEEP-OPEN"* ]]
    [[ "$output" == *"demo"* ]]
    [[ "$output" != *"/arcs/goanchor/close"* ]]
}

@test "T-4320: GO on the close_task is refused and points at the close_task" {
    run arc_review goclose
    [ "$status" -eq 1 ]
    [[ "$output" == *"holds **Recommendation:** GO"* ]]
    [[ "$output" == *"T-911 (close_task)"* ]]
    [[ "$output" != *"/arcs/goclose/close"* ]]
}

@test "T-4320: NO_GO on the anchor is refused too" {
    run arc_review nogo
    [ "$status" -eq 1 ]
    [[ "$output" == *"holds **Recommendation:** NO-GO"* ]]
    [[ "$output" != *"/arcs/nogo/close"* ]]
}

@test "T-4320: no close_task and no anchor_task refuses and names close_task" {
    run arc_review nothing
    [ "$status" -eq 1 ]
    [[ "$output" == *"Set close_task: T-XXX"* ]]
    [[ "$output" != *"/arcs/nothing/close"* ]]
}

@test "T-4320: KEEP-OPEN on the close_task emits the URL" {
    run arc_review keepopen
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/keepopen/close"* ]]
}

@test "T-4320: a bold CLOSE and a bulleted CLOSE both emit the URL" {
    run arc_review boldclose
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/boldclose/close"* ]]
    run arc_review bullet
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/bullet/close"* ]]
}
