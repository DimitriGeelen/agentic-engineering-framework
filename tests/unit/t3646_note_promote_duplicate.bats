#!/usr/bin/env bats
# T-3646 — `fw note promote OBS-NNN` must not silently create a second task
# when a task already names that observation id.
#
# Ported from 055-agentic-fleet-cockpit (P-007, framework:pickup offset 238,
# their task 348; also OBS-064 at offset 221), re-derived against our code.
# A recurrence is legitimate, so the refusal informs and offers
# --allow-duplicate rather than hard-blocking forever.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

setup() {
    export TEST_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_DIR"
    mkdir -p "$TEST_DIR/.context/working" "$TEST_DIR/.tasks/active" "$TEST_DIR/.tasks/completed"
    echo 'current_task: T-001' > "$TEST_DIR/.context/working/focus.yaml"
    cat > "$TEST_DIR/.context/inbox.yaml" <<'YAML'
observations:
- id: OBS-022
  text: "Duplicate-prone observation"
  captured: 2026-10-01T00:00:00Z
  context_task: T-001
  tags: []
  status: pending
  promoted_to: null
YAML
    cp "$TEST_DIR/.context/inbox.yaml" "$TEST_DIR/inbox.orig"
}

teardown() { rm -rf "$TEST_DIR"; }

_task() {  # $1 dir (active|completed)  $2 id  $3 body line
    printf -- '---\nid: %s\nname: "x"\nstatus: started-work\nworkflow_type: build\n---\n# %s\n\n%s\n' \
        "$2" "$2" "$3" > "$TEST_DIR/.tasks/$1/$2-x.md"
}

_ntasks() { find "$TEST_DIR/.tasks" -name 'T-*.md' | wc -l; }

@test "T-3646: promote refuses when an ACTIVE task already names the OBS id" {
    _task active T-0500 "Promoted from observation OBS-022"
    before=$(_ntasks)
    run "$OBSERVE" promote OBS-022
    [ "$status" -eq 1 ]
    [ "$(_ntasks)" -eq "$before" ]
    cmp -s "$TEST_DIR/.context/inbox.yaml" "$TEST_DIR/inbox.orig"
    [[ "$output" == *"T-0500"* ]]
    [[ "$output" == *"--allow-duplicate"* ]]
    [[ "$output" == *"fw note dismiss OBS-022"* ]]
}

@test "T-3646: promote refuses when a COMPLETED task already names the OBS id" {
    _task completed T-0501 "Fixes OBS-022."
    run "$OBSERVE" promote OBS-022
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-0501"* ]]
    cmp -s "$TEST_DIR/.context/inbox.yaml" "$TEST_DIR/inbox.orig"
}

@test "T-3646: --allow-duplicate promotes anyway" {
    _task active T-0500 "Promoted from observation OBS-022"
    before=$(_ntasks)
    run "$OBSERVE" promote OBS-022 --allow-duplicate
    [ "$status" -eq 0 ]
    [ "$(_ntasks)" -eq $((before + 1)) ]
    grep -q "status: promoted" "$TEST_DIR/.context/inbox.yaml"
}

@test "T-3646 boundary: OBS-0220 / OBS-0221 in a task do NOT block OBS-022" {
    _task active T-0502 "About OBS-0220 and OBS-0221 only"
    before=$(_ntasks)
    run "$OBSERVE" promote OBS-022
    [ "$status" -eq 0 ]
    [ "$(_ntasks)" -eq $((before + 1)) ]
}

@test "T-3646 control: no task names the id → promote proceeds" {
    before=$(_ntasks)
    run "$OBSERVE" promote OBS-022
    [ "$status" -eq 0 ]
    [ "$(_ntasks)" -eq $((before + 1)) ]
    grep -q "status: promoted" "$TEST_DIR/.context/inbox.yaml"
}
