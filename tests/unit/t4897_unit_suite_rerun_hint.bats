#!/usr/bin/env bats
# T-4897: the unit-suite grader's re-run hint is this project's own scheduled command
# (cron registry <kind>-nightly), so a consumer's FW_UNIT_SUITE_DIR is included. The bare
# default made 055 run an empty corpus (T-4896). Harness: the check is EXTRACTED from the
# shipped agents/audit/audit.sh, as in t3794/t3621.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WORK="$BATS_TEST_TMPDIR/t4897"
    mkdir -p "$WORK/ctx"
}

_run_check() {   # <context_dir>
    run env FW_UNIT_SUITE_REPORT="$WORK/missing-LATEST.yaml" SECTIONS="structure" \
        CTX="$1" REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "MITIGATION|$3"; }
        fail() { echo "FAIL|$1"; echo "MITIGATION|$3"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^_audit_is_prepush_scope() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="$CTX"
        check_unit_suite_report
    '
}

@test "consumer registry: the hint is the project's own unit-suite-nightly command" {
    cat > "$WORK/ctx/cron-registry.yaml" <<'EOF'
jobs:
- id: unit-suite-nightly
  schedule: 30 2 * * *
  command: FW_UNIT_SUITE_DIR=/srv/proj/tests PROJECT_ROOT=/srv/proj /srv/proj/.agentic-framework/agents/audit/unit-suite.sh
  status: active
EOF
    _run_check "$WORK/ctx"
    [[ "$output" == *"MITIGATION|Run once by hand: FW_UNIT_SUITE_DIR=/srv/proj/tests PROJECT_ROOT=/srv/proj /srv/proj/.agentic-framework/agents/audit/unit-suite.sh"* ]]
}

@test "no registry entry: the hint falls back to the default path" {
    printf 'jobs:\n- id: something-else\n  command: true\n' > "$WORK/ctx/cron-registry.yaml"
    _run_check "$WORK/ctx"
    [[ "$output" == *"MITIGATION|Run once by hand: agents/audit/unit-suite.sh"* ]]
}

@test "no registry file at all: the default path" {
    _run_check "$WORK/nonexistent"
    [[ "$output" == *"MITIGATION|Run once by hand: agents/audit/unit-suite.sh"* ]]
}
