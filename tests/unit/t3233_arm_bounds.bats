#!/usr/bin/env bats
# T-3233 — `fw continuous arm` must not report a bound it does not enforce.
#
# arc-012 review findings W1-F2, W1-F3, W1-F4 and W1-F8/W5-F4: four defects in one
# verb, all the same shape. `arm` printed a confident summary of a run it had not
# actually bounded.
#
# THE CENTRAL TEST is `printed ceiling equals enforced ceiling`. Asserting either
# side alone is what let this ship: `arm` printed `Ceiling: tier 5` truthfully —
# that IS what it wrote to state — while `inject-next-directive.py:261` resolves
# DIRECTIVE-first and used the stale `1` sitting in `.next-directive.yaml`. Both
# numbers were individually correct about their own file. Only the comparison is
# the defect. Measured on the pre-fix code:
#
#   --tier-ceiling 5 over a stale directive ceiling of 1  ->  printed 5, enforced 1
#   nothing set anywhere                                  ->  printed -, enforced 1
#
# The second is the quieter one: `-` reads as "no ceiling" and the operator gets
# the strictest possible value.
#
# WHY THE ENFORCER IS INVOKED FOR REAL rather than its precedence re-typed here: a
# guard that reimplements the code it guards cannot detect that code changing
# (G-072). `inject-next-directive.py` prints `tier_ceiling N` in the directive
# block it emits, which is the enforcer stating its own resolved value — so the
# comparison runs against the real program, not against a copy of its rules.
#
# NOT TESTED BY PERMISSIONS. The suite runs as root here and in CI, so chmod-based
# "the second write fails" fixtures do not deny anything and the test would pass
# while measuring nothing (the T-3217 / W4-F2 lesson). Write ORDER is asserted on
# mtime instead, which is observable regardless of uid.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    FW="$REPO/bin/fw"
    INJECTOR="$REPO/agents/context/inject-next-directive.py"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active"
    touch "$SB/.framework.yaml"

    # Fixture assertion, not a spot-check (same discipline as t3225).
    [ "$SB" != "$REPO" ]
    [ -f "$SB/.framework.yaml" ]
    DIR_F="$SB/.context/working/.next-directive.yaml"
    STATE_F="$SB/.context/working/.continuous-mode.yaml"
}

# What the ENFORCER resolves, from its own emitted directive block.
enforced_ceiling() {
    python3 "$INJECTOR" --project-root "$SB" --source resume 2>/dev/null \
        | grep -o 'tier_ceiling [0-9]*' | head -1 | awk '{print $2}'
}

# What ARM printed.
printed_ceiling() {
    printf '%s' "$1" | grep -o 'Ceiling: tier [0-9]*' | head -1 | awk '{print $3}'
}

_plant_directive() { printf 'directive: %s\n' "${1:-planted}" > "$DIR_F"; }

# ── the central comparison ────────────────────────────────────────────────────

@test "control: the enforcer reports a ceiling at all (harness can measure)" {
    _plant_directive
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --tier-ceiling 4
    [ "$status" -eq 0 ]
    [ -n "$(enforced_ceiling)" ]
}

@test "printed ceiling equals enforced ceiling OVER A STALE DIRECTIVE VALUE" {
    # The adversarial fixture: a directive already carrying tier_ceiling 1, which
    # is exactly what this repo's own .next-directive.yaml carries. Pre-fix this
    # printed 5 and enforced 1.
    printf 'directive: planted\ntier_ceiling: 1\n' > "$DIR_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --tier-ceiling 5
    [ "$status" -eq 0 ]
    [ "$(printed_ceiling "$output")" = "5" ]
    [ "$(enforced_ceiling)" = "5" ]
}

@test "control: printed equals enforced with no stale value either (not stuck at 5)" {
    _plant_directive
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --tier-ceiling 2
    [ "$(printed_ceiling "$output")" = "2" ]
    [ "$(enforced_ceiling)" = "2" ]
}

@test "with nothing set anywhere, arm prints the enforcer's default, not a dash" {
    _plant_directive
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 0 ]
    [[ "$output" != *"Ceiling: tier -"* ]]
    [ "$(printed_ceiling "$output")" = "1" ]
    [ "$(enforced_ceiling)" = "1" ]
}

