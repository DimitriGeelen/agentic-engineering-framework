#!/usr/bin/env bats
# Regression: fw context add-decision and add-learning must produce
# YAML that parses cleanly even when the input contains backslash-
# anything sequences (\s, \`, \', \bash, etc.) that YAML 1.2 rejects.
#
# Origin: T-1543 / OBS-033. Recurrence shown by L-294 (T-1530), D-036
# (T-1540), D-038 (T-1541) — three hand-fixes in 3 days, same class.
# Both decision.sh (no escape) and learning.sh (only `"` escape via awk
# gsub) needed a shared `_yaml_escape_dquoted` helper.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/project" "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Stub the bus publisher so the test does not depend on bus state
    export FRAMEWORK_ROOT="$FRAMEWORK_ROOT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Hostile input set known to break YAML 1.2 double-quoted strings.
HOSTILE='Pattern grep -vE "^##|^\s*```|^\s*#|^\s*$" with `backticks` and \backslash and "double-quotes"'

@test "add-decision survives hostile input — YAML parses" {
    cd "$PROJECT_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" context add-decision "$HOSTILE" --task T-9999 --rationale "rationale with \\s and \" in it"
    [ -f "$CONTEXT_DIR/project/decisions.yaml" ]
    run python3 -c "import yaml; yaml.safe_load(open('$CONTEXT_DIR/project/decisions.yaml'))"
    [ "$status" -eq 0 ]
}

@test "add-decision round-trips: parsed value == input" {
    cd "$PROJECT_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" context add-decision "$HOSTILE" --task T-9999 --rationale "r"
    # Pass HOSTILE through env to avoid python-source-string escape interpretation
    HOSTILE="$HOSTILE" run python3 -c "
import os, yaml
data = yaml.safe_load(open(os.environ['CONTEXT_DIR'] + '/project/decisions.yaml'))
decisions = data.get('decisions', [])
assert len(decisions) == 1, f'expected 1 decision, got {len(decisions)}'
got = decisions[0]['decision']
want = os.environ['HOSTILE']
assert got == want, f'mismatch:\nwant: {want!r}\ngot:  {got!r}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "add-learning survives hostile input — YAML parses" {
    cd "$PROJECT_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" context add-learning "$HOSTILE" --task T-9999 --source P-001
    [ -f "$CONTEXT_DIR/project/learnings.yaml" ]
    run python3 -c "import yaml; yaml.safe_load(open('$CONTEXT_DIR/project/learnings.yaml'))"
    [ "$status" -eq 0 ]
}

@test "add-learning round-trips: parsed value == input" {
    cd "$PROJECT_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" context add-learning "$HOSTILE" --task T-9999 --source P-001
    HOSTILE="$HOSTILE" run python3 -c "
import os, yaml
data = yaml.safe_load(open(os.environ['CONTEXT_DIR'] + '/project/learnings.yaml'))
learnings = data.get('learnings', [])
assert len(learnings) == 1, f'expected 1 learning, got {len(learnings)}'
got = learnings[0]['learning']
want = os.environ['HOSTILE']
assert got == want, f'mismatch:\nwant: {want!r}\ngot:  {got!r}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "add-decision with rejected-list also escapes each item" {
    cd "$PROJECT_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" context add-decision "main" --task T-9999 --rejected 'alt with \s, alt with `tick`'
    run python3 -c "
import yaml
data = yaml.safe_load(open('$CONTEXT_DIR/project/decisions.yaml'))
rejected = data['decisions'][0].get('alternatives_rejected', [])
assert len(rejected) == 2, f'expected 2 items, got {len(rejected)}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}
