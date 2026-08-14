#!/usr/bin/env bats
# T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit.
#
# The detectors already worked. What did not exist was a route from "a rule fired"
# to "somebody knows". `fw corpus lint` is not in audit, not on cron, not in any
# `## Verification` block — so a finding persisted for as long as nobody typed the
# command. T-2984's two findings stood ~4 weeks that way, on a map vendored into
# every consumer and referenced by an onboarding seed.
#
# The tier is the design decision, so it is the thing most carefully pinned here.
# WARN, not FAIL, diverging from the T-2980 seed-reference sibling: corpus findings
# are not homogeneous (aef-dispatch-loop's emitterless-typed-event is a real seam,
# not a defect), and an audit that exits 2 on a correct corpus trains people to stop
# reading the exit code. A future change to blanket-FAIL would otherwise be silent.
#
# Fixtures COPY tools/ into the sandbox rather than symlinking: corpus_spec derives
# its store from `Path(__file__).resolve().parent.parent`, and .resolve() follows
# symlinks straight back to the real repo — a symlinked fixture would silently scan
# the developer's actual store and pass for the wrong reason.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"
    [ -f "$FRAMEWORK_ROOT/tools/corpus_lint.py" ] || skip "corpus_lint.py not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/designer/projects" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates"
    cp -r "$FRAMEWORK_ROOT/tools" "$TEST_ROOT/tools"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export FW_AUDIT_TIMEOUT=180
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Writes a minimal, lint-clean map. $2 non-empty adds prose on <aef:description> —
# an extension child no per-node reader in this dialect looks at — which trips
# unread-node-prose (T-2976). One rule is enough; the audit code is rule-agnostic.
_make_map() {
    local id="$1" dirty="${2:-}" extra=""
    [ -n "$dirty" ] && extra='<aef:description>prose nobody reads</aef:description>'
    mkdir -p "$TEST_ROOT/.context/designer/projects/$id"
    cat > "$TEST_ROOT/.context/designer/projects/$id/v1.bpmn" <<X
<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="http://anchorpoint.framework/aef/extensions"
                  id="Definitions_$id" targetNamespace="https://aef.anchorpoint.dev/workflows">
  <bpmn:process id="Process_$id" isExecutable="true">
    <bpmn:extensionElements>
      <aef:workflowMeta id="$id" version="1" schemaVersion="2" title="fixture" tier_default="1"/>
    </bpmn:extensionElements>
    <bpmn:startEvent id="n_start" name="start">
      <bpmn:extensionElements><aef:uid value="${id}_s"/><aef:position x="100.0" y="100.0"/>$extra</bpmn:extensionElements>
      <bpmn:outgoing>f1</bpmn:outgoing>
    </bpmn:startEvent>
    <bpmn:endEvent id="n_end" name="end">
      <bpmn:extensionElements><aef:uid value="${id}_e"/><aef:position x="300.0" y="100.0"/></bpmn:extensionElements>
      <bpmn:incoming>f1</bpmn:incoming>
    </bpmn:endEvent>
    <bpmn:sequenceFlow id="f1" sourceRef="n_start" targetRef="n_end">
      <bpmn:extensionElements><aef:uid value="${id}_f1"/></bpmn:extensionElements>
    </bpmn:sequenceFlow>
  </bpmn:process>
</bpmn:definitions>
X
    printf '{"id":"%s","title":"%s","versions":[{"v":1,"note":"t","ts":1}],"latest":1,"updated":1,"uuid":"%s"}' \
        "$id" "$id" "$(printf '%s' "$id" | md5sum | cut -c1-8)-1111-4111-8111-111111111111" \
        > "$TEST_ROOT/.context/designer/projects/$id/meta.json"
}

# --- clean store ---

@test "T-2985: a lint-clean store emits a PASS line carrying the map count" {
    _make_map fixture-clean
    run "$AUDIT" --section structure
    [[ "$output" == *"All 1 corpus map(s) lint clean"* ]]
}