@test "status agrees with arm on the ceiling" {
    printf 'directive: planted\ntier_ceiling: 1\n' > "$DIR_F"
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --tier-ceiling 5 >/dev/null
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [[ "$output" == *"Tier ceiling: 5"* ]]
}

@test "status resolves DIRECTIVE-first when the two files disagree" {
    # This is the leg the rest of the suite cannot see. Once arm writes the
    # ceiling to both files, state-first and directive-first agree on everything
    # arm produces — so reverting the resolver to state-only reddened NOTHING
    # until this test existed (mutation M2). The disagreement is still reachable:
    # anything other than arm can write the directive — a hand edit, a pickup, a
    # prior run's file — and F2's second direction is exactly this, a directive
    # carrying 6 silently WIDENING an arm of 1.
    #
    # Planted directly rather than via arm, because arm is now (correctly)
    # incapable of producing this state.
    printf 'directive: planted\nexpires_at: 2099-01-01T00:00:00Z\ntier_ceiling: 6\n' > "$DIR_F"
    printf 'enabled: true\ncurrent_iteration: 0\ntier_ceiling: 2\n' > "$STATE_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [[ "$output" == *"Tier ceiling: 6"* ]]
    # And the enforcer must agree — that is the whole point of the chain.
    [ "$(enforced_ceiling)" = "6" ]
}

# ── the task cap (W1-F4) ──────────────────────────────────────────────────────

@test "--max-tasks is written to BOTH files" {
    _plant_directive
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --max-tasks 7
    [ "$status" -eq 0 ]
    grep -q 'max_tasks: 7' "$DIR_F"
    grep -q 'max_tasks: 7' "$STATE_F"
    [[ "$output" == *"Max tasks: 7"* ]]
}

@test "a stale max_tasks is CLEARED when the flag is absent" {
    # Pre-fix, this value survived the arm and halted the run after 2 tasks with
    # a ceiling that appeared in neither the arm output nor status.
    printf 'directive: planted\nmax_tasks: 2\n' > "$DIR_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 0 ]
    [ "$(grep -c 'max_tasks' "$DIR_F")" -eq 0 ]
    [[ "$output" == *"Max tasks: unset"* ]]
}

@test "completed_task_ids is cleared in the same arm that zeroes the counter" {
    _plant_directive
    printf 'tasks_completed: 4\ncompleted_task_ids: [T-1, T-2]\n' > "$STATE_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 0 ]
    grep -q 'completed_task_ids: \[\]' "$STATE_F"
    grep -q 'tasks_completed: 0' "$STATE_F"
}

# ── the no-op arm (W1-F3) ─────────────────────────────────────────────────────

@test "arm refuses when the result would carry no directive text (exit 2)" {
    # inject-next-directive.py returns before write_state() without a directive
    # string, so this arm would restart sessions forever without advancing the
    # counter or issuing marching orders — while printing a confident bound.
    rm -f "$DIR_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 2 ]
    [[ "$output" == *"no directive text"* ]]
}

@test "control: arm succeeds when the directive file already carries one" {
    _plant_directive "already here"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 0 ]
}

@test "control: --directive satisfies the refusal on an empty sandbox" {
    rm -f "$DIR_F"
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "go"
    [ "$status" -eq 0 ]
    grep -q 'directive: go' "$DIR_F"
}

# ── write order (W1-F8 / W5-F4) ───────────────────────────────────────────────

@test "the directive file is written BEFORE the state file" {
    # Per-file atomicity is not atomicity across a pair. If the process dies
    # between the two saves, the ORDER decides which half-state is reachable:
    #   state first  -> enabled:true + the PREVIOUS expiry = armed and instantly
    #                   dead, the exact 74-day state the header promises cannot
    #                   happen;
    #   directive first -> fresh expiry + still disarmed = harmless.
    _plant_directive
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 >/dev/null
    run python3 -c "
import os,sys
d=os.stat('$DIR_F').st_mtime_ns
s=os.stat('$STATE_F').st_mtime_ns
sys.exit(0 if d <= s else 1)
"
    [ "$status" -eq 0 ]
}

@test "arm names the bounds that bind a Stop-hook-driven run" {
    # current_iteration advances only across SessionStart; the Stop hook drives
    # turns inside one session. Leading with the session count read as the
    # operative bound when it cannot tick at all in that mode.
    _plant_directive
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [[ "$output" == *"Stop-hook-driven run"* ]]
    [[ "$output" == *"advances only across SessionStart"* ]]
}
