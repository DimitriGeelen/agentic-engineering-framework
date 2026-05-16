#!/usr/bin/env bats
# T-1856 (T-NEW-8): anchor_task existence audit check.
#
# When an arc YAML declares anchor_task: T-XXX and that task does not exist
# in .tasks/{active,completed}/, audit emits a WARN — never FAIL.
# Symmetric to T-1849's arc_id validation (which guards task→arc); this
# guards arc→task. Matches T-1846 §4 D4 (warn not block).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" "$TEST_ROOT/.context/audits"

    # Minimal fixtures for the structure section's other prerequisites.
    mkdir -p "$TEST_ROOT/.tasks/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export FW_AUDIT_TIMEOUT=120
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# --- happy path: anchor resolves ---

@test "T-1856: arc with valid anchor_task → pass line emitted" {
    cat > "$TEST_ROOT/.context/arcs/test-arc.yaml" <<'YAML'
id: test-arc
slug: test-arc
name: "test arc"
status: in-progress
anchor_task: T-1234
constituent_tasks: []
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1234-stub.md" <<'MD'
---
id: T-1234
name: stub
---
MD
    run "$AUDIT" --section structure
    [[ "$output" == *"anchor_task references"* ]] || [[ "$output" == *"arc anchor_task"* ]]
}

# --- failure path: anchor missing ---

@test "T-1856: arc with nonexistent anchor_task → WARN emitted (audit exit ≤1)" {
    cat > "$TEST_ROOT/.context/arcs/orphan.yaml" <<'YAML'
id: orphan
slug: orphan
name: "orphan arc"
status: in-progress
anchor_task: T-99999
constituent_tasks: []
YAML
    run "$AUDIT" --section structure
    # WARN-only, never FAIL. Audit exit code unaffected — 0 or 1, NEVER 2.
    [ "$status" -le 1 ]
    [[ "$output" == *"T-99999"* ]]
    [[ "$output" == *"anchor_task"* ]]
}

# --- silent for arcs without anchor ---

@test "T-1856: arc without anchor_task → no warning, no pass line" {
    cat > "$TEST_ROOT/.context/arcs/noanchor.yaml" <<'YAML'
id: noanchor
slug: noanchor
name: "no anchor"
status: in-progress
constituent_tasks: []
YAML
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    # No warning about anchor_task for THIS arc — but since 0 arcs had
    # anchor_task to check, the pass line for the anchor check is also
    # absent (we only emit it when at least one was checked).
    [[ "$output" != *"noanchor"*"anchor_task"* ]]
}

# --- null anchor passes silently ---

@test "T-1856: arc with anchor_task: null → silent, treated as unset" {
    cat > "$TEST_ROOT/.context/arcs/nullanchor.yaml" <<'YAML'
id: nullanchor
slug: nullanchor
name: "null anchor"
status: in-progress
anchor_task: null
constituent_tasks: []
YAML
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"nullanchor"*"anchor_task"* ]]
}

# --- mix: one valid + one orphan → exactly one warn ---

@test "T-1856: mix of valid + orphan → only the orphan warns" {
    cat > "$TEST_ROOT/.context/arcs/good.yaml" <<'YAML'
id: good
slug: good
status: in-progress
anchor_task: T-2222
YAML
    cat > "$TEST_ROOT/.tasks/active/T-2222-stub.md" <<'MD'
---
id: T-2222
---
MD
    cat > "$TEST_ROOT/.context/arcs/bad.yaml" <<'YAML'
id: bad
slug: bad
status: in-progress
anchor_task: T-99999
YAML
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"T-99999"* ]]
    [[ "$output" != *"T-2222"*"not found"* ]]
}
