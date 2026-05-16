#!/usr/bin/env bats
# T-1848 sequel — verb-side normalisation coverage.
#
# Verifies that arc verbs (focus, show, tag, close) accept BOTH the slug form
# (`dispatch-safety`) and the canonical arc-NNN form (`arc-001`) introduced by
# T-1848's D-Immutability axiom. Substrate shipped 2026-05-16 (commit cee2a90d)
# but verb-side normalisation was deferred to a sequel — this is that sequel.
#
# Pattern: scaffold a throwaway ARCS_DIR under BATS_TEST_TMPDIR, source the
# library, run each verb with both forms, assert success + correct routing.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"

    # Two arcs: one slug-only (legacy form), one with arc-NNN id (T-1848 form).
    cat > "$ARCS_DIR/dispatch-safety.yaml" <<'YAML'
id: arc-001
slug: dispatch-safety
name: "Dispatch safety"
description: test fixture
status: in-progress
created: 2026-01-01T00:00:00Z
constituent_tasks: []
YAML

    cat > "$ARCS_DIR/legacy-arc.yaml" <<'YAML'
id: legacy-arc
slug: legacy-arc
name: "Legacy arc (pre-migration form)"
description: test fixture
status: in-progress
created: 2026-01-01T00:00:00Z
constituent_tasks: []
YAML

    # Stub task file so arc_tag has a target.
    cat > "$PROJECT_ROOT/.tasks/active/T-9999-stub.md" <<'MD'
---
id: T-9999
name: "stub for arc_tag tests"
status: started-work
tags: []
---
# stub
MD

    # Source arc.sh in a subshell-friendly way (it expects PROJECT_ROOT + ARCS_DIR set).
    # Note: arc.sh doesn't pollute when sourced; functions become callable.
    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/arc.sh"
}

# --- _arc_normalize_input (helper sanity) ---

@test "T-1848: _arc_normalize_input passes slug through unchanged" {
    run _arc_normalize_input "dispatch-safety"
    [ "$status" -eq 0 ]
    [ "$output" = "dispatch-safety" ]
}

@test "T-1848: _arc_normalize_input resolves arc-NNN to slug" {
    run _arc_normalize_input "arc-001"
    [ "$status" -eq 0 ]
    [ "$output" = "dispatch-safety" ]
}

@test "T-1848: _arc_normalize_input passes unknown input through unchanged" {
    run _arc_normalize_input "no-such-arc"
    [ "$status" -eq 0 ]
    [ "$output" = "no-such-arc" ]
}

# --- arc_focus ---

@test "T-1848: arc_focus accepts arc-NNN form" {
    run arc_focus "arc-001"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dispatch-safety"* ]]
    # focus file should contain the normalized slug, not arc-001
    run grep -q "current_arc: dispatch-safety" "$ARC_FOCUS_FILE"
    [ "$status" -eq 0 ]
}

@test "T-1848: arc_focus accepts slug form (backward compat)" {
    run arc_focus "dispatch-safety"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dispatch-safety"* ]]
}

@test "T-1848: arc_focus unknown arc errors cleanly" {
    run arc_focus "no-such-arc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# --- arc_show ---

@test "T-1848: arc_show accepts arc-NNN form" {
    run arc_show "arc-001"
    [ "$status" -eq 0 ]
    [[ "$output" == *"slug: dispatch-safety"* ]]
}

@test "T-1848: arc_show accepts slug form" {
    run arc_show "dispatch-safety"
    [ "$status" -eq 0 ]
    [[ "$output" == *"slug: dispatch-safety"* ]]
}

# --- arc_tag ---

@test "T-1848: arc_tag accepts arc-NNN form, writes slug-based tag" {
    # update-task.sh isn't sourced here; arc_tag falls through to inline python.
    run arc_tag "arc-001" "T-9999"
    [ "$status" -eq 0 ]
    # Task file should have arc:dispatch-safety tag (slug form), not arc:arc-001
    run grep -q "arc:dispatch-safety" "$PROJECT_ROOT/.tasks/active/T-9999-stub.md"
    [ "$status" -eq 0 ]
}

# --- arc_close (under non-CLAUDECODE mode for test purposes) ---

@test "T-1848: arc_close accepts arc-NNN form (with --i-am-human bypass)" {
    # The default-to-OPEN gate refuses under CLAUDECODE=1 unless --i-am-human / --from-watchtower.
    # We pass --i-am-human to exercise the actual close path.
    # Use --demo none + --justification to skip demo gate.
    unset CLAUDECODE
    run arc_close "arc-001" --decision "test close via arc-001" --demo none --justification "bats test" --i-am-human
    # Close may exit 0 (success) or 1 (downstream gate) — what we care about is
    # that the "arc not found" path didn't fire, which would emit status=1
    # with that specific message. Slug normalisation success is the absence of
    # the "arc 'arc-001' not found" error.
    [[ "$output" != *"arc 'arc-001' not found"* ]]
}

# --- bash -n sanity (catch syntax regressions) ---

@test "T-1848: lib/arc.sh parses cleanly" {
    run bash -n "$FRAMEWORK_ROOT/lib/arc.sh"
    [ "$status" -eq 0 ]
}
