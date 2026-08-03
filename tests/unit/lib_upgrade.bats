#!/usr/bin/env bats
# Unit tests for lib/upgrade.sh
#
# Tests do_upgrade argument parsing, help, and guards

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    # T-2759: do_upgrade's shim-migration step (4c) reads $HOME/.local/bin/fw
    # unconditionally — a real host with fw installed via the shim-symlink
    # pattern leaks its own ~/.local/bin/fw state into every real-run test
    # here. On the framework's own dev host that symlink resolves into a
    # self-vendored copy carrying its own FRAMEWORK.md, so the T-1278
    # defence-in-depth guard REFUSES and do_upgrade returns 1 — aborting
    # before steps 5-10 run. Scope HOME to an empty temp dir so $HOME/.local/bin
    # never exists and step 4c's `[ -d "$local_bin" ]` guard skips it cleanly.
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "upgrade: do_upgrade --help shows usage" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw upgrade"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "upgrade: do_upgrade --help shows what gets upgraded" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"What gets upgraded"* ]]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *"Task templates"* ]]
    [[ "$output" == *"Git hooks"* ]]
}

@test "upgrade: do_upgrade rejects unknown option" {
    run do_upgrade --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "upgrade: do_upgrade rejects nonexistent directory" {
    run do_upgrade "/nonexistent/dir/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "upgrade: do_upgrade rejects project without .framework.yaml" {
    local proj="$TEST_TEMP_DIR/no-fw"
    mkdir -p "$proj"
    run do_upgrade "$proj"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not a framework project"* ]]
}

@test "upgrade: do_upgrade rejects upgrading framework itself" {
    # Create .framework.yaml so it passes the first guard and hits the self-check
    local had_fw=false
    [ -f "$FRAMEWORK_ROOT/.framework.yaml" ] && had_fw=true
    [ "$had_fw" = false ] && echo "framework_root: $FRAMEWORK_ROOT" > "$FRAMEWORK_ROOT/.framework.yaml"
    run do_upgrade "$FRAMEWORK_ROOT"
    [ "$had_fw" = false ] && rm -f "$FRAMEWORK_ROOT/.framework.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot upgrade the framework project itself"* ]]
}

@test "upgrade: do_upgrade --dry-run shows dry run mode" {
    local proj="$TEST_TEMP_DIR/dry-proj"
    mkdir -p "$proj"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "upgrade: do_upgrade shows version info" {
    local proj="$TEST_TEMP_DIR/ver-proj"
    mkdir -p "$proj"
    echo -e "framework_root: $FRAMEWORK_ROOT\nversion: 1.4.0" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.4.0"* ]]
    [[ "$output" == *"1.5.0"* ]]
}

@test "upgrade: do_upgrade shows current version match" {
    local proj="$TEST_TEMP_DIR/cur-proj"
    mkdir -p "$proj"
    echo -e "framework_root: $FRAMEWORK_ROOT\nversion: 1.5.0" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"current"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# G-056 / T-1383: resume.md drift-refresh invariants
# ─────────────────────────────────────────────────────────────────────────────

@test "upgrade: detects resume.md drift vs lib/templates/resume-md.md and refreshes with .bak" {
    local proj="$TEST_TEMP_DIR/drift-proj"
    mkdir -p "$proj/.claude/commands"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    # Synthesize pre-T-1378 stale content
    cat > "$proj/.claude/commands/resume.md" <<'STALE'
# /resume - OLD STALE VERSION
5. Check web server: curl -sf http://localhost:3000/
STALE
    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume.md refreshed from template"* ]]
    # Refreshed file contains canonical triple-file read
    grep -q 'watchtower.url' "$proj/.claude/commands/resume.md"
    # Backup preserved
    [ -f "$proj/.claude/commands/resume.md.bak" ]
    grep -q 'OLD STALE VERSION' "$proj/.claude/commands/resume.md.bak"
}

@test "upgrade: resume.md matches template — reports OK, no .bak written" {
    local proj="$TEST_TEMP_DIR/match-proj"
    mkdir -p "$proj/.claude/commands"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    cp "$FRAMEWORK_ROOT/lib/templates/resume-md.md" "$proj/.claude/commands/resume.md"
    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume.md matches template"* ]]
    [ ! -f "$proj/.claude/commands/resume.md.bak" ]
}

@test "upgrade: missing resume.md — created from template" {
    local proj="$TEST_TEMP_DIR/create-proj"
    mkdir -p "$proj"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume.md from template"* ]]
    [ -f "$proj/.claude/commands/resume.md" ]
    grep -q 'watchtower.url' "$proj/.claude/commands/resume.md"
}

# T-2759 (target_dir rebind in step 4c's shim migration) has its own
# regression coverage in tests/unit/t2759_upgrade_target_dir_shadowing.bats —
# real bin/fw subprocess, controlled $HOME, asserts exact directory contents.
