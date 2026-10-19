#!/usr/bin/env bats
# T-4369: in the framework repo, an inherited FRAMEWORK_ROOT=<repo>/.agentic-framework
# (claude-fw exported it, T-4218) made bin/fw run from the repo's vendored self-copy:
# `fw cron generate` wrote .agentic-framework/bin/fw into every cron line and `fw doctor`
# reported a false "Cron registry edited but not generated". bin/fw now drops an
# inherited FRAMEWORK_ROOT that is the vendored copy of the repo it runs from.
# Consumers keep their own vendored FRAMEWORK_ROOT (control leg).

REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# A framework tree at $1: real bin/ copied (bin/fw resolves itself via readlink -f),
# everything else symlinked to the real repo.
_fw_tree() {
    local d="$1" e
    mkdir -p "$d"
    cp -r "$REAL/bin" "$d/bin"
    for e in lib agents policy FRAMEWORK.md status-transitions.yaml; do
        ln -s "$REAL/$e" "$d/$e"
    done
}

setup() {
    TMP="$(mktemp -d)"
    REPO="$TMP/fwrepo"
    _fw_tree "$REPO"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" "$REPO/.context/working" "$REPO/.context/cron"
    ln -s "$REAL/.tasks/templates" "$REPO/.tasks/templates"
    _fw_tree "$REPO/.agentic-framework"
    : > "$REPO/.agentic-framework/.fw-not-a-project"
    cat > "$REPO/.context/cron-registry.yaml" <<'EOF'
jobs:
  - id: t4369-probe
    name: "T-4369 probe"
    schedule: "17 3 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-4369
    status: active
    description: "test"
EOF
    unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY CLAUDE_PROJECT_DIR
}

teardown() { rm -rf "$TMP"; }

@test "T-4369: repo bin/fw ignores an inherited FRAMEWORK_ROOT pointing at its own vendored copy" {
    run bash -c "cd '$REPO' && FRAMEWORK_ROOT='$REPO/.agentic-framework' bin/fw version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $REPO" <<<"$output"
}

@test "T-4369: cron generate under the inherited env writes the repo's bin/fw" {
    run bash -c "cd '$REPO' && FRAMEWORK_ROOT='$REPO/.agentic-framework' bin/fw cron generate 2>&1"
    [ "$status" -eq 0 ]
    line="$(grep -E '^[*0-9]' "$REPO/.context/cron/agentic-audit.crontab" | head -1)"
    [[ "$line" == *"\"$REPO/bin/fw\" audit"* ]]
    [[ "$line" != *".agentic-framework"* ]]
}

@test "T-4369: doctor under the inherited env reports no registry drift on a synced registry" {
    run bash -c "cd '$REPO' && env -u FRAMEWORK_ROOT bin/fw cron generate 2>&1"
    [ "$status" -eq 0 ]
    run bash -c "cd '$REPO' && FRAMEWORK_ROOT='$REPO/.agentic-framework' timeout 600 bin/fw doctor 2>&1"
    [[ "$output" == *"Cron "* ]]   # the cron section ran
    [[ "$output" != *"Cron registry edited but not generated"* ]]
}

# Same harness as t4218-a: a fake `claude` records the environment claude-fw starts it with.
@test "T-4369: claude-fw launched in the framework repo exports the repo, not its vendored copy" {
    mkdir -p "$TMP/fakebin"
    printf '#!/bin/bash\nenv > %q\nexit 0\n' "$TMP/claude.env" > "$TMP/fakebin/claude"
    chmod +x "$TMP/fakebin/claude"
    R="$(cd "$REPO" && pwd -P)"
    cd "$REPO"
    run env -u TMUX -u TL_CLAUDE_ENABLED -u FW_DISPATCHED_WORKER -u FRAMEWORK_ROOT \
        PATH="$TMP/fakebin:$PATH" FW_CLAUDE_FW_NO_TMUX=1 FW_NO_TERMINATOR=1 CLAUDE_FW_NO_SIDECAR=1 \
        bash "$REAL/bin/claude-fw" --no-restart </dev/null
    [ -s "$TMP/claude.env" ] || { echo "claude was not started: $output"; false; }
    grep -qx "FRAMEWORK_ROOT=$R" "$TMP/claude.env"
}

@test "T-4369 control: a consumer's inherited vendored FRAMEWORK_ROOT is still honoured" {
    C="$TMP/consumer"
    mkdir -p "$C/.tasks/active" "$C/.context/working"
    echo "project_name: consumer" > "$C/.framework.yaml"
    _fw_tree "$C/.agentic-framework"
    : > "$C/.agentic-framework/.fw-not-a-project"
    run bash -c "cd '$C' && FRAMEWORK_ROOT='$C/.agentic-framework' .agentic-framework/bin/fw version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $C/.agentic-framework" <<<"$output"
}
