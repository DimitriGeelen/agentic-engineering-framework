#!/usr/bin/env bats
# T-1631 (B-3b of T-1626) — hook-failure threshold rule.
#
# Pins the contract that:
#   1. lib/hook-threshold.py reads .hook-counter + .hook-failure-counter
#   2. Sums duplicate keys defensively (concurrent-write race in T-1628)
#   3. Threshold env vars override defaults (FW_HOOK_THRESHOLD_*)
#   4. Healthy state (no failures) emits nothing under threshold scan
#   5. Broken state (failures > threshold AND total >= min_fires) emits FAIL
#   6. --register upserts a G-XXX into concerns.yaml
#   7. --register is idempotent — already-open entry is skipped
#   8. After human closes a concern, re-occurrence creates a new entry
#
# Origin: T-1626 immune-system loop. B-2 (T-1628) wired the telemetry,
# B-3a (T-1629) added the doctor probe, B-3b (this) closes the
# detection-to-escalation half by surfacing chronic in-production
# failures into the gaps register without depending on agent vigilance.

load ../test_helper

HELPER="$FRAMEWORK_ROOT/lib/hook-threshold.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.context/working"
    mkdir -p "$PROJECT_ROOT/.context/project"
    # Minimal concerns.yaml so register can find next G-id
    cat > "$PROJECT_ROOT/.context/project/concerns.yaml" <<EOF
concerns:
- id: G-001
  type: gap
  title: Existing concern
  status: closed
  created: 2026-01-01
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "hook-threshold.py exists and contains T-1631 marker" {
    [ -f "$HELPER" ]
    grep -q "T-1631" "$HELPER"
}

@test "hook-threshold.py has executable shebang" {
    head -1 "$HELPER" | grep -qE "^#!/usr/bin/env python3"
}

# ---- Behavioural — scan mode ----

@test "scan emits nothing under threshold when no failures recorded" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
budget-gate=50
EOF
    : > "$PROJECT_ROOT/.context/working/.hook-failure-counter"
    run python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "scan emits FAIL line when failure ratio exceeds default threshold" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=15
EOF
    run python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL|check-tier0|100|15|0.1500"* ]]
}

@test "scan respects min-fires (suppress on small samples)" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=5
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=4
EOF
    # Default min-fires=20; 5 fires shouldn't trigger even at 80% failure
    run python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "scan honours --min-fires override" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=5
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=4
EOF
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --min-fires 3 --fail-ratio 0.5
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL|check-tier0|5|4|0.8000"* ]]
}

@test "scan honours FW_HOOK_THRESHOLD_* env vars" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=10
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=2
EOF
    run env FW_HOOK_THRESHOLD_MIN_FIRES=5 FW_HOOK_THRESHOLD_FAIL_RATIO=0.15 \
        python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL|check-tier0|10|2|0.2000"* ]]
}

@test "scan sums duplicate keys defensively (concurrent-write race)" {
    # T-1628's mapfile-rewrite is not atomic across concurrent writers;
    # a single hook may legitimately appear twice in the counter file.
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=30
budget-gate=10
check-tier0=70
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=5
check-tier0=10
EOF
    run python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 1 ]
    # Sum: total=100, failures=15, ratio=0.15 — should trigger default threshold
    [[ "$output" == *"FAIL|check-tier0|100|15|0.1500"* ]]
}

@test "scan ignores malformed lines (truncated keys, garbage)" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
garbage line
=5
trunc
budget-gate=
budget-gate=20
EOF
    : > "$PROJECT_ROOT/.context/working/.hook-failure-counter"
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"check-tier0|100"* ]]
    [[ "$output" == *"budget-gate|20"* ]]
}

@test "scan --all includes hooks under threshold" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    : > "$PROJECT_ROOT/.context/working/.hook-failure-counter"
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok|check-tier0|100|0|0.0000"* ]]
}

@test "scan returns 0 when no telemetry files exist (degraded silent)" {
    run python3 "$HELPER" --project-root "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---- Behavioural — register mode ----

@test "register appends a G-XXX entry on first occurrence" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=15
EOF
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --register
    [ "$status" -eq 0 ]
    [[ "$output" == *"REGISTERED|check-tier0|G-002"* ]]
    grep -q "id: G-002" "$PROJECT_ROOT/.context/project/concerns.yaml"
    grep -q "hook:check-tier0" "$PROJECT_ROOT/.context/project/concerns.yaml"
    grep -q "hook-failure-threshold" "$PROJECT_ROOT/.context/project/concerns.yaml"
    # Verify YAML still parses
    python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.context/project/concerns.yaml'))"
}

@test "register is idempotent — open entry blocks re-registration" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=15
EOF
    # First registration
    python3 "$HELPER" --project-root "$PROJECT_ROOT" --register >/dev/null
    initial_count=$(grep -c "^- id: G-" "$PROJECT_ROOT/.context/project/concerns.yaml")
    # Second registration — should skip
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --register
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP|check-tier0|already-open"* ]]
    final_count=$(grep -c "^- id: G-" "$PROJECT_ROOT/.context/project/concerns.yaml")
    [ "$initial_count" = "$final_count" ]
}

@test "register re-fires after entry is closed (recurrence creates new entry)" {
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=15
EOF
    # First registration
    python3 "$HELPER" --project-root "$PROJECT_ROOT" --register >/dev/null
    # Manually flip status from open → closed (simulates human resolving)
    sed -i 's/^  status: open$/  status: closed/' "$PROJECT_ROOT/.context/project/concerns.yaml"
    initial_count=$(grep -c "^- id: G-" "$PROJECT_ROOT/.context/project/concerns.yaml")
    # Second registration — recurrence should create a new G-entry
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --register
    [ "$status" -eq 0 ]
    [[ "$output" == *"REGISTERED|check-tier0|G-003"* ]]
    final_count=$(grep -c "^- id: G-" "$PROJECT_ROOT/.context/project/concerns.yaml")
    [ "$final_count" -eq $((initial_count + 1)) ]
}

@test "register handles missing concerns.yaml (creates with G-001)" {
    rm -f "$PROJECT_ROOT/.context/project/concerns.yaml"
    cat > "$PROJECT_ROOT/.context/working/.hook-counter" <<EOF
check-tier0=100
EOF
    cat > "$PROJECT_ROOT/.context/working/.hook-failure-counter" <<EOF
check-tier0=15
EOF
    run python3 "$HELPER" --project-root "$PROJECT_ROOT" --register
    [ "$status" -eq 0 ]
    # First registration with no prior concerns.yaml — id should be G-001
    [[ "$output" == *"REGISTERED|check-tier0|G-001"* ]]
}
