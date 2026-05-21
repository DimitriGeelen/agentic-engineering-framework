#!/usr/bin/env bats
# T-1976 — fw arc remove-driver <slug> "<name>" --rationale "<≥30 chars>" CLI verb.
#
# Pins the contract (symmetric with fw bvp driver --remove):
#   - Resolves slug OR arc-NNN form via _arc_normalize_input.
#   - Requires --rationale ≥30 chars (R6).
#   - Refuses on unknown driver names (no silent no-op).
#   - §ACD refusal under $CLAUDECODE=1 unless --i-am-human / --from-watchtower.
#   - On success: removes from scoped_drivers:, appends row to
#     .context/audits/arc-scoped-driver-removals.jsonl, exit 0.
#   - arc_dispatch routes 'remove-driver' to arc_remove_driver.
#   - arc_help lists it under verbs.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/audits"

    # Arc with 2 approved scoped drivers — one is the happy-path target,
    # one stays so we can confirm only the named one is removed.
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

    # Default to non-agent session — ACD gate is open unless we explicitly set
    # CLAUDECODE=1 in a specific test.
    unset CLAUDECODE
}

# --- Happy path ---

@test "T-1976: arc_remove_driver removes a named driver and exits 0" {
    run arc_remove_driver "sample-arc" "alpha-driver" --rationale "removing alpha because it duplicates D1 antifragility"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: removed scoped driver 'alpha-driver'"* ]]
    # alpha removed, beta retained
    run grep -c "name: alpha-driver" "$ARCS_DIR/sample-arc.yaml"
    [ "$output" -eq 0 ]
    run grep -c "name: beta-driver" "$ARCS_DIR/sample-arc.yaml"
    [ "$output" -eq 1 ]
}

@test "T-1976: arc_remove_driver accepts arc-NNN form (normalisation path)" {
    run arc_remove_driver "arc-191" "alpha-driver" --rationale "removing alpha via arc-NNN form normalisation test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-driver"* ]]
}

@test "T-1976: arc_remove_driver writes audit row to arc-scoped-driver-removals.jsonl" {
    run arc_remove_driver "sample-arc" "alpha-driver" --rationale "removing alpha — its signal is already covered by D2 reliability"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.context/audits/arc-scoped-driver-removals.jsonl" ]
    run cat "$PROJECT_ROOT/.context/audits/arc-scoped-driver-removals.jsonl"
    [[ "$output" == *"\"driver\":\"alpha-driver\""* ]]
    [[ "$output" == *"\"arc_id\":\"sample-arc\""* ]]
}

# --- Refusal paths ---

@test "T-1976: arc_remove_driver refuses unknown driver name (no silent no-op)" {
    run arc_remove_driver "sample-arc" "ghost-driver" --rationale "trying to remove a driver that does not exist for test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
    # File untouched
    run grep -c "name: alpha-driver" "$ARCS_DIR/sample-arc.yaml"
    [ "$output" -eq 1 ]
    run grep -c "name: beta-driver" "$ARCS_DIR/sample-arc.yaml"
    [ "$output" -eq 1 ]
}

@test "T-1976: arc_remove_driver refuses missing --rationale" {
    run arc_remove_driver "sample-arc" "alpha-driver"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--rationale"* ]]
}

@test "T-1976: arc_remove_driver refuses --rationale shorter than 30 chars" {
    run arc_remove_driver "sample-arc" "alpha-driver" --rationale "too short"
    [ "$status" -ne 0 ]
    [[ "$output" == *"≥30 characters"* ]]
}

@test "T-1976: arc_remove_driver refuses unknown arc id" {
    run arc_remove_driver "no-such-arc" "alpha-driver" --rationale "removing alpha from a non-existent arc for refusal test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "T-1976: arc_remove_driver with no arguments prints usage and exits non-zero" {
    run arc_remove_driver
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "T-1976: arc_remove_driver refuses under \$CLAUDECODE=1 without exemption" {
    export CLAUDECODE=1
    run arc_remove_driver "sample-arc" "alpha-driver" --rationale "agent attempting remove without --from-watchtower exemption"
    [ "$status" -ne 0 ]
    [[ "$output" == *"§ACD"* ]] || [[ "$output" == *"M6"* ]]
    # File untouched
    run grep -c "name: alpha-driver" "$ARCS_DIR/sample-arc.yaml"
    [ "$output" -eq 1 ]
}

@test "T-1976: arc_remove_driver accepts --from-watchtower exemption under \$CLAUDECODE=1" {
    export CLAUDECODE=1
    run arc_remove_driver "sample-arc" "alpha-driver" --rationale "watchtower-flow removal of alpha — sufficient context here" --from-watchtower
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-driver"* ]]
}

# --- Dispatch wiring ---

@test "T-1976: arc_dispatch routes 'remove-driver' to arc_remove_driver" {
    run arc_dispatch remove-driver "sample-arc" "alpha-driver" --rationale "dispatch-wired removal — exercising the routing path here"
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-driver"* ]]
}

@test "T-1976: arc_help lists 'remove-driver <id>' under verbs" {
    run arc_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"remove-driver"* ]]
    [[ "$output" == *"T-1976"* ]]
}

# ── T-1976 latent-bug regression: arc_approve_driver --rationale acceptance ──
#
# Pre-existing gap surfaced during T-1976 round-trip: the Watchtower forms
# (both /approve-driver from Proposed and /add-driver from custom) pass
# `--rationale R` but the CLI argparse rejected it with "Unexpected arg:
# --rationale". This pinned the contract: the verb accepts --rationale and
# persists it on the scoped_drivers entry.

setup_approve_fixture() {
    cat > "$ARCS_DIR/approve-fixture.yaml" <<'YAML'
id: arc-291
slug: approve-fixture
name: "Approve fixture"
description: test fixture
status: in-progress
anchor_task: T-9992
created: 2026-01-01T00:00:00Z
constituent_tasks: []
scoped_drivers: []
proposed_scoped_drivers: []
YAML
}

@test "T-1976: arc_approve_driver accepts --rationale flag (was 'Unexpected arg')" {
    setup_approve_fixture
    run arc_approve_driver "approve-fixture" "rationale-driver" --weight 3 --rationale "rationale should be accepted and persisted on the entry per R6 friction"
    [ "$status" -eq 0 ]
    [[ "$output" == *"rationale-driver"* ]]
    # Persisted: rationale field on the scoped_drivers entry
    run grep -c "rationale:" "$ARCS_DIR/approve-fixture.yaml"
    [ "$output" -ge 1 ]
}

@test "T-1976: arc_approve_driver persists rationale text verbatim" {
    setup_approve_fixture
    run arc_approve_driver "approve-fixture" "alpha" --weight 4 --rationale "this rationale string should round-trip into the yaml verbatim"
    [ "$status" -eq 0 ]
    run grep -F "this rationale string should round-trip into the yaml verbatim" "$ARCS_DIR/approve-fixture.yaml"
    [ "$status" -eq 0 ]
}

@test "T-1976: arc_approve_driver without --rationale still works (back-compat)" {
    setup_approve_fixture
    run arc_approve_driver "approve-fixture" "no-rationale-driver" --weight 3
    [ "$status" -eq 0 ]
    [[ "$output" == *"no-rationale-driver"* ]]
}
