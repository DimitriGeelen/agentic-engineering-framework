#!/usr/bin/env bats
#
# T-4687: the T-4662 contract says a caller with no hook payload exports
# _FW_PAYLOAD_CWD. 050 did exactly that with PROJECT_ROOT unset (cwd /tmp) and
# `git status` was refused with no message. Now the project is derived from the
# payload cwd (nearest .framework.yaml); a payload cwd in no framework project is
# refused with one stderr line naming both variables.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions
# compare captured output instead.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$ROOT/agents/context/lib/safe-commands.sh"
    PROJ="$(realpath "$(mktemp -d)")"
    BARE="$(realpath "$(mktemp -d)")"
    mkdir -p "$PROJ/sub"
    git -C "$PROJ" init -q
    touch "$PROJ/.framework.yaml"
    git -C "$BARE" init -q
    ERR="$BATS_TEST_TMPDIR/err"
}

teardown() {
    rm -rf "$PROJ" "$BARE"
}

# _judge <payload cwd> <cmd> [PROJECT_ROOT]: 050's shape — shell cwd /tmp, no
# _FW_GIT_CWD, PROJECT_ROOT unset unless given. Prints SAFE / NOTSAFE; stderr -> $ERR.
_judge() {
    local pc="$1" cmd="$2" pr="${3:-}"
    ( cd /tmp && env -u PROJECT_ROOT -u _FW_GIT_CWD -u _FW_NO_CWD_NOTED _FW_PAYLOAD_CWD="$pc" \
        ${pr:+PROJECT_ROOT="$pr"} \
        bash -c 'source "$1"; if is_bash_safe_command "$2"; then echo SAFE; else echo NOTSAFE; fi
                 is_bash_safe_command "$2"; true' _ "$LIB" "$cmd" ) 2>"$ERR"
}

@test "050 shape: PROJECT_ROOT unset, _FW_PAYLOAD_CWD=<framework project>: git status SAFE, silent" {
    run _judge "$PROJ" "git status"
    [ "${lines[0]}" = "SAFE" ]
    [ ! -s "$ERR" ]
}

@test "050 shape from a subdirectory of the project: git log SAFE" {
    run _judge "$PROJ/sub" "git log --oneline -1"
    [ "${lines[0]}" = "SAFE" ]
}

@test "payload cwd in a repo that is not a framework project: refused with one note naming both variables" {
    run _judge "$BARE" "git status"
    [ "${lines[0]}" = "NOTSAFE" ]
    [ "$(wc -l < "$ERR")" -eq 1 ]
    grep -q "PROJECT_ROOT is unset" "$ERR"
    grep -q "_FW_PAYLOAD_CWD=$BARE" "$ERR"
    grep -q "T-4687" "$ERR"
}

@test "derived project keeps the foreign-repo rule: cd <bare repo> && git status refused" {
    run _judge "$PROJ" "cd $BARE && git status"
    [ "${lines[0]}" = "NOTSAFE" ]
}

@test "derived project keeps -C confinement: git -C <bare repo> status refused" {
    run _judge "$PROJ" "git -C $BARE status"
    [ "${lines[0]}" = "NOTSAFE" ]
}

@test "explicit PROJECT_ROOT is not overridden: payload cwd outside the given PROJECT_ROOT stays NOT SAFE" {
    run _judge "$PROJ" "git status" "$BARE"
    [ "${lines[0]}" = "NOTSAFE" ]
    [ ! -s "$ERR" ]
}

@test "derivation is scoped to the call: PROJECT_ROOT is still unset afterwards" {
    run bash -c 'cd /tmp && unset PROJECT_ROOT _FW_GIT_CWD; _FW_PAYLOAD_CWD="$1"; source "$2"
                 is_bash_safe_command "git status" >/dev/null 2>&1; echo "[${PROJECT_ROOT-unset}]"' _ "$PROJ" "$LIB"
    [ "$output" = "[unset]" ]
}
