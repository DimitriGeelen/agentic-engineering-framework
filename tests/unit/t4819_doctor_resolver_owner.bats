#!/usr/bin/env bats
# T-4819 (832 field report, msg 22d67d94) — doctor's Autonomous Dispatch block
# must attribute an active resolver-loop.timer to this project only when the
# service's WorkingDirectory is PROJECT_ROOT. systemd units are host-wide, so a
# name-only check made every co-resident consumer report AEF's loop as its own
# LIVE loop.
#
# Same harness as t4357: the block is taken from bin/fw and run against a stub
# systemctl on PATH. No real unit is queried.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUB_DIR="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_DIR"
    PROJ="$BATS_TEST_TMPDIR/proj"
    OTHER="$BATS_TEST_TMPDIR/other"
    mkdir -p "$PROJ" "$OTHER"
    ln -s "$PROJ" "$BATS_TEST_TMPDIR/proj-link"
}

_block() {
    awk '/\$\{BOLD\}Autonomous Dispatch\$\{NC\}/{on=1; next} on && /if \[ -f "\$cron_registry" \]/{exit} on{print}' \
        "$FRAMEWORK_ROOT/bin/fw"
}

# $1 = is-active exit code, $2 = WorkingDirectory the service reports ("" = unset)
_stub_systemctl() {
    cat > "$STUB_DIR/systemctl" <<EOF
#!/bin/bash
case "\$1" in
    list-unit-files) echo "resolver-loop.timer enabled enabled"; exit 0 ;;
    is-active) exit $1 ;;
    show)
        case "\$*" in
            *WorkingDirectory*resolver-loop.service*) echo "WorkingDirectory=$2"; exit 0 ;;
        esac ;;
esac
exit 1
EOF
    chmod +x "$STUB_DIR/systemctl"
}

# $1 = PROJECT_ROOT
_run_block() {
    local block
    block="$(_block)"
    [ -n "$block" ]
    run env PATH="$STUB_DIR:/usr/bin:/bin" PROJECT_ROOT="$1" /bin/bash -c "_section() { GREEN=''; CYAN=''; YELLOW=''; NC=''
$block
}; _section"
}

@test "T-4819: an active timer owned by another directory is not this project's LIVE loop" {
    _stub_systemctl 0 "$OTHER"
    _run_block "$PROJ"
    [[ "$output" != *"LIVE"* ]]
    [[ "$output" != *"dispatching unattended every 30m"* ]]
    [[ "$output" == *"INFO"*"another project's resolver loop"*"$OTHER"* ]]
}

@test "T-4819/control: an active timer whose WorkingDirectory is PROJECT_ROOT reports LIVE" {
    _stub_systemctl 0 "$PROJ"
    _run_block "$PROJ"
    [[ "$output" == *"LIVE"*"dispatching unattended every 30m"* ]]
}

@test "T-4819: PROJECT_ROOT and WorkingDirectory are compared by realpath" {
    _stub_systemctl 0 "$BATS_TEST_TMPDIR/proj-link"
    _run_block "$PROJ"
    [[ "$output" == *"LIVE"* ]]
}

@test "T-4819: an active timer with no WorkingDirectory is not claimed as LIVE" {
    _stub_systemctl 0 ""
    _run_block "$PROJ"
    [[ "$output" != *"LIVE"* ]]
    [[ "$output" == *"INFO"*"no WorkingDirectory"* ]]
}

@test "T-4819: an inactive timer owned by another directory names that directory" {
    _stub_systemctl 3 "$OTHER"
    _run_block "$PROJ"
    [[ "$output" == *"another project's resolver loop"*"$OTHER"*"inactive"* ]]
}

@test "T-4819/control: an inactive timer owned by this project keeps today's wording" {
    _stub_systemctl 3 "$PROJ"
    _run_block "$PROJ"
    [[ "$output" == *"systemd resolver-loop.timer is installed but inactive"* ]]
}
