#!/usr/bin/env bats
# T-4846: a bats run killed mid-file never removes its bats-run-XXXXXX dir, and
# AEF's own runners outside the unit suite (the P-011 Verification gate, fw test)
# handed bats the caller's TMPDIR — the shared /tmp tmpfs, which filled to 0 MB on
# 2026-10-27 (2.6 GB of it one killed run's bats-run-* tree).
#
# Pinned here: a killed run leaves nothing at the temp root (its debris is in an
# owned aef-<label>-<pid>-* dir); the next sweep removes that orphan and nothing it
# cannot attribute; the fullness verdict WARNs over the threshold and only WARNs.
#
# Every test runs against its own temp root ($S); nothing here touches /tmp.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    S="$(mktemp -d)"
    export S
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/tmp-hygiene.sh"
    BG_PID=""
}

teardown() {
    [ -n "${BG_PID:-}" ] && kill -KILL -- "-$BG_PID" 2>/dev/null
    [ -n "${BG_PID:-}" ] && kill -KILL "$BG_PID" 2>/dev/null
    [ -d "${S:-}" ] && rm -rf "$S"
}

# A bats file whose single test sleeps long enough to be killed mid-run.
_slow_bats() {
    mkdir -p "$S/fix"
    printf '@test "slow" { sleep 20; }\n' > "$S/fix/slow.bats"
    printf '@test "quick" { true; }\n' > "$S/fix/quick.bats"
}

# _run_killed <cmd...> — start cmd in its own session with TMPDIR=$S/root, wait
# until bats has made its run dir somewhere under $S/root, then SIGKILL the whole
# process group (the shape of a worker hitting its time limit).
_run_killed() {
    mkdir -p "$S/root"
    TMPDIR="$S/root" setsid bash -c 'echo $$ > "$S/pgid"; exec "$@"' _ "$@" \
        > "$S/run.out" 2>&1 < /dev/null &
    local i=0
    until [ -s "$S/pgid" ] && [ -n "$(find "$S/root" -maxdepth 3 -type d -name 'bats-run-*' -print -quit 2>/dev/null)" ]; do
        i=$((i + 1)); [ "$i" -gt 200 ] && { cat "$S/run.out" >&2; return 1; }
        sleep 0.1
    done
    BG_PID="$(cat "$S/pgid")"
    kill -KILL -- "-$BG_PID"
    local j=0
    while kill -0 "$BG_PID" 2>/dev/null && [ "$j" -lt 50 ]; do sleep 0.1; j=$((j + 1)); done
}

_top_names() { find "$S/root" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort; }

# ── the reproduction, and why the fix is needed ──────────────────────────────

@test "CONTROL: bare bats killed mid-run leaves bats-run-* at the top of its TMPDIR" {
    # The defect itself, measured without any AEF code: if this ever stops being
    # true (a bats that cleans up on SIGKILL), the rest of the file is moot.
    _slow_bats
    _run_killed bats "$S/fix/slow.bats" "$S/fix/quick.bats"
    _top_names | grep -q '^bats-run-'
}

# ── fw test ──────────────────────────────────────────────────────────────────

@test "fw test killed mid-run leaves no bats-run-* at the temp root, only its owned dir" {
    _slow_bats
    _run_killed "$FRAMEWORK_ROOT/bin/fw" test integration "$S/fix/slow.bats" "$S/fix/quick.bats"
    run _top_names
    [[ "$output" != *bats-run-* ]]
    [[ "$output" == *aef-bats-* ]]
}

@test "the next sweep removes the orphan of a killed fw test run" {
    _slow_bats
    _run_killed "$FRAMEWORK_ROOT/bin/fw" test integration "$S/fix/slow.bats" "$S/fix/quick.bats"
    # Orphaned grandchildren (the sleeping test) die with the process group, so
    # nothing holds the dir open any more.
    run fw_tmp_sweep "$S/root"
    [ "$status" -eq 0 ]
    [[ "$output" == aef-bats-* ]]
    [ -z "$(_top_names)" ]
}

@test "fw test removes its owned dir on a normal exit" {
    _slow_bats
    mkdir -p "$S/root"
    TMPDIR="$S/root" run "$FRAMEWORK_ROOT/bin/fw" test integration "$S/fix/quick.bats"
    [ "$status" -eq 0 ]
    [ -z "$(_top_names)" ]
}

# ── the P-011 Verification gate ──────────────────────────────────────────────

_gate_project() {
    export PROJECT_ROOT="$S/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    cat > "$PROJECT_ROOT/.tasks/active/T-9846-tmp-task.md" <<EOF
---
id: T-9846
name: "tmp hygiene fixture"
description: "T-4846 fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-10-27T00:00:00Z
last_update: 2026-10-27T00:00:00Z
date_finished: null
---

# T-9846: tmp hygiene fixture

## Acceptance Criteria

### Agent
- [x] done

## Verification
$1
EOF
}

