#!/usr/bin/env bats
# T-5048 — bin/fw writes no colour codes into files, pipes or under NO_COLOR.
#
# Origin: ring20-dashboard (be.26) — `NO_COLOR=1 bin/fw doctor --quick > f`
# wrote ^[[1mfw doctor^[[0m, so a verification line with a fixed-string marker
# that spanned a colour code never matched and 8 tasks could not close.
# bin/fw set its colours unconditionally (and so did ~20 embedded Python blocks),
# and lib/release.sh's `${RED:=...}` refilled the empty values bin/fw had chosen.
#
# One `fw doctor --quick` run per mode (setup_file), as t2452 does: it is the
# fast project-only path, and its exit code (warnings) is not under test here.

load ../test_helper

setup_file() {
    export FW_DOCTOR_HOOK_EXERCISE=0  # T-4523: skip the per-hook probe
    T5048_DIR="$(mktemp -d)"
    export T5048_DIR
    local fw="$BATS_TEST_DIRNAME/../../bin/fw"
    # stdout is a file, stderr is a file: neither is a terminal.
    "$fw" doctor --quick > "$T5048_DIR/plain.out" 2> "$T5048_DIR/plain.err" || true
    # NO_COLOR on top, as the field report ran it.
    NO_COLOR=1 "$fw" doctor --quick > "$T5048_DIR/nocolor.out" 2>&1 || true
}

teardown_file() {
    rm -rf "$T5048_DIR"
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"  # test_helper's teardown removes it
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

@test "doctor --quick redirected to a file carries no ESC byte" {
    [ -s "$T5048_DIR/plain.out" ]
    [ "$(grep -c $'\x1b' "$T5048_DIR/plain.out")" -eq 0 ]
}

@test "doctor --quick under NO_COLOR=1 carries no ESC byte" {
    [ -s "$T5048_DIR/nocolor.out" ]
    [ "$(grep -c $'\x1b' "$T5048_DIR/nocolor.out")" -eq 0 ]
}

@test "the doctor header is matchable with grep -F in both files" {
    grep -qF "fw doctor - Framework Health Check" "$T5048_DIR/plain.out"
    grep -qF "fw doctor - Framework Health Check" "$T5048_DIR/nocolor.out"
}

@test "status markers past the release-tag check are plain too (lib/release.sh no longer refills colours)" {
    # The VERSION check sources lib/release.sh; before T-5048 every line after it
    # was coloured again even though the header was plain.
    grep -qE "^  (OK|WARN|FAIL|SKIP)  " "$T5048_DIR/plain.out"
    run grep -nE ':=\\\\033' "$FRAMEWORK_ROOT/lib/release.sh"
    [ "$status" -eq 1 ]
}

@test "embedded Python output (fw gaps) piped carries no ESC byte" {
    run bash -c "'$FW_BIN' gaps 2>&1 | cat"
    [ "$status" -eq 0 ]
    [ "$(grep -c $'\x1b' <<<"$output")" -eq 0 ]
    grep -qF "Gaps Register" <<<"$output"
}

@test "colour is kept on a terminal (fw gaps under a pty)" {
    # Control leg: proves the guard is a terminal test, not "colour off".
    run python3 - "$FW_BIN" <<'PY'
import os, pty, subprocess, sys
master, slave = pty.openpty()
env = dict(os.environ)
env.pop("NO_COLOR", None)
p = subprocess.Popen([sys.argv[1], "gaps"], stdout=slave, stderr=slave,
                     stdin=subprocess.DEVNULL, env=env)
os.close(slave)
buf = b""
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError:
        break
    if not chunk:
        break
    buf += chunk
p.wait()
sys.exit(0 if b"\x1b[" in buf else 1)
PY
    [ "$status" -eq 0 ]
}

@test "bin/fw top-level colour block uses the lib/colors.sh guard" {
    grep -qF 'if [[ ( -t 1 || -t 2 ) && -z "${NO_COLOR:-}" ]]; then' "$FW_BIN"
    grep -qF "RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''" "$FW_BIN"
}

@test "bin/fw passes bash -n" {
    bash -n "$FW_BIN"
}
