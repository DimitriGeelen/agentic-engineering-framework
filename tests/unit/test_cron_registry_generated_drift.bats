#!/usr/bin/env bats
# T-1942 — Pin fw doctor registry → generated drift detection.
# Origin: T-1935/T-1941 — bvp-cost-estimator-sweep entry was added to
# cron-registry.yaml but `fw cron generate` was never run; doctor's existing
# check covers generated → deployed (both stale, matched), so it reported
# "Cron registry in sync" for 3+ days while the new entry was invisible to
# the OS scheduler.
#
# This test pins the registry → generated leg: when cron-registry.yaml is
# ahead of .context/cron/agentic-audit.crontab, doctor must emit a WARN
# pointing at `fw cron generate`. When in sync, the existing OK line stays.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-cron-gen-drift"
    TEST_CRON_DIR="$TEST_TEMP_DIR/etc-cron-d"
    mkdir -p "$TEST_PROJECT/.context/cron" \
             "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_CRON_DIR"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    export FW_CRON_INSTALL_DIR="$TEST_CRON_DIR"
    PROJECT_SLUG="$(basename "$TEST_PROJECT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')"
    DEPLOYED_PATH="$TEST_CRON_DIR/agentic-audit-${PROJECT_SLUG}"
    SOURCE_PATH="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
    REGISTRY_PATH="$TEST_PROJECT/.context/cron-registry.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_one_job_registry() {
    cat > "$REGISTRY_PATH" <<'EOF'
jobs:
  - id: t1942-one
    name: "one job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-1942
    status: active
    description: "first job"
EOF
}

_two_job_registry() {
    cat > "$REGISTRY_PATH" <<'EOF'
jobs:
  - id: t1942-one
    name: "one job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-1942
    status: active
    description: "first job"
  - id: t1942-two
    name: "two job"
    schedule: "15 * * * *"
    command: "fw bvp estimator sweep"
    source_file: agentic-audit.crontab
    origin_task: T-1942
    status: active
    description: "second job — added but not regenerated (T-1935 class)"
EOF
}

@test "T-1942: registry ahead of generated → WARN 'edited but not generated'" {
    # Setup: registry has TWO jobs, generated file only has ONE (the stale
    # state — this is the T-1935 class). Deployed matches generated, so the
    # existing generated→deployed check stays green and silently hides drift.
    _one_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"
    # Now bump the registry but DON'T regenerate.
    _two_job_registry

    run "$FRAMEWORK_ROOT/bin/fw" doctor
    [ "$status" -ne 2 ]  # doctor exits non-zero on FAILs; WARN-only stays exit 0 or 1
    echo "$output" | grep -q "Cron registry edited but not generated"
}

@test "T-1942: clean state (registry == generated == deployed) → OK, no drift WARN" {
    _two_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"

    run "$FRAMEWORK_ROOT/bin/fw" doctor
    echo "$output" | grep -q "Cron registry in sync"
    ! echo "$output" | grep -q "Cron registry edited but not generated"
}

@test "T-1942: registry modified-in-place (same job count, different schedule) → WARN" {
    # Content-comparison, not job-count: bumping just the schedule of an
    # existing entry must also trip the gate.
    _one_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"
    # Edit the registry job's schedule in place.
    sed -i 's|schedule: "0 0 \* \* \*"|schedule: "30 2 * * *"|' "$REGISTRY_PATH"

    run "$FRAMEWORK_ROOT/bin/fw" doctor
    echo "$output" | grep -q "Cron registry edited but not generated"
}
