#!/usr/bin/env bats
# T-2545 — E2E forward bridge: BPMN compile → promote → REAL create-task.sh gate.
#
# test_bpmn_promote.py (15 unit tests) mocks create_via_gate; this integration
# test exercises the WHOLE chain against the real gate in a hermetic temp
# PROJECT_ROOT: real `fw bpmn compile --write` stages proposals → real
# `fw bpmn promote all --write` delegates to the real `fw task create` gate →
# assert real .tasks/ files with T-2543's sovereignty guarantees.
#
# It is the AEF-side counterpart to 832's joint compile→promote→create test.
#
# Guarantees pinned end-to-end (T-2542 verb, T-2543 gate-level hardening, D-320):
#   - created tasks are owner:human + captured + carry an aef_provenance block
#   - owner is FORCED human even for Agent-lane nodes (G2 — u-compile-002 proves it)
#   - each --write materialization appends a .bpmn-promote-audit.jsonl line
#   - a promote-origin `create --owner agent` is REFUSED by the gate (no file)
#   - a stale source_bpmn_sha → PROPOSE-not-clobber (materialized content intact)

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    command -v python3 >/dev/null || skip "python3 required"
    cd "$FRAMEWORK_ROOT"

    FIXTURE="tests/fixtures/bpmn/two-lane-sample.bpmn"
    [ -f "$FIXTURE" ] || skip "fixture missing: $FIXTURE"

    # Defensive hermeticity: snapshot the real focus.yaml so a path-resolution
    # leak (seen once in the T-2543 scratch e2e, root not chased) can never
    # corrupt the repo. teardown restores it unconditionally.
    REAL_FOCUS=".context/working/focus.yaml"
    FOCUS_BAK="$(mktemp)"
    cp "$REAL_FOCUS" "$FOCUS_BAK" 2>/dev/null || : > "$FOCUS_BAK"

    ROOT="$BATS_TEST_TMPDIR/e2e"
    mkdir -p "$ROOT/.tasks/active" "$ROOT/.tasks/completed" "$ROOT/.context/working"
    cp -r .tasks/templates "$ROOT/.tasks/templates"
    STAGE="$ROOT/.context/bpmn-staged"

    # Stage proposals from the fixture (real compile --write).
    FW_BPMN_STAGE_DIR="$STAGE" bin/fw bpmn compile --write "$FIXTURE" >/dev/null 2>&1
}

teardown() {
    # Restore real focus.yaml regardless of what happened inside the run.
    [ -f "$FOCUS_BAK" ] && cp "$FOCUS_BAK" "$REAL_FOCUS" 2>/dev/null || :
    rm -f "$FOCUS_BAK"
    # BATS_TEST_TMPDIR is auto-removed by bats.
}

_promote() {
    PROJECT_ROOT="$ROOT" TASKS_DIR="$ROOT/.tasks" FW_BPMN_STAGE_DIR="$STAGE" \
        bin/fw bpmn promote "$@"
}

@test "E2E: compile→promote→create materializes owner:human captured tasks with provenance" {
    run _promote all --write
    [ "$status" -eq 0 ]
    [[ "$output" == *"[created]"* ]]

    # 3 fixture nodes → 3 real task files.
    n=$(ls "$ROOT/.tasks/active/"T-*.md 2>/dev/null | wc -l)
    [ "$n" -eq 3 ]

    # Every created file is owner:human + captured + has an aef_provenance block.
    for f in "$ROOT/.tasks/active/"T-*.md; do
        grep -q "^owner: human" "$f"
        grep -q "^status: captured" "$f"
        grep -q "^aef_provenance:" "$f"
        grep -q "source_diagram:" "$f"
        grep -q "source_bpmn_sha:" "$f"
        grep -q "promoted_at:" "$f"
    done

    # G2: owner is FORCED human even for the Agent-lane node (u-compile-002 was
    # owner:agent in the manifest — the gate must have overridden it to human).
    af=$(grep -rl "uid: u-compile-002" "$ROOT/.tasks/active/")
    [ -n "$af" ]
    grep -q "^owner: human" "$af"

    # Real repo untouched: no fixture-derived task leaked into the real .tasks/.
    ! grep -rlq "uid: u-compile-002" .tasks/active/ 2>/dev/null
    # Real focus.yaml unchanged by the run.
    diff -q "$FOCUS_BAK" "$REAL_FOCUS" >/dev/null 2>&1 || [ ! -s "$FOCUS_BAK" ]
}

