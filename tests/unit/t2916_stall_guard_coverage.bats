#!/usr/bin/env bats
# T-2916 — the stall guard must JUDGE, not merely run.
#
# T-2914 shipped `--stall-after` and closed with 6/6 ACs green. Every one of
# those ACs verified the guard was *wired* — flag parsed, banner printed, verb
# exits 0. None verified it reached a verdict on real data. It did not: the
# predicate required `task_snapshot`, a field T-2914 itself introduced, so its
# evaluable history was empty on day one (measured 11/1325 rows = 0.8%) and it
# abstained on 100% of its input while printing the same line as a guard that
# had cleared everything.
#
# These legs pin the three things that were wrong, each in BOTH directions so
# the suite cannot pass by reporting everything or nothing.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    WORK="$(mktemp -d -t t2916-XXXXXX)"
    mkdir -p "$WORK/.tasks/active" "$WORK/.context"
    git -C "$WORK" init -q 2>/dev/null || true
    git -C "$WORK" config user.email t@t 2>/dev/null || true
    git -C "$WORK" config user.name t 2>/dev/null || true
}

teardown() { rm -rf "$WORK"; }

# Write a task file with a controllable last_update.
mk_task() {  # mk_task <id> <last_update> [ac_ticked]
    local id="$1" lu="$2" ticked="${3:-0}"
    { echo "---"
      echo "id: $id"
      echo "name: \"$id\""
      echo "status: started-work"
      echo "workflow_type: build"
      echo "owner: agent"
      echo "horizon: now"
      echo "last_update: '$lu'"
      echo "---"
      echo
      echo "## Acceptance Criteria"
      echo
      echo "### Agent"
      local i
      for ((i=0; i<ticked; i++)); do echo "- [x] done $i"; done
      echo "- [ ] pending"
    } > "$WORK/.tasks/active/$id-t.md"
}

# Append N dispatch rows for <id> at <ts>, with or without a task_snapshot.
mk_dispatches() {  # mk_dispatches <id> <n> <ts> <with_snapshot:0|1>
    local id="$1" n="$2" ts="$3" snap="$4" i
    for ((i=0; i<n; i++)); do
        if [ "$snap" = "1" ]; then
            echo "{\"task_id\":\"$id\",\"ts\":\"$ts\",\"dispatch_id\":\"d$i\",\"task_snapshot\":{\"status\":\"started-work\",\"ac_ticked\":0}}"
        else
            echo "{\"task_id\":\"$id\",\"ts\":\"$ts\",\"dispatch_id\":\"d$i\"}"
        fi
    done >> "$WORK/.context/dispatches.jsonl"
}

run_stalled() {  # run_stalled -> JSON on stdout
    ( cd "$WORK" && PROJECT_ROOT="$WORK" python3 "$FRAMEWORK_ROOT/lib/resolver.py" \
        stalled --stall-after 5 --json 2>/dev/null )
}

@test "t2916: a task with NO task_snapshot on any row is still evaluated (degraded path)" {
    # The exact pre-fix blind spot: 5 snapshot-less dispatches, task untouched
    # since before the window opened. Pre-T-2916 this was skipped entirely.
    mk_task T-9001 "2026-01-01T00:00:00Z"
    mk_dispatches T-9001 5 "2026-06-01T00:00:00Z" 0
    out="$(run_stalled)"
    echo "$out" | grep -q 'T-9001'
    echo "$out" | grep -q '"evidence": "degraded"'
}

@test "t2916: the degraded path does NOT report a task whose last_update moved (opposite direction)" {
    # Same shape, one difference: the task was touched AFTER the window opened.
    # If this leg goes red the fix is over-reporting, which is the worse error —
    # a false stall silently locks a task out (the T-2915 failure mode).
    mk_task T-9002 "2026-06-02T00:00:00Z"
    mk_dispatches T-9002 5 "2026-06-01T00:00:00Z" 0
    out="$(run_stalled)"
    ! echo "$out" | grep -q 'T-9002'
}

@test "t2916: the snapshot path still works and is labelled as full evidence" {
    mk_task T-9003 "2026-01-01T00:00:00Z"
    mk_dispatches T-9003 5 "2026-06-01T00:00:00Z" 1
    out="$(run_stalled)"
    echo "$out" | grep -q 'T-9003'
    echo "$out" | grep -q '"evidence": "snapshot"'
}

@test "t2916: below-threshold tasks are counted as coverage, not silently dropped" {
    mk_task T-9004 "2026-01-01T00:00:00Z"
    mk_dispatches T-9004 2 "2026-06-01T00:00:00Z" 0
    out="$(run_stalled)"
    [[ "$out" != *"T-9004"* ]]          # 2 < 5, correctly not stalled
    echo "$out" | grep -q '"below_threshold": 1'   # but it IS accounted for
}

@test "t2916: coverage is present in JSON even when nothing is stalled" {
    # The defect in one leg: a verdict with no denominator. "nothing stalled"
    # must never again be printable without saying what was looked at.
    mk_task T-9005 "2026-06-02T00:00:00Z"
    mk_dispatches T-9005 5 "2026-06-01T00:00:00Z" 0
    out="$(run_stalled)"
    echo "$out" | grep -q '"stalled": {}'
    echo "$out" | grep -q '"coverage"'
    echo "$out" | grep -q '"evaluated"'
    echo "$out" | grep -q '"tasks_seen"'
}

@test "t2916: coverage prints on the human path too, not only --json" {
    mk_task T-9006 "2026-06-02T00:00:00Z"
    mk_dispatches T-9006 5 "2026-06-01T00:00:00Z" 0
    out="$( cd "$WORK" && PROJECT_ROOT="$WORK" python3 "$FRAMEWORK_ROOT/lib/resolver.py" \
        stalled --stall-after 5 2>/dev/null )"
    echo "$out" | grep -q 'no tasks stalled'
    echo "$out" | grep -q 'evaluated'
}

@test "t2916: a commit that merely CITES the task does not count as advancement" {
    # Origin case. T-2862 (60 dispatches, 0 outcomes, last_update frozen) was
    # cleared from the stalled set by commits 387a1465b and e7cce384b — the
    # T-2914 and T-2916 commits, which name T-2862 in their BODIES as the
    # example of a stalled task. Writing the RCA about a stall made the stall
    # undetectable. Advancement is declared in the subject, per P-002.
    mk_task T-9007 "2026-01-01T00:00:00Z"
    mk_dispatches T-9007 5 "2026-06-01T00:00:00Z" 0
    ( cd "$WORK" && git add -A >/dev/null 2>&1
      git commit -q -m "T-9999: unrelated work

      Cites T-9007 in the body as an example, but does not advance it." >/dev/null 2>&1 )
    out="$(run_stalled)"
    echo "$out" | grep -q 'T-9007'
}

@test "t2916: a commit whose SUBJECT claims the task does count as advancement" {
    # Opposite direction of the leg above — subject-match must still fire, or
    # the guard would report every task with a frozen last_update forever.
    mk_task T-9008 "2026-01-01T00:00:00Z"
    mk_dispatches T-9008 5 "2026-06-01T00:00:00Z" 0
    ( cd "$WORK" && git add -A >/dev/null 2>&1
      git commit -q -m "T-9008: actually advanced this task" >/dev/null 2>&1 )
    out="$(run_stalled)"
    ! echo "$out" | grep -q 'T-9008'
}
