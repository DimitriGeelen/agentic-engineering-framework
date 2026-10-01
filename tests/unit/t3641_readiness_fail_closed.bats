#!/usr/bin/env bats
# T-3641 — the decision-readiness gate must fail CLOSED, not open.
#
# Ported from 055-agentic-fleet-cockpit (framework:pickup offset 207 FINDING 8,
# P-001 offset 230, their task 294). Re-derived against our code.
#
# Before the fix, all three call sites of inception_underdisposed_questions
# loaded lib/inception-readiness.sh with `2>/dev/null || true` (or `|| return 0`)
# and then gated on `command -v` or simply returned. So:
#   - library missing          → decide preflight skipped, close gate returned 0
#   - predicate crashed (rc>1) → `|| true` swallowed it, empty output read as "ready"
# Both silently let an undisposed inception through the sovereignty path.
#
# Negative controls: with the library intact the gate still flags an undisposed
# question, and a NON-inception task still closes when the library is missing.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REAL_ROOT="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    unset FW_SKIP_DISPOSITION_GATE
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working"
    UPDATE_SH="$REAL_ROOT/agents/task-create/update-task.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# A fake FRAMEWORK_ROOT whose lib/ is the real one minus inception-readiness.sh.
# $1 = "missing" | "crash" | "undefined"
_fake_root() {
    local mode="$1" fake="$TEST_TEMP_DIR/fwroot"
    mkdir -p "$fake/lib"
    local e
    for e in "$REAL_ROOT"/*; do
        [ "$(basename "$e")" = lib ] && continue
        ln -s "$e" "$fake/$(basename "$e")"
    done
    for e in "$REAL_ROOT"/lib/*; do
        [ "$(basename "$e")" = inception-readiness.sh ] && continue
        ln -s "$e" "$fake/lib/$(basename "$e")"
    done
    case "$mode" in
        crash)
            printf '%s\n' 'inception_underdisposed_questions() { return 3; }' \
                > "$fake/lib/inception-readiness.sh" ;;
        undefined)
            printf '%s\n' '# defines nothing' > "$fake/lib/inception-readiness.sh" ;;
    esac
    echo "$fake"
}

_make_task() {
    local id="$1" wf="$2"
    local path="$PROJECT_ROOT/.tasks/active/${id}-ro-test.md"
    cat > "$path" << EOF
---
id: $id
name: "readiness fail-closed test"
status: started-work
workflow_type: $wf
owner: human
horizon: now
target_blast_radius: 3
voi_score: 0.5
created: 2026-10-01T00:00:00Z
last_update: 2026-10-01T00:00:00Z
---

# $id: readiness fail-closed test

## Open Questions

- **IW-1: undisposed question?**
  confidence: 1
  disposition:
  rationale:

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated

## Recommendation

**Recommendation:** GO
**Rationale:** substantive rationale for the fixture, long enough to pass audits here.
**Evidence:**
- fixture evidence line

## Decision

## Updates
EOF
    touch "$PROJECT_ROOT/.context/working/.reviewed-${id}"
    echo "$path"
}

# Run check_disposition_gate extracted from update-task.sh, against $1 root.
_run_close_gate() {
    local root="$1" file="$2"
    run bash -c "
        set -euo pipefail
        FRAMEWORK_ROOT='$root'
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
}

# Run do_inception_decide with $1 as FRAMEWORK_ROOT, in a fresh shell.
_run_decide() {
    local root="$1" id="$2"
    run bash -c "
        export FRAMEWORK_ROOT='$root' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1
        export AGENTS_DIR='$root/agents' FW_LIB_DIR='$root/lib'
        unset CLAUDECODE
        source '$root/lib/colors.sh'
        source '$root/lib/errors.sh'
        source '$root/lib/tasks.sh'
        source '$root/lib/inception.sh'
        unset -f inception_underdisposed_questions
        [ -f '$root/lib/inception-readiness.sh' ] && source '$root/lib/inception-readiness.sh'
        do_inception_decide $id go --rationale 'test go' --i-am-human
    "
}

# ---- negative controls: the gate still loads and still flags ----

@test "C1 control: close gate with intact library refuses an undisposed inception" {
    f=$(_make_task T-9641 inception)
    _run_close_gate "$REAL_ROOT" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"IW-1"* ]]
}

@test "C2 control: decide with intact library refuses and leaves the body untouched" {
    f=$(_make_task T-9642 inception)
    before=$(md5sum "$f" | awk '{print $1}')
    _run_decide "$REAL_ROOT" T-9642
    [ "$status" -ne 0 ]
    [ "$before" = "$(md5sum "$f" | awk '{print $1}')" ]
}

# ---- close gate (update-task.sh) ----

@test "U1 close gate: library MISSING refuses an inception loudly" {
    fake=$(_fake_root missing)
    f=$(_make_task T-9643 inception)
    _run_close_gate "$fake" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"inception-readiness.sh"* ]]
}

@test "U2 close gate: library MISSING still passes a non-inception task" {
    fake=$(_fake_root missing)
    f=$(_make_task T-9644 build)
    _run_close_gate "$fake" "$f"
    [ "$status" -eq 0 ]
}

@test "U3 close gate: predicate CRASH (rc>1, no output) refuses an inception" {
    fake=$(_fake_root crash)
    f=$(_make_task T-9645 inception)
    _run_close_gate "$fake" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"rc=3"* ]]
}

@test "U4 close gate: predicate UNDEFINED after sourcing refuses an inception" {
    fake=$(_fake_root undefined)
    f=$(_make_task T-9646 inception)
    _run_close_gate "$fake" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"inception_underdisposed_questions"* ]]
}

# ---- decide preflight (lib/inception.sh) ----

@test "D1 decide: library MISSING refuses, names the path, writes nothing" {
    fake=$(_fake_root missing)
    f=$(_make_task T-9647 inception)
    before=$(md5sum "$f" | awk '{print $1}')
    _run_decide "$fake" T-9647
    [ "$status" -ne 0 ]
    [[ "$output" == *"inception-readiness.sh"* ]]
    [[ "$output" == *"Nothing was written"* ]]
    [ "$before" = "$(md5sum "$f" | awk '{print $1}')" ]
}

@test "D2 decide: predicate CRASH refuses and writes nothing" {
    fake=$(_fake_root crash)
    f=$(_make_task T-9648 inception)
    before=$(md5sum "$f" | awk '{print $1}')
    _run_decide "$fake" T-9648
    [ "$status" -ne 0 ]
    [[ "$output" == *"rc=3"* ]]
    [ "$before" = "$(md5sum "$f" | awk '{print $1}')" ]
}

@test "D3 decide: predicate UNDEFINED refuses and writes nothing" {
    fake=$(_fake_root undefined)
    f=$(_make_task T-9649 inception)
    before=$(md5sum "$f" | awk '{print $1}')
    _run_decide "$fake" T-9649
    [ "$status" -ne 0 ]
    [ "$before" = "$(md5sum "$f" | awk '{print $1}')" ]
}

# ---- review emission (lib/review.sh): warn-only, but must warn ----

@test "R1 review: library MISSING warns that readiness could not be checked" {
    fake=$(_fake_root missing)
    f=$(_make_task T-9650 inception)
    run bash -c "
        export FRAMEWORK_ROOT='$fake' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1
        source '$fake/lib/colors.sh'
        source '$fake/lib/review.sh'
        emit_review T-9650 '$f'
    "
    [[ "$output" == *"readiness could NOT be checked"* ]]
}
