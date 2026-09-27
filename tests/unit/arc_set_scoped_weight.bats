#!/usr/bin/env bats
# T-1977 — fw arc set-scoped-weight <slug> "<name>" --weight N --rationale "<≥30 chars>" CLI verb.
#
# Pins the contract (mirrors T-1929 /bvp weight sliders at arc scope):
#   - Requires --weight (1-6, M2 cap) and --rationale (≥30 chars, R6).
#   - Refuses on unknown driver names (no silent no-op).
#   - §ACD refusal under $CLAUDECODE=1 unless --i-am-human / --from-watchtower.
#   - On success: mutates scoped_drivers[].weight in place, appends audit row
#     to .context/audits/arc-scoped-weight-changes.jsonl, exit 0.
#   - arc_dispatch routes 'set-scoped-weight' to arc_set_scoped_weight.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/audits"

    cat > "$ARCS_DIR/sample-arc.yaml" <<'YAML'
id: arc-191
slug: sample-arc
name: "Sample arc"
description: test fixture
status: in-progress
anchor_task: T-9991
created: 2026-01-01T00:00:00Z
constituent_tasks: []
scoped_drivers:
    - name: alpha-driver
      weight: 4
      approved_at: 2026-02-01T00:00:00Z
    - name: beta-driver
      weight: 3
      approved_at: 2026-02-02T00:00:00Z
proposed_scoped_drivers: []
YAML

    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/arc.sh"

    unset CLAUDECODE
}

# --- Happy path ---

@test "T-1977: arc_set_scoped_weight mutates the named driver weight and exits 0" {
    # --from-watchtower added by T-3523: this test pins MUTATION MECHANICS, not policy.
    # D-661 leg 2 made the unflagged path reviewer-gated (mirroring T-3429/D-586 on
    # approve-driver), and this fixture's driver carries no scoring spec, so an
    # unflagged call now fails review for a reason unrelated to what this test checks.
    run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 6 --rationale "tighten estimator-fidelity weight to reflect new arc priorities" --from-watchtower
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 → 6"* ]]
    # alpha now 6, beta unchanged
    run python3 -c "import yaml; d=yaml.safe_load(open('$ARCS_DIR/sample-arc.yaml')); print(next(x['weight'] for x in d['scoped_drivers'] if x['name']=='alpha-driver'))"
    [ "$output" = "6" ]
    run python3 -c "import yaml; d=yaml.safe_load(open('$ARCS_DIR/sample-arc.yaml')); print(next(x['weight'] for x in d['scoped_drivers'] if x['name']=='beta-driver'))"
    [ "$output" = "3" ]
}

@test "T-1977: arc_set_scoped_weight writes audit row to arc-scoped-weight-changes.jsonl" {
    # --from-watchtower per T-3523, same reason as the mutation test above.
    run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 5 --rationale "evidence from recent incident motivates raising this weight" --from-watchtower
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.context/audits/arc-scoped-weight-changes.jsonl" ]
    run cat "$PROJECT_ROOT/.context/audits/arc-scoped-weight-changes.jsonl"
    [[ "$output" == *"\"driver\":\"alpha-driver\""* ]]
    [[ "$output" == *"\"old_weight\":4"* ]]
    [[ "$output" == *"\"new_weight\":5"* ]]
    [[ "$output" == *"\"arc_id\":\"sample-arc\""* ]]
}

# --- Refusal paths ---

@test "T-1977: arc_set_scoped_weight refuses unknown driver name (no silent no-op)" {
    run arc_set_scoped_weight "sample-arc" "ghost-driver" --weight 4 --rationale "trying to set weight on a driver that does not exist for test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "T-1977: arc_set_scoped_weight refuses weight out of range (>6)" {
    run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 7 --rationale "trying to set a weight that exceeds the M2 cap of six"
    [ "$status" -ne 0 ]
    [[ "$output" == *"out of range"* ]]
}

@test "T-1977: arc_set_scoped_weight refuses weight out of range (<1)" {
    run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 0 --rationale "trying to set a weight that falls below the minimum of one"
    [ "$status" -ne 0 ]
    [[ "$output" == *"out of range"* ]]
}

@test "T-1977: arc_set_scoped_weight refuses rationale shorter than 30 chars (R6)" {
    run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 5 --rationale "too short"
    [ "$status" -ne 0 ]
    [[ "$output" == *"≥30"* ]]
}

@test "T-3523: an agent is REVIEWER-gated on set-scoped-weight, not §ACD-refused" {
    # POLICY CHANGED, and this test changed with it rather than being deleted.
    # It used to assert "refuses under $CLAUDECODE=1 without override (§ACD)".
    # Operator ruling 2026-09-27 (D-661 leg 2, answering OBS-558): "ARC drivers also
    # don't need human approval anymore, they can just be agent approved", and when
    # asked whether that reaches the WEIGHT or stops at adding a driver, the operator
    # ruled it reaches the weight — a driver whose weight nobody can tune is inert.
    #
    # So the §ACD refusal became the override path, mirroring what T-3429/D-586 did
    # for approve-driver. An unflagged agent call now runs the static reviewer. This
    # fixture's driver carries no scoring spec, so the reviewer fails it on check (a)
    # — which is the point: the agent is JUDGED, not refused for being an agent.
    CLAUDECODE=1 run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 5 --rationale "agent call now reaches the reviewer instead of the identity gate"
    [ "$status" -ne 0 ]
    # The refusal must come from the REVIEWER, not from the identity gate.
    [[ "$output" == *"did not pass review"* ]]
    [[ "$output" != *"agents must not invoke"* ]]
}

@test "T-1977: arc_set_scoped_weight accepts --from-watchtower under \$CLAUDECODE=1" {
    CLAUDECODE=1 run arc_set_scoped_weight "sample-arc" "alpha-driver" --weight 5 --rationale "watchtower-routed commit should pass through the ACD gate" --from-watchtower
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 → 5"* ]]
}

@test "T-1977: arc_dispatch routes 'set-scoped-weight' to arc_set_scoped_weight" {
    # Routing pin only. Runs with --from-watchtower so it exercises the DISPATCH
    # table rather than the reviewer gate T-3523 added on the unflagged agent path;
    # without it this test would fail for a reason that has nothing to do with
    # routing, which is what it went red for when the gate landed.
    run arc_dispatch set-scoped-weight "sample-arc" "alpha-driver" --weight 6 --rationale "dispatcher routing pin keeps the verb table aligned with help" --from-watchtower
    [ "$status" -eq 0 ]
}

@test "T-1977: arc_help lists set-scoped-weight under verbs" {
    run arc_help
    [[ "$output" == *"set-scoped-weight"* ]]
}
