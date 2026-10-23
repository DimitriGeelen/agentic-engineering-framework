#!/usr/bin/env bats
# T-4711 — ring20 runs Watchtower under its own systemd .service unit
# (Restart=on-failure). The T-4706 keep-alive (lib/watchtower-ensure.sh) and the
# own-scope start (bin/watchtower.sh) would start a second, unmanaged server inside
# systemd's restart window, and systemd's restart then fails on the busy port.
# Now: fw_watchtower_systemd_unit names the managing unit, ensure does nothing but
# say so, and start/restart refuse with `systemctl <verb> <unit>`. WATCHTOWER_ENSURE
# is a config key (0 = opt out).
#
# Every case uses fake cgroup files and a fake unit dir (FW_WATCHTOWER_PROC_DIR,
# FW_WATCHTOWER_SELF_CGROUP, FW_WATCHTOWER_UNIT_DIRS); no live Watchtower and no
# real systemd unit is read or touched.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR NO_COLOR=1
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj" FRAMEWORK_ROOT="$FWROOT"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    export FW_WATCHTOWER_PROC_DIR="$TEST_TEMP_DIR/proc"
    export FW_WATCHTOWER_SELF_CGROUP="$TEST_TEMP_DIR/self.cgroup"
    export FW_WATCHTOWER_UNIT_DIRS="$TEST_TEMP_DIR/units"
    mkdir -p "$FW_WATCHTOWER_PROC_DIR" "$FW_WATCHTOWER_UNIT_DIRS"
    echo "0::/system.slice/cron.service" > "$FW_WATCHTOWER_SELF_CGROUP"
    STUB="$TEST_TEMP_DIR/watchtower.sh"
    export FW_WATCHTOWER_SH="$STUB" CALLS="$TEST_TEMP_DIR/calls"
    cat > "$STUB" <<EOF
#!/usr/bin/env bash
echo "\$1" >> "$CALLS"
case "\$1" in status) exit 3 ;; start) exit 0 ;; esac
EOF
    chmod +x "$STUB"
    unset FW_WATCHTOWER_ENSURE FW_REVIEW_WORKER FW_DISPATCHED_WORKER FW_WATCHTOWER_ALLOW_LIVE_IN_TEST
    source "$FWROOT/lib/watchtower-ensure.sh"
    SLEEPER=""
}

teardown() {
    [ -n "$SLEEPER" ] && kill -KILL "$SLEEPER" 2>/dev/null || true
    rm -rf "${TEST_TEMP_DIR:?}"
}

_pid_in() {   # _pid_in <pid> <cgroup-path> — fake /proc/<pid>/cgroup + triple pid file
    mkdir -p "$FW_WATCHTOWER_PROC_DIR/$1"
    echo "0::$2" > "$FW_WATCHTOWER_PROC_DIR/$1/cgroup"
    echo "$1" > "$PROJECT_ROOT/.context/working/watchtower.pid"
}

_unit_file() {   # _unit_file <name> <workdir> <execstart>
    printf '[Service]\nWorkingDirectory=%s\nExecStart=%s\nRestart=on-failure\n' "$2" "$3" \
        > "$FW_WATCHTOWER_UNIT_DIRS/$1"
}

_starts() { [ -f "$CALLS" ] || { echo 0; return; }; grep -c '^start$' "$CALLS" || true; }

@test "t4711: pid in a *watchtower*.service cgroup -> unit named, ensure skips with one line" {
    _pid_in 4242 /system.slice/ring20-watchtower.service
    run fw_watchtower_systemd_unit
    [ "$status" -eq 0 ]
    [ "$output" = "ring20-watchtower.service" ]
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ "$output" = "watchtower: managed by systemd unit ring20-watchtower.service — ensure does nothing (T-4711)" ]
    [ ! -e "$CALLS" ]
    grep -q "skip: managed by systemd unit ring20-watchtower.service" "$PROJECT_ROOT/.context/working/watchtower-ensure.log"
}

@test "t4711: restart window (no live pid) -> unit file running this project's web.app is found, ensure never starts" {
    _unit_file wt.service "$PROJECT_ROOT" "/usr/bin/python3 -m web.app --port 3000"
    run fw_watchtower_systemd_unit
    [ "$status" -eq 0 ]
    [ "$output" = "wt.service" ]
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ "$(_starts)" -eq 0 ]
}

@test "t4711: another project's Watchtower unit, or a unit that is not a Watchtower, is not ours" {
    _unit_file other.service "$TEST_TEMP_DIR/otherproj" "/usr/bin/python3 -m web.app"
    _unit_file pfx.service "${PROJECT_ROOT}2" "${PROJECT_ROOT}2/bin/watchtower.sh start"
    _unit_file api.service "$PROJECT_ROOT" "/usr/bin/python3 -m api.server"
    run fw_watchtower_systemd_unit
    [ "$status" -eq 1 ]
    run fw_watchtower_ensure
    [ "$(_starts)" -eq 1 ]
}

