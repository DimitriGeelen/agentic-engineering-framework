#!/usr/bin/env bats
# T-1769 — Pin the shape of `fw cron generate` output. Origin: T-1720 found
# that the generator silently produced unrunnable lines (no cwd for `python3
# -m lib.X` invocations; stderr swallowed by `2>/dev/null`). Reviewer audit
# was effectively dead for 9 days. Generator shape is now load-bearing —
# this fixture pins it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-cron-shape"
    mkdir -p "$TEST_PROJECT/.context/cron" \
             "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_registry() {
    cat > "$TEST_PROJECT/.context/cron-registry.yaml"
}

_generated_lines() {
    grep -E '^[*0-9]' "$TEST_PROJECT/.context/cron/agentic-audit.crontab"
}

@test "T-1720: fw command gets cd + PROJECT_ROOT + logger redirect" {
    _write_registry <<'EOF'
jobs:
  - id: fw-test
    name: "FW test"
    schedule: "37 4 * * *"
    command: "fw reviewer audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    line="$(_generated_lines | head -1)"
    [[ "$line" == *"cd \"$TEST_PROJECT\" &&"* ]]
    [[ "$line" == *"PROJECT_ROOT=\"$TEST_PROJECT\""* ]]
    [[ "$line" == *"2>&1 | logger -t agentic-cron"* ]]
    [[ "$line" != *"2>/dev/null"* ]]
}

@test "T-1720: non-fw python3 command gets cd + logger but no PROJECT_ROOT prefix" {
    _write_registry <<'EOF'
jobs:
  - id: py-test
    name: "Python test"
    schedule: "33 5 * * *"
    command: "python3 tools/escalation-scan-v0.5.py --window-days 30"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    line="$(_generated_lines | head -1)"
    [[ "$line" == *"cd \"$TEST_PROJECT\" && python3 tools/escalation-scan-v0.5.py"* ]]
    [[ "$line" == *"2>&1 | logger -t agentic-cron"* ]]
    [[ "$line" != *"PROJECT_ROOT=\"$TEST_PROJECT\""* ]]
}

@test "T-1720: 2>/dev/null in registry gets rewritten to logger" {
    _write_registry <<'EOF'
jobs:
  - id: silenced
    name: "Silenced"
    schedule: "* * * * *"
    command: "fw mirror sync --quiet 2>/dev/null"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    line="$(_generated_lines | head -1)"
    [[ "$line" != *"2>/dev/null"* ]]
    [[ "$line" == *"2>&1 | logger -t agentic-cron"* ]]
}

@test "logger redirect in registry is preserved (idempotent)" {
    _write_registry <<'EOF'
jobs:
  - id: pre-logged
    name: "Pre-logged"
    schedule: "* * * * *"
    command: "/some/script.sh 2>&1 | logger -t custom-tag"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    line="$(_generated_lines | head -1)"
    [[ "$line" == *"2>&1 | logger -t custom-tag"* ]]
    [ "$(echo "$line" | grep -c "logger -t")" -eq 1 ]
}

@test "registry leading-cd produces double-cd (documents current behavior; T-1687 cleanup is the canonical fix)" {
    _write_registry <<'EOF'
jobs:
  - id: legacy-cd
    name: "Legacy with leading cd"
    schedule: "0 0 * * *"
    command: "cd /opt/some/dir && python3 script.py"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    line="$(_generated_lines | head -1)"
    [[ "$line" == *"cd \"$TEST_PROJECT\" &&"* ]]
    [[ "$line" == *"cd /opt/some/dir &&"* ]]
}

@test "paused job emitted as comment, not active line" {
    _write_registry <<'EOF'
jobs:
  - id: paused-job
    name: "Paused"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: paused
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    active="$(_generated_lines || true)"
    [ -z "$active" ]
    grep -q "^# PAUSED:" "$TEST_PROJECT/.context/cron/agentic-audit.crontab"
}
