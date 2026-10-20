#!/usr/bin/env bats
# T-3160 — Regression: 'fw cron install --dry-run' ran the writing generator
# as its diff step, rewriting the git-tracked .context/cron/agentic-audit.crontab
# and then printing "(dry-run — no changes made)" (G-087 / 001-CashWeb field
# report: a 3875-byte source with ten live jobs truncated to 450 bytes).
#
# Pins:
#   1. --dry-run leaves the source byte- and mtime-identical, and prints the diff
#   2. --dry-run against a deployed target still prints a unified diff of the
#      registry-derived text, and touches neither source nor target
#   3. --dry-run leaves no scratch file behind
#   4. without --dry-run, install still generates, writes and installs

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-t3160"
    TEST_CRON_DIR="$TEST_TEMP_DIR/etc-cron-d"
    mkdir -p "$TEST_PROJECT/.context/cron" "$TEST_CRON_DIR" "$TEST_TEMP_DIR/scratch"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    cat > "$TEST_PROJECT/.context/cron-registry.yaml" << 'EOF'
jobs:
  - id: probe
    name: Probe job
    schedule: "*/5 * * * *"
    command: "echo t3160-probe"
    status: active
EOF
    SRC="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
    printf '# legacy hand-written source\n*/1 * * * * root echo keep-me\n' > "$SRC"
    touch -d '2020-01-01 00:00:00' "$SRC"
    export PROJECT_ROOT="$TEST_PROJECT"
    export FW_CRON_INSTALL_DIR="$TEST_CRON_DIR"
    export TMPDIR="$TEST_TEMP_DIR/scratch"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_fingerprint() { echo "$(md5sum "$1" | cut -d' ' -f1) $(stat -c %Y "$1")"; }

@test "T-3160: install --dry-run does not write the crontab source" {
    before=$(_fingerprint "$SRC")
    run "$FRAMEWORK_ROOT/bin/fw" cron install --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"no changes made"* ]]
    [[ "$output" == *"echo t3160-probe"* ]]
    [ "$(_fingerprint "$SRC")" = "$before" ]
    grep -q keep-me "$SRC"
    [ ! -e "$TEST_CRON_DIR/agentic-audit-proj-t3160" ]
}

@test "T-3160: install --dry-run diffs registry text against the deployed target" {
    target="$TEST_CRON_DIR/agentic-audit-proj-t3160"
    printf '# Agentic Engineering Framework — Scheduled Jobs (managed by cron-registry.yaml)\n*/9 * * * * root echo old-job\n' > "$target"
    src_before=$(_fingerprint "$SRC")
    tgt_before=$(_fingerprint "$target")
    run "$FRAMEWORK_ROOT/bin/fw" cron install --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"-*/9 * * * * root echo old-job"* ]]
    [[ "$output" == *"+*/5 * * * * root"*"echo t3160-probe"* ]]
    [ "$(_fingerprint "$SRC")" = "$src_before" ]
    [ "$(_fingerprint "$target")" = "$tgt_before" ]
}

@test "T-3160: install --dry-run leaves no scratch file behind" {
    run "$FRAMEWORK_ROOT/bin/fw" cron install --dry-run
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "T-3160: install without --dry-run still writes source and installs" {
    run "$FRAMEWORK_ROOT/bin/fw" cron install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: $TEST_CRON_DIR/agentic-audit-proj-t3160"* ]]
    grep -q "echo t3160-probe" "$SRC"
    ! grep -q keep-me "$SRC" || false
    cmp "$SRC" "$TEST_CRON_DIR/agentic-audit-proj-t3160"
    run "$FRAMEWORK_ROOT/bin/fw" cron install
    [[ "$output" == *"Cron in sync"* ]]
}
