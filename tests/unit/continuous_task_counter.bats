#!/usr/bin/env bats
# T-3169 (arc-012 S3) — the TASK-keyed ceiling.
#
# Two ceilings now exist and they are counted in different units: sessions
# (context windows spent) and tasks (work done). Every test below exists because
# collapsing them back into one number is the easy mistake.

setup() {
    LIB="${BATS_TEST_DIRNAME}/../../lib/continuous-mode.sh"
    DRIVER="${BATS_TEST_DIRNAME}/../../agents/context/stop-driver.sh"
    ROOT="$(mktemp -d)"
    export CLAUDE_PROJECT_DIR="$ROOT"
    mkdir -p "$ROOT/.context/working"
    STATE="$ROOT/.context/working/.continuous-mode.yaml"
    # shellcheck source=/dev/null
    . "$LIB"
}

teardown() {
    [ -n "${ROOT:-}" ] && rm -rf "$ROOT"
}

write_state() {
    cat > "$STATE" <<YAML
enabled: ${1:-true}
max_iterations: 100
current_iteration: 1
tasks_completed: ${2:-0}
${3:-}
YAML
}

read_field() {
    python3 -c "
import yaml
print(yaml.safe_load(open('$STATE')).get('$1'))"
}

run_driver() {
    printf '{}' | bash "$DRIVER"
}

# --- the counter ------------------------------------------------------------

@test "an armed loop counts a completed task" {
    write_state true 0
    fw_continuous_note_task_completed T-1 "$ROOT"
    [ "$(read_field tasks_completed)" = "1" ]
}

@test "counting the same task twice advances the count once" {
    # `--status work-completed` is re-runnable: partial-complete tasks come back
    # through it after the human ticks their ACs.
    write_state true 0
    fw_continuous_note_task_completed T-1 "$ROOT"
    fw_continuous_note_task_completed T-1 "$ROOT"
    [ "$(read_field tasks_completed)" = "1" ]
}

@test "distinct tasks each advance the count" {
    write_state true 0
    fw_continuous_note_task_completed T-1 "$ROOT"
    fw_continuous_note_task_completed T-2 "$ROOT"
    [ "$(read_field tasks_completed)" = "2" ]
}

@test "a DISARMED loop counts nothing — the control leg" {
    # Without this, an unconditional increment satisfies every test above while
    # making every ordinary session's closes look like loop progress.
    write_state false 0
    fw_continuous_note_task_completed T-1 "$ROOT"
    [ "$(read_field tasks_completed)" = "0" ]
}

@test "no state file is a silent no-op, not an error" {
    rm -f "$STATE"
    run fw_continuous_note_task_completed T-1 "$ROOT"
    [ "$status" -eq 0 ]
}

@test "the other counter is left alone" {
    # Sessions and tasks are different units; advancing one must not advance the other.
    write_state true 0
    fw_continuous_note_task_completed T-1 "$ROOT"
    [ "$(read_field current_iteration)" = "1" ]
}

# --- the ceiling, in the driver ---------------------------------------------

@test "the driver stops when the task ceiling is reached" {
    write_state true 3 "max_tasks: 3"
    run run_driver
    [ "$output" = "{}" ]
    grep -q "max_tasks-reached" "$ROOT/.context/working/.stop-driver.log"
}

@test "the driver names the TASK cap, not the session cap, when tasks ran out" {
    # The two stops mean opposite things to the operator: work finished, versus
    # budget exhausted. A shared reason string erases the difference.
    write_state true 3 "max_tasks: 3"
    run run_driver
    ! grep -q "max_iterations-reached" "$ROOT/.context/working/.stop-driver.log"
}

@test "under the task ceiling the driver continues — the control leg" {
    write_state true 1 "max_tasks: 5"
    run run_driver
    echo "$output" | grep -q '"decision": "block"'
}

@test "an UNSET max_tasks is unbounded, not a ceiling of zero" {
    # The failure this guards: `max_tasks` absent read as 0, so `0 >= 0` stops the
    # loop before it has done anything, on every project that never set the field.
    write_state true 0
    run run_driver
    echo "$output" | grep -q '"decision": "block"'
}

@test "a per-directive max_tasks overrides the state value" {
    write_state true 2 "max_tasks: 99"
    cat > "$ROOT/.context/working/.next-directive.yaml" <<YAML
directive: "keep going"
max_tasks: 2
YAML
    run run_driver
    [ "$output" = "{}" ]
}
