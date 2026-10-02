#!/usr/bin/env bats
# T-3694: design-conformance gate, end to end through the real entry points.
#
#   1. update-task.sh --status work-completed refuses a task whose own result defers
#      its work to a task that does not exist / is not active / never mentions it
#      (the T-3691 "deferred to T-3692/T-3693" hole), and accepts the same close
#      once the targets are real owners. Fixture text is T-3691's own task file.
#   2. update-task.sh refuses a slice on arc-011-shaped arcs (arc resolved by id:,
#      register linked by register_docs:) that defers an unowned register row, and
#      a task that closes while owning an unbuilt row.
#   3. `fw doctor` WARNs on a register row without a valid owner; silent-OK on a
#      clean register.
#
# Every test runs in a throwaway PROJECT_ROOT; nothing in the repo corpus is touched.
# The audit FAIL leg (agents/audit/audit.sh) is a thin call into the same module
# and is exercised against the live repo in the task's ## Verification.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
FIXTURE="$FRAMEWORK_ROOT/tests/fixtures/t3694/T-3691-as-closed.md"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE FW_SKIP_REGISTER_REQUIREMENTS
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/.context/arcs" \
             "$PROJECT_ROOT/docs/architecture"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _task ID STATUS ARC BODY — minimal closeable build task
_task() {
    local id="$1" status="$2" arc="$3" body="$4"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-fixture.md" <<EOF
---
id: ${id}
name: "fixture ${id}"
description: "T-3694 fixture"
status: ${status}
workflow_type: build
owner: agent
horizon: now
tags: []
arc_id: ${arc}
created: 2026-10-01T00:00:00Z
last_update: 2026-10-01T00:00:00Z
date_finished: null
---

# ${id}

${body}
EOF
}

_closeable_body() {
    printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n\n## Verification\n\n%s\n\n## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** fixture.\n' "$1"
}

_t3691_active() {
    cp "$FIXTURE" "$PROJECT_ROOT/.tasks/active/T-3691-design-conformance-gate.md"
    # The fixture's verification lines check the real repo; replace them so this
    # test reaches the deferral gate rather than failing on an unrelated path.
    # The deferral prose (Evolution, Recommendation) is left verbatim.
    python3 - "$PROJECT_ROOT/.tasks/active/T-3691-design-conformance-gate.md" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"(## Verification\n).*?(?=\n## )", r"\1\ntrue\n", s, flags=re.S)
# T-3691 carried an empty template ## Evolution ahead of its real one and closed
# with --skip-evolution; drop the empty copy so the Evolution gate is satisfied
# by T-3691's own real entry.
s = re.sub(r"## Evolution\n.*?(?=\n## Summary)", "", s, count=1, flags=re.S)
open(p, "w").write(s)
PY
}