# --- findings surface ---

@test "T-2985: a finding surfaces as WARN naming rule, map and node" {
    _make_map fixture-dirty dirty
    run "$AUDIT" --section structure
    [[ "$output" == *"Corpus lint"* ]]
    [[ "$output" == *"unread-node-prose"* ]]
    [[ "$output" == *"fixture-dirty"* ]]
    [[ "$output" == *"n_start"* ]]
}

@test "T-2985: the WARN carries the linter's own detail, not just a rule name" {
    _make_map fixture-dirty dirty
    run "$AUDIT" --section structure
    # Without the detail the reader has to re-run the linter to learn anything,
    # which is the situation this whole check exists to end.
    [[ "$output" == *"aef:description"* ]]
}

@test "T-2985: findings are WARN tier — audit does not exit 2" {
    _make_map fixture-dirty dirty
    run "$AUDIT" --section structure
    # THE design decision (see file header). Corpus findings include real seams;
    # failing the audit on a correct corpus teaches people to ignore the exit code.
    [ "$status" -le 1 ]
}

@test "T-2985: a store with findings does NOT also claim to be clean" {
    _make_map fixture-clean
    _make_map fixture-dirty dirty
    run "$AUDIT" --section structure
    [[ "$output" == *"unread-node-prose"* ]]
    [[ "$output" != *"corpus map(s) lint clean"* ]]
}

# --- degrade silently where there is nothing to scan ---

@test "T-2985: no map store → silent, no PASS line claiming a scan" {
    rm -rf "$TEST_ROOT/.context/designer/projects"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"corpus map(s) lint clean"* ]]
    [[ "$output" != *"Corpus lint ["* ]]
}

@test "T-2985: no linter (vendored consumer without tools/) → silent, no traceback" {
    _make_map fixture-dirty dirty
    rm -rf "$TEST_ROOT/tools"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"corpus map(s) lint clean"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "T-2985: an empty store directory is not reported as a clean scan" {
    # Zero maps means the linter had nothing to judge. Saying "all 0 clean" would
    # read as coverage where there was none.
    run "$AUDIT" --section structure
    [[ "$output" != *"corpus map(s) lint clean"* ]]
}

# --- the check that guards the other checks ---

@test "T-2985: the audit sees the REAL store, not only fixtures" {
    real_store="$FRAMEWORK_ROOT/.context/designer/projects"
    [ -d "$real_store" ] || skip "no designer store in this checkout"

    # T-2980's lesson: fixture tests all stay green while the scan quietly stops
    # covering what it claims to. Run the audit against the real repo and assert it
    # reached a verdict about the real corpus — either a clean line or findings.
    set +e
    (
        export PROJECT_ROOT="$FRAMEWORK_ROOT"
        export CONTEXT_DIR="$FRAMEWORK_ROOT/.context"
        "$AUDIT" --section structure 2>&1
    ) > "$TEST_ROOT/real.out"
    real_status=$?
    set -e

    # 75 is EX_TEMPFAIL — the audit lock (T-2930/OBS-221 chose it over 0 precisely so
    # readers can tell contention from a verdict). The daily cron audit holds the real
    # repo's lock, so this collides on a live host. Honour the contract: no verdict was
    # produced, so there is nothing to judge. Asserting through it makes the test flaky
    # in exactly the way a scheduled audit guarantees.
    if [ "$real_status" -eq 75 ]; then
        skip "another audit holds the real repo's lock (EX_TEMPFAIL) — no verdict to judge"
    fi

    grep -qE "corpus map\(s\) lint clean|Corpus lint \[" "$TEST_ROOT/real.out" || {
        echo "audit exited $real_status but produced no corpus-lint verdict against the real store:"
        grep -i corpus "$TEST_ROOT/real.out" || echo "  (no corpus lines at all)"
        false
    }
}