@test "t4711: own-scope pid (aef-watchtower-*.scope) -> normal: ensure starts a dead one" {
    _pid_in 4243 /aef.slice/aef-watchtower-1-2.scope
    run fw_watchtower_systemd_unit
    [ "$status" -eq 1 ]
    run fw_watchtower_ensure
    [ "$(_starts)" -eq 1 ]
}

@test "t4711: a launcher's unit (cockpit/cron) is not 'managed'; the caller's own unit never is" {
    _pid_in 4244 /system.slice/agentic-fleet-cockpit.service
    run fw_watchtower_systemd_unit
    [ "$status" -eq 1 ]
    # a unit whose OWN ExecStart runs `watchtower.sh start` must be able to start it
    _pid_in 4245 /system.slice/wt.service
    _unit_file wt.service "$PROJECT_ROOT" "$PROJECT_ROOT/bin/watchtower.sh start"
    echo "0::/system.slice/wt.service" > "$FW_WATCHTOWER_SELF_CGROUP"
    run fw_watchtower_systemd_unit
    [ "$status" -eq 1 ]
    # ...while the same unit seen from cron is the manager
    echo "0::/system.slice/cron.service" > "$FW_WATCHTOWER_SELF_CGROUP"
    run fw_watchtower_systemd_unit
    [ "$status" -eq 0 ]
    [ "$output" = "wt.service" ]
}

@test "t4711: WATCHTOWER_ENSURE: 0 in .framework.yaml disables ensure; env FW_WATCHTOWER_ENSURE wins" {
    echo "WATCHTOWER_ENSURE: 0" > "$PROJECT_ROOT/.framework.yaml"
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ ! -e "$CALLS" ]
    FW_WATCHTOWER_ENSURE=1 run fw_watchtower_ensure
    [ "$(_starts)" -eq 1 ]
    echo "WATCHTOWER_ENSURE: 1" > "$PROJECT_ROOT/.framework.yaml"
    rm -f "$CALLS"
    run fw_watchtower_ensure
    [ "$(_starts)" -eq 1 ]
}

@test "t4711: WATCHTOWER_ENSURE is a registry key settable with fw config set" {
    grep -q '^    "WATCHTOWER_ENSURE|1|' "$FWROOT/lib/config.sh"
    grep -q '^    ("WATCHTOWER_ENSURE", "1",' "$FWROOT/web/blueprints/config.py"
    touch "$PROJECT_ROOT/.framework.yaml"
    run bash -c 'cd "$PROJECT_ROOT" && "$FRAMEWORK_ROOT/bin/fw" config set WATCHTOWER_ENSURE 0'
    [ "$status" -eq 0 ]
    grep -qx "WATCHTOWER_ENSURE: 0" "$PROJECT_ROOT/.framework.yaml"
}

@test "t4711: watchtower.sh start refuses on a systemd-managed Watchtower, hint names the unit" {
    _unit_file ring20-wt.service "$PROJECT_ROOT" "/usr/bin/python3 -m web.app"
    run "$FWROOT/bin/watchtower.sh" start --port 1
    [ "$status" -eq 5 ]
    [[ "$output" == *"managed by systemd unit ring20-wt.service"* ]]
    [[ "$output" == *"systemctl start ring20-wt.service"* ]]
    [ ! -e "$PROJECT_ROOT/.context/working/watchtower.port" ]
}

@test "t4711: watchtower.sh restart refuses before stopping the managed server" {
    sleep 300 & SLEEPER=$!
    _pid_in "$SLEEPER" /system.slice/ring20-watchtower.service
    run "$FWROOT/bin/watchtower.sh" restart
    [ "$status" -eq 5 ]
    [[ "$output" == *"systemctl restart ring20-watchtower.service"* ]]
    kill -0 "$SLEEPER"
    [ "$(cat "$PROJECT_ROOT/.context/working/watchtower.pid")" = "$SLEEPER" ]
}

@test "t4711: own-scope pid -> start is not refused (control leg)" {
    _pid_in 4246 /aef.slice/aef-watchtower-1-2.scope
    mkdir -p "$TEST_TEMP_DIR/bin"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/bin/python3"   # stop do_start at the module pre-flight
    chmod +x "$TEST_TEMP_DIR/bin/python3"
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" "$FWROOT/bin/watchtower.sh" start --port 1
    [ "$status" -ne 5 ]
    [[ "$output" != *"managed by systemd"* ]]
    [[ "$output" == *"missing Python module"* ]]
}