@test "the P-011 gate runs verification lines under an owned TMPDIR and removes it" {
    mkdir -p "$S/root"
    _gate_project 'echo "$TMPDIR" > "$S/seen"'
    TMPDIR="$S/root" run "$UPDATE_TASK" T-9846 --status work-completed
    [ -s "$S/seen" ]
    seen="$(cat "$S/seen")"
    [[ "$seen" == "$S/root/aef-verify-"* ]]
    [ ! -e "$seen" ]
}

@test "the P-011 gate killed mid-verification leaves no bats-run-* at the temp root" {
    _slow_bats
    # Through a script: the gate refuses a bare unjudged `bats` line, and the
    # point here is what a killed run leaves, not how the line is judged.
    printf 'bats "%s" "%s"\n' "$S/fix/slow.bats" "$S/fix/quick.bats" > "$S/fix/run.sh"
    _gate_project "bash $S/fix/run.sh"
    _run_killed "$UPDATE_TASK" T-9846 --status work-completed
    run _top_names
    [[ "$output" != *bats-run-* ]]
    [[ "$output" == *aef-verify-* ]]
    run fw_tmp_sweep "$S/root"
    [[ "$output" == aef-verify-* ]]
    [ -z "$(_top_names)" ]
}

# ── the sweep's boundary: only what it can attribute ─────────────────────────

@test "sweep leaves foreign entries, live owners and every bats-run dir alone" {
    # bats-run-* cannot be attributed to AEF: every project on the host runs bats as
    # the same uid in the shared /tmp, so even an old one is never AEF's to delete.
    mkdir -p "$S/root/other-project-scratch" "$S/root/pytest-of-root" \
             "$S/root/aef-other-1-abcdef" "$S/root/fw-something" \
             "$S/root/aef-bats-$$-live01" "$S/root/bats-run-young1" "$S/root/bats-run-old001"
    touch -d '3 days ago' "$S/root/other-project-scratch" "$S/root/pytest-of-root" \
                          "$S/root/aef-other-1-abcdef" "$S/root/fw-something" \
                          "$S/root/bats-run-old001"
    run fw_tmp_sweep "$S/root"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(_top_names | wc -l)" -eq 7 ]
}

@test "sweep removes a dead owner's dirs, not one a live process is using" {
    ( exit 0 ) & dead=$!; wait "$dead"
    mkdir -p "$S/root/aef-bats-$dead-dead01" "$S/root/aef-verify-$dead-dead02" \
             "$S/root/aef-bats-$dead-busy01"
    # A process with its cwd inside makes the dir in use, even when its owner pid is gone.
    ( cd "$S/root/aef-bats-$dead-busy01" && exec sleep 30 ) &
    busy=$!
    run fw_tmp_sweep "$S/root"
    kill "$busy" 2>/dev/null; wait "$busy" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ "$(_top_names)" = "aef-bats-$dead-busy01" ]
}

@test "sweep stops at its bound" {
    ( exit 0 ) & dead=$!; wait "$dead"
    for i in 1 2 3 4 5; do mkdir -p "$S/root/aef-bats-$dead-x0000$i"; done
    run fw_tmp_sweep "$S/root" 1440 2
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 2 ]
    [ "$(_top_names | wc -l)" -eq 3 ]
}

# ── the fullness verdict ─────────────────────────────────────────────────────

@test "usage verdict WARNs over the threshold and names the largest entries" {
    mkdir -p "$S/root/big" "$S/root/small"
    head -c 2097152 /dev/zero > "$S/root/big/blob"
    run fw_tmp_usage_verdict "$S/root" 0
    [ "$status" -eq 1 ]
    [[ "$output" == WARN$'\t'* ]]
    [[ "$output" == *"big 2.0M"* ]]
}

@test "usage verdict is OK at or under the threshold, ERROR on a bad threshold" {
    mkdir -p "$S/root"
    run fw_tmp_usage_verdict "$S/root" 100
    [ "$status" -eq 0 ]
    [[ "$output" == OK$'\t'* ]]
    run fw_tmp_usage_verdict "$S/root" abc
    [ "$status" -eq 2 ]
}

@test "doctor and the structure audit read TMP_USE_WARN_PCT and only ever WARN on it" {
    grep -q 'TMP_USE_WARN_PCT|85|' "$FRAMEWORK_ROOT/lib/config.sh"
    for f in "$FRAMEWORK_ROOT/bin/fw" "$FRAMEWORK_ROOT/agents/audit/audit.sh"; do
        block="$(awk '/T-4846: \/tmp here is/{p=1} p{print} p&&/^ *fi$/&&++n==2{exit}' "$f")"
        [[ "$block" == *fw_tmp_usage_verdict* ]]
        [[ "$block" == *TMP_USE_WARN_PCT* ]]
        ! grep -qE '(^|[[:space:]])fail |FAIL' <<<"$block" || false
    done
}
