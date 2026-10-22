#!/usr/bin/env bats
#
# T-4630 (SECURITY, G-121): the read-only allowlist admitted journalctl and dmesg by
# name. journalctl --vacuum-*/--rotate/--flush/--sync/--relinquish-var/
# --update-catalog/--setup-keys/--cursor-file change journal state or write a file;
# dmesg -C/-c clear the ring buffer and -D/-E/-n change console logging. Reported by
# ring20-dashboard round 2 (msg 9e201103).
#
# Fix: agents/context/lib/safe-commands.sh _fw_option_changes_state — judged on the
# dequoted words, getopt abbreviations included; SYSTEMD_PAGER prefix denied.
# Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    cd "$ROOT"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-4630: the probe's journalctl and dmesg lines are NOT SAFE" {
    _refused "journalctl --vacuum-time=1s" "journalctl --vacuum-size=1M" "journalctl --vacuum-files=1" \
        "journalctl --rotate" "journalctl --flush" "dmesg -C" "dmesg --clear" "dmesg -c"
}

@test "T-4630: the other journalctl maintenance options are NOT SAFE" {
    _refused "journalctl --sync" "journalctl --relinquish-var" "journalctl --smart-relinquish-var" \
        "journalctl --update-catalog" "journalctl --setup-keys" "journalctl --cursor-file=/tmp/c -n1" \
        "journalctl --cursor-file /tmp/c" "journalctl -u x --rotate"
}

@test "T-4630: getopt abbreviations are NOT SAFE" {
    _refused "journalctl --rot" "journalctl --vacuum-t=1s" "journalctl --fl" "journalctl --cursor-f=/tmp/c" \
        "dmesg --cl" "dmesg --read" "dmesg --console-l 1"
}

@test "T-4630: dmesg console options and short bundles are NOT SAFE" {
    _refused "dmesg -D" "dmesg -E" "dmesg -n 1" "dmesg -n1" "dmesg -Hc" "dmesg -TC" \
        "dmesg --console-off" "dmesg --console-on" "dmesg --console-level=1"
}

@test "T-4630: quoted or expanded spellings and SYSTEMD_PAGER are NOT SAFE" {
    _refused "journalctl '--rotate'" "journalctl --vac\"uum-time=1s\"" 'journalctl "$O"' \
        "dmesg '-C'" 'dmesg "$O"' "dmesg -{C,T}" "SYSTEMD_PAGER=touch journalctl -u x"
}

@test "T-4630: read forms and the G-121 controls stay SAFE" {
    _safe "journalctl -u x" "journalctl -u x -n 50 --no-pager" "journalctl --cursor=abc" \
        "journalctl --since today -o json" "journalctl --verify" "journalctl --system -b" \
        "journalctl -f -u x" "dmesg" "dmesg -T" "dmesg --level=err" "dmesg -H --color=never" \
        "dmesg -l err,warn" "pgrep -f x" "getent hosts x"
}