_register() {
    cat > "$PROJECT_ROOT/docs/architecture/side.md" <<EOF
# side design

\`\`\`yaml
register:
  - id: R6
    text: "sender sees each state"
    owner_task: $1
    status: $2
\`\`\`
EOF
}

# ---------------------------------------------------------------- self-deferral

@test "T-3691 reproduction: close REFUSED when deferral targets are missing/unrelated" {
    _t3691_active
    _task T-3692 captured "" "Unrelated bug about sidecar inbox reads."
    run "$UPDATE_TASK" T-3691 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"defers its own work to a task that cannot own it"* ]]
    [[ "$output" == *"T-3693 does not exist"* ]]
    [[ "$output" == *"T-3692 never mentions T-3691"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-3691-design-conformance-gate.md" ]
}

@test "T-3691 control: same text closes once both targets are active and name it" {
    _t3691_active
    _task T-3692 captured "" "Owns T-3691 item 3."
    _task T-3693 captured "" "Owns T-3691 item 5."
    run "$UPDATE_TASK" T-3691 --status work-completed
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-3691-design-conformance-gate.md" ]
}

@test "self-deferral: agent cannot waive the gate with --skip-self-deferral" {
    _task T-0100 started-work "" "$(_closeable_body true)
Remaining work deferred to T-0404."
    export CLAUDECODE=1
    run "$UPDATE_TASK" T-0100 --status work-completed --skip-self-deferral --reason "test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused in an agent session"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-0100-fixture.md" ]
}

# ---------------------------------------------------------------- register close gate

@test "register gate: arc resolved by id (not filename) — unowned deferred row REFUSED" {
    printf 'id: arc-011\nslug: parallel-thing\nstatus: in-progress\nregister_docs:\n  - docs/architecture/side.md\n' \
        > "$PROJECT_ROOT/.context/arcs/parallel-thing.yaml"
    _register null unbuilt
    _task T-0300 started-work arc-011 "$(_closeable_body true)
R6 deferred."
    run "$UPDATE_TASK" T-0300 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"R6: deferred here but has no owner_task"* ]]
}

@test "register gate: owner closing while its row is partial REFUSED (T-3561 shape)" {
    _register T-0400 partial
    _task T-0400 started-work "" "$(_closeable_body true)"
    run "$UPDATE_TASK" T-0400 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"R6: owned by T-0400 and still 'partial'"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-0400-fixture.md" ]
}

@test "register gate control: owner closes once its row is built" {
    _register T-0400 built
    _task T-0400 started-work "" "$(_closeable_body true)"
    run "$UPDATE_TASK" T-0400 --status work-completed
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-0400-fixture.md" ]
}

# ---------------------------------------------------------------- doctor

@test "doctor WARNs on a register row whose owner does not exist" {
    _register T-0404 unbuilt
    run "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    [[ "$output" == *"WARN"*"Design-conformance register: row(s) without a valid owner"* ]]
    [[ "$output" == *"R6: owner_task T-0404 does not exist"* ]]
}

@test "doctor control: OK on a register whose owner is active" {
    _register T-0400 unbuilt
    _task T-0400 started-work "" "body"
    run "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    [[ "$output" == *"OK"*"Design-conformance register: every row has a valid owner"* ]]
    [[ "$output" != *"Design-conformance register: row(s) without"* ]]
}

# ---------------------------------------------------------------- audit (structure section)

_audit() {
    ( cd "$PROJECT_ROOT" && "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure )
}

@test "audit FAILs: owner completed while its row is not built (the T-3561 shape)" {
    _register T-3561 partial
    mkdir -p "$PROJECT_ROOT/.tasks/completed"
    printf -- '---\nid: T-3561\nname: x\nstatus: work-completed\n---\n' \
        > "$PROJECT_ROOT/.tasks/completed/T-3561-x.md"
    run _audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"[FAIL]"*"Design-conformance register: 1 row(s) without a valid owner"* ]]
    [[ "$output" == *"R6: owner T-3561 is completed but row status is 'partial'"* ]]
}

@test "audit FAILs: row with no owner_task" {
    _register null unbuilt
    run _audit
    [[ "$output" == *"[FAIL]"*"Design-conformance register"* ]]
    [[ "$output" == *"R6: no owner_task"* ]]
}

@test "audit control: re-pointed to an active owner → PASS" {
    _register T-3693 partial
    _task T-3693 started-work "" "body"
    run _audit
    [[ "$output" == *"[PASS]"*"Design-conformance register: every row has a live or finished-and-built owner"* ]]
    run grep -c "FAIL.*Design-conformance register" <<< "$output"
    [ "$output" = "0" ]
}

@test "audit WARNs on a keystone captured >3 days; PASS once started" {
    _register T-0500 unbuilt
    _task T-0500 captured "" "body"
    sed -i 's/^created: .*/created: 2026-01-01T00:00:00Z/' "$PROJECT_ROOT/.tasks/active/T-0500-fixture.md"
    run _audit
    [[ "$output" == *"[WARN]"*"Stale keystones: 1 captured >3 days"* ]]
    [[ "$output" == *"T-0500: captured"*"owns unbuilt register row R6"* ]]
    sed -i 's/^status: captured/status: started-work/' "$PROJECT_ROOT/.tasks/active/T-0500-fixture.md"
    run _audit
    [[ "$output" == *"[PASS]"*"Stale keystones: none captured >3 days"* ]]
}
