#!/usr/bin/env bats
# T-2414 — claude-fw stamps `-n <project>` into CC picker via `claude --name`.
#
# CC's `claude agents` picker has no project column. T-2413 spike found that
# CC has a first-class `claude -n/--name <name>` flag — "Set a display name
# for this session picker, and terminal title". claude-fw passes this when
# the user has not provided one, defaulting to the project basename.
#
# Cases:
#   - default        : bare claude-fw → -n <basename> in claude argv
#   - user-wins      : claude-fw --name custom → no second -n added
#   - env-override   : FW_PROJECT_NAME=AEF → -n AEF
#   - opt-out        : FW_NO_PICKER_NAME=1 → no -n flag in argv
#   - short-form     : claude-fw -n custom → no second -n added

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="$FRAMEWORK_ROOT/bin/claude-fw"
    [ -f "$WRAPPER" ] || skip "bin/claude-fw not found"
    command -v git >/dev/null || skip "git unavailable"

    PROJ="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    ARGV_LOG="$PROJ/argv.log"
    ( cd "$PROJ" && git init -q -b master && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init )

    # Stub `claude` that writes its full argv to a log then exits cleanly.
    # printf '%s\n' guarantees one arg per line — easy to grep/wc.
    cat > "$BINDIR/claude" <<STUB
#!/bin/bash
printf '%s\n' "\$@" > "$ARGV_LOG"
exit 0
STUB
    chmod +x "$BINDIR/claude"
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
}

@test "FIX default: claude-fw passes -n <project-basename> when no name provided" {
    cd "$PROJ"
    expected_name=$(basename "$PROJ")
    run timeout 20 env PATH="$BINDIR:$PATH" bash "$WRAPPER" --no-restart
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    # First two args should be -n <basename>
    head_arg=$(head -1 "$ARGV_LOG")
    name_arg=$(sed -n '2p' "$ARGV_LOG")
    [ "$head_arg" = "-n" ]
    [ "$name_arg" = "$expected_name" ]
}

@test "CONTROL user-wins: --name <custom> does NOT cause a second -n to be added" {
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" bash "$WRAPPER" --no-restart --name custom
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    # Exactly one occurrence of --name (or -n) — no auto-added second flag
    n_count=$(grep -cE '^(--name(=.*)?|-n)$' "$ARGV_LOG" || true)
    [ "$n_count" -eq 1 ]
    grep -qE '^--name$' "$ARGV_LOG"
    grep -qE '^custom$' "$ARGV_LOG"
}

@test "CONTROL short-form-wins: -n <custom> does NOT cause a second -n to be added" {
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" bash "$WRAPPER" --no-restart -n shortcustom
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    n_count=$(grep -cE '^(-n|--name(=.*)?)$' "$ARGV_LOG" || true)
    [ "$n_count" -eq 1 ]
    grep -qE '^shortcustom$' "$ARGV_LOG"
}

@test "FIX env-override: FW_PROJECT_NAME=AEF passes -n AEF" {
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" FW_PROJECT_NAME=AEF bash "$WRAPPER" --no-restart
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    head_arg=$(head -1 "$ARGV_LOG")
    name_arg=$(sed -n '2p' "$ARGV_LOG")
    [ "$head_arg" = "-n" ]
    [ "$name_arg" = "AEF" ]
}

@test "FIX opt-out: FW_NO_PICKER_NAME=1 means no -n added" {
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" FW_NO_PICKER_NAME=1 bash "$WRAPPER" --no-restart
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    # Either log is empty (no extra args) or no -n/--name present
    n_count=$(grep -cE '^(-n|--name(=.*)?)$' "$ARGV_LOG" || true)
    [ "$n_count" -eq 0 ]
}
