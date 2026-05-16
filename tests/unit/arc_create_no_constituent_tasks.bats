#!/usr/bin/env bats
# T-1851 (T-NEW-4): constituent_tasks: field deprecated for new arcs.
#
# `arc_create` no longer emits `constituent_tasks: []` for new arcs.
# Legacy arcs (with the field present) continue to receive arc_tag
# appends — D-Immutability preserves legacy data. Read-surfaces
# (web/blueprints/arcs.py, agents/audit/audit.sh) merge legacy
# constituent_tasks with the task-side arc_id: scan, so the two
# populations co-exist.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/lib/arc.sh" ] || skip "lib/arc.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working" "$TEST_ROOT/.tasks/active"

    cat > "$TEST_ROOT/.tasks/active/T-9999-stub.md" <<'MD'
---
id: T-9999
name: stub
tags: []
---
MD

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Helper: run a snippet against the live arc.sh sourced in a fresh subshell.
arc_sh() {
    cd "$FRAMEWORK_ROOT"
    bash -c "source lib/arc.sh; $*"
}

# --- arc_create no longer emits the deprecated field ---

@test "T-1851: arc_create omits constituent_tasks: from new arc YAML" {
    run arc_sh "arc_create newarc --name 'newarc' --anchor T-9999 --headline-mechanic 'user sees mechanic fire visibly'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/.context/arcs/newarc.yaml" ]
    run grep -c '^constituent_tasks:' "$TEST_ROOT/.context/arcs/newarc.yaml"
    [ "$output" = "0" ]
}

# --- Legacy arcs with the field still get arc_tag appends ---

@test "T-1851: arc_tag still appends to legacy arcs that have constituent_tasks:" {
    cat > "$TEST_ROOT/.context/arcs/legacy.yaml" <<'YAML'
id: arc-100
slug: legacy
name: "legacy arc"
status: in-progress
anchor_task: T-9999
constituent_tasks: []
headline_mechanic: "legacy mechanic"
demo_evidence: null
created: 2026-01-01T00:00:00Z
closed_at: null
decision: null
YAML
    run arc_sh "arc_tag legacy T-9999"
    [ "$status" -eq 0 ]
    run grep -c '^constituent_tasks: \["T-9999"\]' "$TEST_ROOT/.context/arcs/legacy.yaml"
    [ "$output" = "1" ]
}

# --- arc_tag does NOT re-create the field on new arcs ---

@test "T-1851: arc_tag does not re-create constituent_tasks: on new arcs" {
    arc_sh "arc_create freshone --name 'freshone' --anchor T-9999 --headline-mechanic 'user sees fresh mechanic fire visibly'"
    arc_sh "arc_tag freshone T-9999" || true
    run grep -c '^constituent_tasks:' "$TEST_ROOT/.context/arcs/freshone.yaml"
    [ "$output" = "0" ]
}

# --- Pre-existing committed arcs retain their data (D-Immutability) ---

@test "T-1851: existing arc YAML committed to repo retains constituent_tasks:" {
    # Sanity: at least one of the 5 in-tree arcs (arc-001..arc-005) has the
    # field, proving the migration policy is "preserve legacy, omit on new".
    found=0
    for f in "$FRAMEWORK_ROOT/.context/arcs"/*.yaml; do
        [ -f "$f" ] || continue
        if grep -q '^constituent_tasks:' "$f"; then
            found=$((found + 1))
        fi
    done
    [ "$found" -ge 1 ]
}

# --- Sanity ---

@test "T-1851: lib/arc.sh parses cleanly under bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/arc.sh"
    [ "$status" -eq 0 ]
}