@test "E2E: each materialization appends an audit line" {
    run _promote all --write
    [ "$status" -eq 0 ]

    audit="$ROOT/.context/working/.bpmn-promote-audit.jsonl"
    [ -f "$audit" ]
    lines=$(wc -l < "$audit")
    [ "$lines" -eq 3 ]
    # Each line is JSON with the required keys.
    run python3 - "$audit" <<'PY'
import json, sys
req = {"uid", "task_id", "sha", "action", "source_diagram"}
with open(sys.argv[1]) as fh:
    rows = [json.loads(l) for l in fh if l.strip()]
assert len(rows) == 3, len(rows)
for r in rows:
    assert req <= set(r), (req - set(r))
    assert r["action"] == "created", r["action"]
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "E2E: gate refuses a promote-origin create with owner:agent (no task written)" {
    before=$(ls "$ROOT/.tasks/active/"T-*.md 2>/dev/null | wc -l)
    run env FW_TASK_ORIGIN=bpmn-promote PROJECT_ROOT="$ROOT" TASKS_DIR="$ROOT/.tasks" \
        bin/fw task create --name "attack" --description d --type build --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"owner:human"* ]] || [[ "$output" == *"owner: human"* ]] || [[ "$output" == *"human"* ]]
    # No new task file materialized by the refused create.
    after=$(ls "$ROOT/.tasks/active/"T-*.md 2>/dev/null | wc -l)
    [ "$after" -eq "$before" ]
    ! ls "$ROOT/.tasks/active/"*attack* >/dev/null 2>&1
}

@test "E2E: changed source_bpmn_sha → PROPOSE-not-clobber, materialized content intact" {
    _promote all --write >/dev/null 2>&1
    f=$(grep -rl "uid: u-compile-002" "$ROOT/.tasks/active/")
    [ -n "$f" ]

    # Simulate sha drift by tampering the recorded provenance sha. This is OUR
    # edit — after it, the file must not change again from the re-promote.
    sed -i 's/source_bpmn_sha: .*/source_bpmn_sha: 0000stalestale00/' "$f"
    before=$(md5sum < "$f")

    run _promote all --write
    [ "$status" -ne 0 ]        # exit 3: --write requested but a proposal is [PROPOSE]
    [[ "$output" == *"[PROPOSE]"* ]]
    [[ "$output" == *"u-compile-002"* ]]
    [[ "$output" == *"NOT clobbered"* ]]

    # Not clobbered: the materialized task is byte-identical to before the re-promote.
    after=$(md5sum < "$f")
    [ "$before" = "$after" ]
}

@test "E2E seam-slice: two-lane-joint — initiative→agent node G2-forced to owner:human, inception node materializes past T-2204 (T-2548/T-2549)" {
    # 832's canonical joint fixture (sha efb53839): owner-bearing task in BOTH lanes —
    # n_inception (subProcess, sovereignty→owner:human, wf:inception) + n_plan
    # (serviceTask, initiative→owner:agent, wf:build). Exercises the initiative→agent
    # owner derivation + the G2 gate override + inception-node materialization that the
    # single-node inception-gonogo fixture and two-lane-sample can't reach.
    JOINT="tests/fixtures/bpmn/two-lane-joint.bpmn"
    [ -f "$JOINT" ] || skip "joint fixture missing: $JOINT"
    JSTAGE="$ROOT/.context/bpmn-staged-joint"
    FW_BPMN_STAGE_DIR="$JSTAGE" bin/fw bpmn compile --write "$JOINT" >/dev/null 2>&1

    # Compiler owner-derivation from lane authority, BEFORE the gate (staged manifest):
    man="$JSTAGE/two-lane-joint/manifest.yaml"
    [ -f "$man" ]
    grep -A4 'n_inception:' "$man" | grep -q "owner: human"   # sovereignty → human
    grep -A4 'n_plan:'       "$man" | grep -q "owner: agent"   # initiative  → agent

    # Promote through the REAL gate.
    run env PROJECT_ROOT="$ROOT" TASKS_DIR="$ROOT/.tasks" FW_BPMN_STAGE_DIR="$JSTAGE" \
        bin/fw bpmn promote all --write
    [ "$status" -eq 0 ]
    [[ "$output" == *"[created]"* ]]

    # 2 owner-bearing nodes → 2 real task files (inception node NOT refused — T-2549).
    n=$(ls "$ROOT/.tasks/active/"T-*.md 2>/dev/null | wc -l)
    [ "$n" -eq 2 ]

    # Both materialize owner:human + captured + provenance.
    for f in "$ROOT/.tasks/active/"T-*.md; do
        grep -q "^owner: human" "$f"
        grep -q "^status: captured" "$f"
        grep -q "^aef_provenance:" "$f"
    done

    # Load-bearing #1 — initiative→agent leg: n_plan was owner:agent in the manifest;
    # the T-2543 G2 gate forces it to owner:human at materialization.
    pf=$(grep -rl "uid: n_plan" "$ROOT/.tasks/active/")
    [ -n "$pf" ]
    grep -q "^owner: human" "$pf"
    grep -q "^workflow_type: build" "$pf"

    # Load-bearing #2 — inception node materializes past the T-2204 gate (T-2549):
    # a DEFER recommendation is injected at creation so the gate does not refuse it.
    inf=$(grep -rl "uid: n_inception" "$ROOT/.tasks/active/")
    [ -n "$inf" ]
    grep -q "^workflow_type: inception" "$inf"
    grep -q "^owner: human" "$inf"
    grep -q "Recommendation:.*DEFER" "$inf"

    # Real repo untouched.
    ! grep -rlq "uid: n_plan" .tasks/active/ 2>/dev/null
    ! grep -rlq "uid: n_inception" .tasks/active/ 2>/dev/null
}
