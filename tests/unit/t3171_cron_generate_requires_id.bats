#!/usr/bin/env bats
# T-3171 — fw cron generate must refuse a registry containing a job with a
# missing/empty/duplicate id, before this reaches fw cron list / fw cron run
# / Watchtower pause-resume, which all require job['id'] hard (KeyError/404
# otherwise). Origin: 001-CashWeb built a candidate registry from a running
# crontab, which carries no job ids — generate/install silently accepted it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-cron-ids"
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

@test "T-3171: generate refuses a job with no id: at all, writes nothing" {
    _write_registry <<'EOF'
jobs:
  - name: "Reindex from running crontab"
    schedule: "*/15 * * * *"
    command: "fw fabric reindex"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing/empty id"* ]]
    [[ "$output" == *"Reindex from running crontab"* ]]
    [ ! -f "$TEST_PROJECT/.context/cron/agentic-audit.crontab" ]
}

@test "T-3171: generate refuses an empty-string id" {
    _write_registry <<'EOF'
jobs:
  - id: ""
    name: "Empty id job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing/empty id"* ]]
}

@test "T-3171: generate refuses two jobs sharing an id" {
    _write_registry <<'EOF'
jobs:
  - id: dup-id
    name: "First"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
  - id: dup-id
    name: "Second"
    schedule: "0 1 * * *"
    command: "fw reviewer audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate id 'dup-id'"* ]]
    [ ! -f "$TEST_PROJECT/.context/cron/agentic-audit.crontab" ]
}

@test "T-3171: generate does not truncate a previously-valid crontab source on refusal" {
    _write_registry <<'EOF'
jobs:
  - id: fine-job
    name: "Fine job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.context/cron/agentic-audit.crontab" ]
    before_checksum="$(md5sum "$TEST_PROJECT/.context/cron/agentic-audit.crontab")"

    _write_registry <<'EOF'
jobs:
  - id: fine-job
    name: "Fine job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
  - name: "Bad job added later, no id"
    schedule: "*/5 * * * *"
    command: "fw doctor"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -ne 0 ]
    after_checksum="$(md5sum "$TEST_PROJECT/.context/cron/agentic-audit.crontab")"
    [ "$before_checksum" = "$after_checksum" ]
}

@test "T-3171: fw cron install inherits the refusal (never reaches the install step)" {
    _write_registry <<'EOF'
jobs:
  - name: "No id job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/etc-cron.d"
    mkdir -p "$FW_CRON_INSTALL_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" cron install
    [ "$status" -ne 0 ]
    [[ "$output" == *"fw cron generate failed"* ]]
    slug=$(basename "$TEST_PROJECT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')
    [ ! -f "$FW_CRON_INSTALL_DIR/agentic-audit-${slug}" ]
}

@test "T-3171: reproduction — the exact 001-CashWeb shape (one job, no id, built from crontab -l) is refused by generate before install/list/run can ever see it" {
    # Before the fix: generate exited 0, and `fw cron list` printed the
    # 'Cron registry: 1 jobs' header then raised KeyError: 'id' — a counter
    # reporting a job it cannot process (PL-020 shape). After the fix,
    # generate refuses outright, so a registry in this shape never reaches
    # the installed crontab in the first place.
    _write_registry <<'EOF'
jobs:
  - name: "Solo job from crontab -l"
    schedule: "0 3 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing/empty id"* ]]
    [ ! -f "$TEST_PROJECT/.context/cron/agentic-audit.crontab" ]
}

@test "T-3171: fw cron list still requires id hard (no read-side softening) if a bad registry reaches it by another path" {
    # AC5: the write-side refusal in generate is the fix; list/run must NOT
    # gain a .get('id', ...) default, because that would preserve an
    # uncontrollable live schedule while hiding the defect. This test writes
    # the bad registry directly (bypassing generate) to confirm list still
    # fails loudly rather than silently degrading.
    _write_registry <<'EOF'
jobs:
  - name: "Solo job from crontab -l"
    schedule: "0 3 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron list
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cron registry: 1 jobs"* ]]
    [[ "$output" == *"KeyError"* ]] || [[ "$output" == *"'id'"* ]]
}
