#!/usr/bin/env bats
# T-3837: bin/fw runs under `set -euo pipefail` (line 12). In that mode
#
#     x=$(cmd); rc=$?
#
# never reaches `rc=$?` when cmd fails — the failed assignment IS the errexit,
# and `fw doctor` dies mid-check with no summary. Four doctor checks were written
# that way (BVP scorability, DM rail, consult inbox, sidecar watcher), each of
# them designed to branch on a non-zero rc, plus a bare TermLink topic-list
# capture that died whenever the local hub was down. Reported by a peer project
# after upgrading to v1.8.0. Fix shape: `x=$(cmd) && rc=0 || rc=$?`.
#
# Test 1 is behavioural: a termlink whose every subcommand fails (hub down) must
# not stop doctor before its summary. Test 2 is the static guard for the class.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3837-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-3837: fw doctor reaches its summary when termlink is installed but every call fails" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj" "$TEST_TEMP_DIR/stub" "$TEST_TEMP_DIR/home"
    git -C "$proj" init --quiet
    "$FRAMEWORK_ROOT/bin/fw" vendor --target "$proj" --source "$FRAMEWORK_ROOT" >/dev/null 2>&1
    printf 'project_name: proj\nprovider: claude\n' > "$proj/.framework.yaml"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context"

    # hub down: --version answers, everything else exits 1
    cat > "$TEST_TEMP_DIR/stub/termlink" <<'SH'
#!/bin/sh
case "$1" in --version) echo "termlink 0.0.0-stub" ;; *) exit 1 ;; esac
SH
    chmod +x "$TEST_TEMP_DIR/stub/termlink"

    run bash -c "cd '$proj' && env -i PATH='$TEST_TEMP_DIR/stub:/usr/local/bin:/usr/bin:/bin' \
        HOME='$TEST_TEMP_DIR/home' FW_PORT=1 timeout 400 '$proj/.agentic-framework/bin/fw' doctor 2>&1"
    # premise: the stub was the termlink doctor saw
    [[ "$output" == *"termlink 0.0.0-stub"* ]] || { echo "$output"; false; }
    # the summary line is the last thing doctor prints; an errexit never reaches it
    echo "$output" | tail -3 | grep -qE 'no failures|failure\(s\)' || { echo "$output" | tail -15; false; }
}

@test "T-3837: no 'x=\$(cmd); rc=\$?' capture remains in bin/fw or lib/ (dead under set -e)" {
    run grep -nE '=\$\(.*\)[[:space:]]*;[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\?' \
        "$FRAMEWORK_ROOT/bin/fw" "$FRAMEWORK_ROOT"/lib/*.sh
    # grep exit 1 = no match; anything printed is an offending line (comments excluded)
    local offenders
    offenders=$(printf '%s\n' "$output" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep . || true)
    [ -z "$offenders" ] || { echo "$offenders"; false; }
}
