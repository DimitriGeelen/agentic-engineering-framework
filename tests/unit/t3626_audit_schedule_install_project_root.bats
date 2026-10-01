#!/usr/bin/env bats
# T-3626: 'PROJECT_ROOT=/x agents/audit/audit.sh schedule install' delegates to
# 'fw cron install'. audit.sh sources lib/paths.sh (sets _FW_PATHS_DERIVED_BY)
# and exec'd fw without cd-ing, so the nested fw's T-3285 re-anchor replaced
# the explicit PROJECT_ROOT with the CWD project — writing and installing the
# wrong project's crontab (in the wild: the live repo's).
#
# The cwd is pinned to a DECOY fixture project, so the test never depends on
# (or writes into) whatever tree the suite happens to be run from.

load ../test_helper

_mkproj() {
    local p="$1"
    mkdir -p "$p/.context/cron" "$p/.context/working" "$p/.context/audits/cron" \
             "$p/.tasks/active" "$p/.tasks/completed" "$p/.tasks/templates"
    echo "# template" > "$p/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$p/.framework.yaml"
    cat > "$p/.context/cron-registry.yaml" <<EOF
jobs:
  - id: marker-$2
    name: "Marker job $2"
    schedule: "17 3 * * *"
    command: "fw audit --section observations --cron"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TARGET="$TEST_TEMP_DIR/target-proj"
    DECOY="$TEST_TEMP_DIR/decoy-proj"
    _mkproj "$TARGET" target
    _mkproj "$DECOY" decoy
    mkdir -p "$TEST_TEMP_DIR/etc-cron-d"
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/etc-cron-d"
    unset TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "schedule install honours explicit PROJECT_ROOT when cwd is another project" {
    cd "$DECOY"
    PROJECT_ROOT="$TARGET" run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
    [ "$status" -eq 0 ]
    [ -f "$TARGET/.context/cron/agentic-audit.crontab" ]
    grep -q "Marker job target" "$TARGET/.context/cron/agentic-audit.crontab"
    [ ! -f "$DECOY/.context/cron/agentic-audit.crontab" ]
}
