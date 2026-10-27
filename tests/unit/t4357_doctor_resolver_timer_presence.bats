#!/usr/bin/env bats
# T-4357 (GH #100) — doctor's Autonomous Dispatch block must decide whether
# resolver-loop.timer is installed from the unit name in `systemctl
# list-unit-files` output, not from its exit code: systemd 245 exits 0 when no
# unit matches, which made doctor say "installed but inactive" on hosts where
# the timer was never installed.
#
# The block under test is taken from bin/fw itself (from the section header to
# the cron-registry read that follows it) and run against a stub systemctl.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUB_DIR="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_DIR"
}

_block() {
    awk '/\$\{BOLD\}Autonomous Dispatch\$\{NC\}/{on=1; next} on && /if \[ -f "\$cron_registry" \]/{exit} on{print}' \
        "$FRAMEWORK_ROOT/bin/fw"
}

# $1 = list-unit-files exit code, $2 = list the unit (1/0), $3 = is-active exit code
_stub_systemctl() {
    cat > "$STUB_DIR/systemctl" <<EOF
#!/bin/bash
case "\$1" in
    list-unit-files)
        if [ "$2" = "1" ]; then
            echo "resolver-loop.timer disabled enabled"
        else
            echo "0 unit files listed."
        fi
        exit $1 ;;
    is-active) exit $3 ;;
    # T-4819: the unit belongs to this project (WorkingDirectory = PROJECT_ROOT).
    show) echo "WorkingDirectory=$BATS_TEST_TMPDIR"; exit 0 ;;
esac
exit 1
EOF
    chmod +x "$STUB_DIR/systemctl"
}

_run_block() {
    local block
    block="$(_block)"
    [ -n "$block" ]
    run env PATH="$1" PROJECT_ROOT="$BATS_TEST_TMPDIR" /bin/bash -c "_section() { GREEN=''; CYAN=''; NC=''
$block
}; _section"
}

@test "T-4357: the block is found in bin/fw" {
    block="$(_block)"
    [[ "$block" == *"resolver-loop.timer"* ]]
}

@test "T-4357: systemd 245 (exit 0, no unit listed) reports not installed" {
    _stub_systemctl 0 0 3
    _run_block "$STUB_DIR:/usr/bin:/bin"
    [[ "$output" == *"resolver-loop.timer not installed on this host"* ]]
    [[ "$output" != *"installed but inactive"* ]]
}

@test "T-4357/control: newer systemd (exit 1, no unit) reports not installed" {
    _stub_systemctl 1 0 3
    _run_block "$STUB_DIR:/usr/bin:/bin"
    [[ "$output" == *"not installed on this host"* ]]
}

@test "T-4357/control: unit listed and inactive reports installed but inactive" {
    _stub_systemctl 0 1 3
    _run_block "$STUB_DIR:/usr/bin:/bin"
    [[ "$output" == *"installed but inactive"* ]]
}

@test "T-4357/control: unit listed and active reports LIVE" {
    _stub_systemctl 0 1 0
    _run_block "$STUB_DIR:/usr/bin:/bin"
    [[ "$output" == *"LIVE"* ]]
}

@test "T-4357/control: no systemctl on PATH reports not installed" {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    _run_block "$BATS_TEST_TMPDIR/empty"
    [[ "$output" == *"not installed on this host"* ]]
}
