#!/usr/bin/env bats
# T-4655 — metrics.sh store counters and last_update parsing.
#
# The context-fabric counters were `grep -c "^  - id: L-"` (and D-, [FSW]P-):
# a fixed indent and a fixed prefix. A store serialised another way read 0 —
# including this repo's own learnings.yaml, where `-` sits on its own line
# (741 learnings shown as 0). A quoted last_update ("2026-…") failed the date
# parse, the epoch came back "0\n0", the -lt test errored to false, and an
# old quoted task never counted as stale (test 6 is the discriminator).
#
# METRICS_SH overrides the script under test, so the pre-fix version can be
# run against the same fixtures (git show HEAD~:metrics.sh > copy).

FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
METRICS_SH="${METRICS_SH:-$FW_ROOT/metrics.sh}"

setup() {
    P="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.tasks/templates" \
             "$P/.context/project" "$P/.context/episodic"
}

_metrics() {
    run env PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FW_ROOT" bash "$METRICS_SH"
}

_line() { echo "$output" | grep -E "^$1" | head -1 | awk '{print $NF}'; }

_task() { # id status last_update(raw, may be quoted)
    printf -- '---\nid: %s\nname: t\ndescription: d\nstatus: %s\nlast_update: %s\n---\n# body\n' \
        "$1" "$2" "$3" > "$P/.tasks/active/$1.md"
}

@test "dash-own-line store (learnings.yaml shape here) counts every entry" {
    printf 'learnings:\n-\n  id: L-001\n  learning: a\n-\n  id: L-002\n  learning: b\n' \
        > "$P/.context/project/learnings.yaml"
    _metrics
    [ "$status" -eq 0 ]
    [ "$(_line Learnings:)" = "2" ]
}

@test "4-space indent and foreign id prefixes count" {
    printf 'decisions:\n    - id: ADR-1\n      d: x\n    - id: ADR-2\n      d: y\n    - id: ADR-3\n' \
        > "$P/.context/project/decisions.yaml"
    printf 'failure_patterns:\n  - id: FP-001\nantifragile_patterns:\n  - id: AP-001\nworkflow_patterns:\n  - id: WP-001\n' \
        > "$P/.context/project/patterns.yaml"
    _metrics
    [ "$status" -eq 0 ]
    [ "$(_line Decisions:)" = "3" ]
    [ "$(_line Patterns:)" = "3" ]
}

@test "classic 2-space store still counts" {
    printf 'learnings:\n  - id: L-001\n    learning: a\n  - id: L-002\n    learning: b\n' \
        > "$P/.context/project/learnings.yaml"
    _metrics
    [ "$(_line Learnings:)" = "2" ]
}

@test "unparseable store prints an ERROR and ?, not 0" {
    printf 'learnings:\n  - id: L-001\n  bad: [unclosed\n' > "$P/.context/project/learnings.yaml"
    _metrics
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "ERROR: metrics: cannot read .*learnings.yaml"
    [ "$(_line Learnings:)" = "?" ]
}

@test "quoted last_update on a fresh task is not stale" {
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _task T-1 captured "\"$now\""
    _task T-2 captured "'$now'"
    _task T-3 captured "$now"
    _metrics
    [ "$status" -eq 0 ]
    [ "$(_line 'Stale tasks')" = "0" ]
}

@test "old task is stale whether or not its date is quoted" {
    _task T-1 captured '"2020-01-01T00:00:00Z"'
    _task T-2 captured '2020-01-01T00:00:00Z'
    _metrics
    [ "$(_line 'Stale tasks')" = "2" ]
}

@test "frozen WIP counts started-work tasks with no update in 14 days" {
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _task T-1 started-work '"2020-01-01T00:00:00Z"'
    _task T-2 started-work "$now"
    _task T-3 captured '2020-01-01T00:00:00Z'
    _metrics
    [ "$(_line 'Frozen WIP')" = "1" ]
}
