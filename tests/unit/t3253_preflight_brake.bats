#!/usr/bin/env bats
# T-3253 AC3 — the breaching session is never launched.
#
# E10 measured the hole these pin: the ceiling was evaluated in the SessionStart
# hook of a session that had ALREADY relaunched carrying the armed directive as
# its prompt, so the breach notice arrived as advisory additionalContext and lost
# the argument with "do not stop until every task is closed". The over-ceiling
# task was closed 4m26s after the brake fired.
#
# These drive the real inject-next-directive.py against a scratch project root,
# for the reason continuous_mode_disarm.bats records: a test written against a
# transcription of the logic would miss the whole point.
#
# EVERY BRAKE CASE HAS A CONTROL. A refusal that fires for the wrong reason is
# indistinguishable from one that fires for the right one unless the passing leg
# is measured too — the same indistinguishability the E10 rig exists to break.

setup() {
    INJECTOR="${BATS_TEST_DIRNAME}/../../agents/context/inject-next-directive.py"
    WRAPPER="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working" "$ROOT/.tasks/active"
    STATE="$ROOT/.context/working/.continuous-mode.yaml"
    DIRECTIVE="$ROOT/.context/working/.next-directive.yaml"
}

teardown() {
    [ -n "${ROOT:-}" ] && rm -rf "$ROOT"
}

# A task whose BVP cost_estimate.blast_radius is $1 — the only input the
# ceiling comparison reads (resolve_task_blast_radius).
task_with_blast() {
    cat > "$ROOT/.tasks/active/T-900-escalation.md" <<YAML
---
id: T-900
name: "escalation task"
cost_estimate:
  blast_radius: ${1}
---
YAML
}

armed() {
    cat > "$STATE" <<YAML
enabled: true
current_iteration: ${1:-3}
max_iterations: ${2:-10}
tier_ceiling: 1
last_terminated_reason: ''
YAML
}

# Directive naming T-900 as the planned next action. expires far in the future so
# expiry never confounds the ceiling leg.
directive() {
    cat > "$DIRECTIVE" <<YAML
next_task: T-900
directive: |
  work T-900 and do not stop until every task is closed
filed_at: 2099-01-01T00:00:00Z
expires_at: 2099-01-01T00:00:00Z
max_iterations: ${1:-10}
tier_ceiling: 1
YAML
}

preflight() { python3 "$INJECTOR" --project-root "$ROOT" --preflight; }
iter_now()  { python3 -c "import yaml;print(yaml.safe_load(open('$STATE')).get('current_iteration'))"; }
enabled_now() { python3 -c "import yaml;print(yaml.safe_load(open('$STATE')).get('enabled'))"; }

# ---------------------------------------------------------------------------
# The brake fires
# ---------------------------------------------------------------------------

@test "ceiling breach exits 3 and names the bound on stdout" {
    task_with_blast 5; armed; directive
    run preflight
    [ "$status" -eq 3 ]
    [[ "$output" == *"tier ceiling exceeded"* ]]
    [[ "$output" == *"T-900"* ]]
}

@test "ceiling breach FREEZES the counter (not advances it)" {
    task_with_blast 5; armed 3; directive
    run preflight
    [ "$status" -eq 3 ]
    [ "$(iter_now)" = "3" ]
}

@test "ceiling breach disarms the flag in the same write (T-3167)" {
    task_with_blast 5; armed; directive
    run preflight
    [ "$status" -eq 3 ]
    [ "$(enabled_now)" = "False" ]
}

@test "max_iterations breach exits 3 — the ceiling is not the only bound" {
    task_with_blast 1; armed 4 4; directive 4
    run preflight
    [ "$status" -eq 3 ]
    [[ "$output" == *"exceeds max_iterations"* ]]
}

# ---------------------------------------------------------------------------
# CONTROLS — the brake stays off, and writes nothing
# ---------------------------------------------------------------------------

@test "CONTROL: blast_radius at the ceiling does not breach" {
    # blast 1 == ceiling 1. The comparison is `>`, so this must pass. A control of
    # "no blast_radius at all" would fail on the `is not None` clause instead and
    # prove only that an unresolvable radius is quiet.
    task_with_blast 1; armed; directive
    run preflight
    [ "$status" -eq 0 ]
}

@test "CONTROL: the clear path writes NOTHING — no double-advance" {
    # evaluate() returns an ADVANCED counter and SessionStart is about to advance
    # it again for this same restart. Writing here would double-advance every
    # iteration, invisible until someone counted.
    task_with_blast 1; armed 3; directive
    before="$(md5sum "$STATE" | cut -d' ' -f1)"
    run preflight
    [ "$status" -eq 0 ]
    [ "$(md5sum "$STATE" | cut -d' ' -f1)" = "$before" ]
    [ "$(iter_now)" = "3" ]
}

@test "CONTROL: an absent state file is left absent and exits 0 (T-179 guard)" {
    # `enabled: false` on a fresh file means "never switched on". If the preflight
    # treated that as a brake it would delete budget auto-restart for every user
    # who never armed a run — nearly all of them.
    task_with_blast 5; directive
    run preflight
    [ "$status" -eq 0 ]
    [ ! -f "$STATE" ]
}

@test "CONTROL: a disarmed run is a no-op, not a brake" {
    task_with_blast 5; directive
    cat > "$STATE" <<YAML
enabled: false
current_iteration: 0
YAML
    before="$(md5sum "$STATE" | cut -d' ' -f1)"
    run preflight
    [ "$status" -eq 0 ]
    [ "$(md5sum "$STATE" | cut -d' ' -f1)" = "$before" ]
}

@test "CONTROL: without --preflight the same inputs still emit and write" {
    # Proves the preflight branch is what changed behaviour, not the fixture.
    task_with_blast 1; armed 3; directive
    run python3 "$INJECTOR" --project-root "$ROOT" --source resume
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next Directive"* ]]
    [ "$(iter_now)" = "4" ]
}

# ---------------------------------------------------------------------------
# Wiring — the order the wrapper consults it in
# ---------------------------------------------------------------------------

@test "wrapper consults the preflight BEFORE taking restart budget" {
    # A loop stopped by a BOUND must not have the ledger report a RATE limit as
    # its cause. Ordering is the whole guarantee, so it is asserted rather than
    # trusted: the preflight call must precede _restart_budget_take in the source.
    pre="$(grep -n '_continuous_preflight)' "$WRAPPER" | head -1 | cut -d: -f1)"
    take="$(grep -n '_restart_budget_take$' "$WRAPPER" | tail -1 | cut -d: -f1)"
    [ -n "$pre" ]
    [ -n "$take" ]
    [ "$pre" -lt "$take" ]
}

@test "wrapper records the refusal under its own ledger reason" {
    # Distinct from continuous-terminated: one means the death was on the books
    # before we looked, the other that we found it by evaluating the plan.
    grep -q '_record_loop_event exit continuous-preflight' "$WRAPPER"
    grep -q '_record_loop_event exit continuous-terminated' "$WRAPPER"
}
