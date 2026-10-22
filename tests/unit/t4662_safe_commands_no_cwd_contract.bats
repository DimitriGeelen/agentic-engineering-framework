#!/usr/bin/env bats
#
# T-4662: since T-4409 the git arm of is_bash_safe_command refuses when the shell's
# cwd is unknown, and a caller with no hook payload (a consumer test harness that
# sources safe-commands.sh) has no known cwd unless $PWD IS PROJECT_ROOT. The
# refusal stays; the contract is now explicit: export _FW_PAYLOAD_CWD=<absolute
# cwd> to state it, and a refusal for want of one says so on stderr, once.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions
# use `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$ROOT/agents/context/lib/safe-commands.sh"
    PROJ="$(realpath "$(mktemp -d)")"
    EVIL="$PROJ.evil"
    mkdir -p "$PROJ/sub" "$EVIL"
    ERR="$BATS_TEST_TMPDIR/err"
}

teardown() {
    rm -rf "$PROJ" "$EVIL"
}

# Run CMD through the library as a harness would: fresh shell, no payload variable,
# PWD = $1. Prints SAFE / NOTSAFE on stdout; stderr goes to $ERR.
_harness() {
    local pwd="$1" cmd="$2"
    ( cd "$pwd" && env -u _FW_PAYLOAD_CWD -u _FW_GIT_CWD PROJECT_ROOT="$PROJ" \
        bash -c 'source "$1"; if is_bash_safe_command "$2"; then echo SAFE; else echo NOTSAFE; fi
                 is_bash_safe_command "$2"; true' _ "$LIB" "$cmd" ) 2>"$ERR"
}

@test "harness, no payload cwd, PWD in a subdirectory: git status refused" {
    run _harness "$PROJ/sub" "git status"
    [ "${lines[0]}" = "NOTSAFE" ]
}

@test "harness, no payload cwd: refusal names the reason and the _FW_PAYLOAD_CWD opt-in on stderr" {
    _harness "$PROJ/sub" "git status" >/dev/null
    grep -q "cwd is unknown" "$ERR"
    grep -q "_FW_PAYLOAD_CWD" "$ERR"
}

@test "harness, no payload cwd: the note is printed once per process, not per call" {
    _harness "$PROJ/sub" "git status" >/dev/null
    [ "$(grep -c '_FW_PAYLOAD_CWD' "$ERR")" -eq 1 ]
}

@test "harness opt-in: _FW_PAYLOAD_CWD inside PROJECT_ROOT makes git status SAFE, silently" {
    run bash -c 'cd "$1" && PROJECT_ROOT="$2" _FW_PAYLOAD_CWD="$1" bash -c "source \"$3\"; is_bash_safe_command \"git status\" && echo SAFE" 2>"$4"' \
        _ "$PROJ/sub" "$PROJ" "$LIB" "$ERR"
    [ "$output" = "SAFE" ]
    [ ! -s "$ERR" ]
}

@test "foreign repo: _FW_PAYLOAD_CWD outside PROJECT_ROOT stays NOT SAFE, no harness note" {
    run bash -c 'cd "$1" && PROJECT_ROOT="$2" _FW_PAYLOAD_CWD="$1" bash -c "source \"$3\"; is_bash_safe_command \"git status\" && echo SAFE || echo NOTSAFE" 2>"$4"' \
        _ "$EVIL" "$PROJ" "$LIB" "$ERR"
    [ "$output" = "NOTSAFE" ]
    if grep -q "_FW_PAYLOAD_CWD" "$ERR"; then false; fi
}

@test "foreign repo: cd /tmp/evil && git status stays NOT SAFE with a project payload cwd" {
    run bash -c 'PROJECT_ROOT="$2" _FW_PAYLOAD_CWD="$2" bash -c "source \"$3\"; is_bash_safe_command \"cd $1 && git status\" && echo SAFE || echo NOTSAFE"' \
        _ "$EVIL" "$PROJ" "$LIB"
    [ "$output" = "NOTSAFE" ]
}

@test "harness, PWD IS PROJECT_ROOT: unchanged (SAFE, no note)" {
    run _harness "$PROJ" "git status"
    [ "${lines[0]}" = "SAFE" ]
    [ ! -s "$ERR" ]
}

@test "contract is documented in the library header" {
    head -60 "$LIB" | grep -q "T-4662"
    head -60 "$LIB" | grep -q "_FW_PAYLOAD_CWD"
}
