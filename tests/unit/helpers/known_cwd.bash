# tests/unit/helpers/known_cwd.bash — classify commands from a KNOWN cwd (T-4429).
#
# Since T-4409, is_bash_safe_command judges git by the shell's starting cwd
# (_fw_initial_git_cwd, agents/context/lib/safe-commands.sh): the hook payload's
# cwd, else $PWD only when it IS PROJECT_ROOT, else unknown — and an unknown cwd
# makes the git arm fail closed. A real hook always carries the payload cwd. A
# test that sources the library bare carries neither, so its verdict depended on
# whoever ran bats (green from a worker shell with PROJECT_ROOT=$PWD, red from
# cron or /tmp). These helpers give the test the context a hook has.
#
#   load helpers/known_cwd
#   setup() { known_cwd_setup; ... }       teardown() { known_cwd_teardown; }
#
# known_cwd_setup: a private temp project (realpath'd, with the .tasks/.context
# markers), exported as PROJECT_ROOT and _FW_PAYLOAD_CWD, and made the cwd, so
# `bash -c` subshells inherit all three. Only classification runs here — no git
# command executes in it — so it needs no repository.
#
# known_cwd_assert_fail_closed LIB: pins the T-4409 rule itself — with no payload
# cwd and PWD != PROJECT_ROOT, `git status` is GATED.

known_cwd_setup() {
    KNOWN_CWD_ROOT="$(realpath -e -- "$(mktemp -d)")"
    KNOWN_CWD_PROJECT="$KNOWN_CWD_ROOT/project"
    mkdir -p "$KNOWN_CWD_PROJECT/.tasks/active" "$KNOWN_CWD_PROJECT/.context/working" \
        "$KNOWN_CWD_ROOT/elsewhere"
    PROJECT_ROOT="$KNOWN_CWD_PROJECT"
    _FW_PAYLOAD_CWD="$KNOWN_CWD_PROJECT"
    export PROJECT_ROOT _FW_PAYLOAD_CWD KNOWN_CWD_ROOT KNOWN_CWD_PROJECT
    cd "$KNOWN_CWD_PROJECT" || return 1
}

known_cwd_teardown() {
    cd / || true
    [ -n "${KNOWN_CWD_ROOT:-}" ] && [ -d "$KNOWN_CWD_ROOT" ] && rm -rf "$KNOWN_CWD_ROOT"
    return 0
}

# $1 = library to source. Runs in a clean subshell so nothing the test set leaks in.
known_cwd_assert_fail_closed() {
    local lib="$1" out
    out="$(cd "$KNOWN_CWD_ROOT/elsewhere" && env -u _FW_PAYLOAD_CWD -u _FW_GIT_CWD \
        PROJECT_ROOT="$KNOWN_CWD_PROJECT" FW_T_LIB="$lib" bash -c \
        'source "$FW_T_LIB"; if is_bash_safe_command "git status"; then echo SAFE; else echo GATED; fi')"
    [ "$out" = "GATED" ] || { echo "fail-closed: expected GATED with unknown cwd, got '$out'"; return 1; }
    # CONTROL: the same command from PROJECT_ROOT itself is a known cwd and stays safe,
    # so the GATED above is the cwd rule firing, not git status being refused outright.
    out="$(cd "$KNOWN_CWD_PROJECT" && env -u _FW_PAYLOAD_CWD -u _FW_GIT_CWD \
        PROJECT_ROOT="$KNOWN_CWD_PROJECT" FW_T_LIB="$lib" bash -c \
        'source "$FW_T_LIB"; if is_bash_safe_command "git status"; then echo SAFE; else echo GATED; fi')"
    [ "$out" = "SAFE" ] || { echo "fail-closed control: expected SAFE from PROJECT_ROOT, got '$out'"; return 1; }
}
