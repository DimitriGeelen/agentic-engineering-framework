#!/usr/bin/env bats
# T-3374 (OBS-423) — the env-prefix stripper must refuse names that decide what
# the command it strips them from actually RESOLVES to.
#
# Before this fix, `is_bash_safe_command` returned SAFE for all four of:
#     PATH=/tmp cat x    LD_PRELOAD=/tmp/e.so cat x
#     BASH_ENV=/tmp/e.sh cat x    IFS=x cat y
# because the T-1908 stripper removed ANY `NAME=VALUE` prefix and then judged the
# base command that was left. The discarded prefix is the part that mattered.
#
# CONTROL LEG. Every assertion below must FAIL against the pre-fix source, or it
# is pinning nothing. Point the suite at any older copy of the library to prove
# that — this is how the control was demonstrated for the task's AC:
#
#   git show <pre-fix-rev>:agents/context/lib/safe-commands.sh > /tmp/old.sh
#   FW_SAFE_COMMANDS_SRC=/tmp/old.sh bats tests/unit/t3374_env_prefix_denylist.bats
#
# The override exists ONLY for that control run. It lives in the test, never in
# the library, so it cannot be used to weaken the gate at runtime.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    source "${FW_SAFE_COMMANDS_SRC:-$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh}"
}

# ---- The four measured OBS-423 forms ----

@test "PATH= prefix is refused (binary resolution)" {
    run is_bash_safe_command "PATH=/tmp cat x"
    [ "$status" -ne 0 ]
}

@test "LD_PRELOAD= prefix is refused (dynamic linker)" {
    run is_bash_safe_command "LD_PRELOAD=/tmp/evil.so cat x"
    [ "$status" -ne 0 ]
}

@test "BASH_ENV= prefix is refused (shell startup file)" {
    run is_bash_safe_command "BASH_ENV=/tmp/evil.sh cat x"
    [ "$status" -ne 0 ]
}

@test "IFS= prefix is refused (changes how the line parses)" {
    run is_bash_safe_command "IFS=x cat y"
    [ "$status" -ne 0 ]
}

# ---- The second entry point: assignments re-stripped inside the T-3096 wrapper
# loop. This is a DISTINCT bypass — a fix applied to only the primary loop leaves
# it open, and `env` is the wrapper an agent reaches for to set a variable. ----

@test "env-wrapped denied prefix is refused (second stripper entry point)" {
    run is_bash_safe_command "env PATH=/tmp cat x"
    [ "$status" -ne 0 ]
}

@test "timeout-wrapped denied prefix is refused" {
    run is_bash_safe_command "timeout 5 PATH=/tmp cat x"
    [ "$status" -ne 0 ]
}

# ---- git hands these to a shell, and `git` has broad read-only allowlisting,
# so they convert an allowlisted read into arbitrary execution. ----

@test "GIT_SSH_COMMAND= prefix is refused" {
    run is_bash_safe_command "GIT_SSH_COMMAND=/tmp/evil.sh git status"
    [ "$status" -ne 0 ]
}

@test "GIT_CONFIG_COUNT= prefix is refused (config-injected pager executes)" {
    run is_bash_safe_command "GIT_CONFIG_COUNT=1 git log"
    [ "$status" -ne 0 ]
}

@test "GIT_DIR= stays SAFE — retargets what is READ, not what RUNS" {
    # Boundary test, not an oversight. GIT_DIR points git at another repository;
    # the sub-verb allowlist still constrains this path to read-only verbs, so a
    # read of a different repo is still a read. Pinned at
    # tests/unit/safe_commands_env_prefix.bats:44 since T-1908; an earlier draft
    # of the denylist here broke it, and narrowing the denylist was the correct
    # response rather than editing that test.
    run is_bash_safe_command "GIT_DIR=foo git status"
    [ "$status" -eq 0 ]
}

@test "DYLD_INSERT_LIBRARIES= prefix is refused (macOS linker, D4 portability)" {
    run is_bash_safe_command "DYLD_INSERT_LIBRARIES=/tmp/e.dylib cat x"
    [ "$status" -ne 0 ]
}

# ---- CONTROL: the T-1908 / L-399 contract must survive untouched. These are the
# assertions that separate "the denylist is selective" from "the stripper was
# broken outright" — without them, deleting the stripper would pass this file. ----

@test "CONTROL: FW_SWITCH_FOCUS=1 stays safe (L-399 bypass contract)" {
    run is_bash_safe_command "FW_SWITCH_FOCUS=1 fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "CONTROL: FW_DEBUG=1 fw doctor stays safe" {
    run is_bash_safe_command "FW_DEBUG=1 fw doctor"
    [ "$status" -eq 0 ]
}

@test "CONTROL: multiple benign prefixes stay safe" {
    run is_bash_safe_command "FOO=1 BAR=2 fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "CONTROL: benign prefix + path-prefixed command stays safe" {
    run is_bash_safe_command "FW_SWITCH_FOCUS=1 bin/fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "CONTROL: bare allowlisted command stays safe" {
    run is_bash_safe_command "fw doctor"
    [ "$status" -eq 0 ]
}

# ---- Mixing: an allowed prefix must not launder a denied one that follows. ----

@test "allowed prefix followed by a denied one is still refused" {
    run is_bash_safe_command "FW_X=1 PATH=/tmp cat y"
    [ "$status" -ne 0 ]
}

# ---- Predicate-level tests: cheaper to diagnose than a full classify. ----

@test "_fw_env_prefix_is_denied: denies resolution-affecting names" {
    for n in PATH SHELL IFS ENV BASH_ENV SHELLOPTS LD_PRELOAD LD_LIBRARY_PATH \
             DYLD_INSERT_LIBRARIES PYTHONPATH PERL5OPT NODE_OPTIONS \
             GIT_SSH_COMMAND GIT_PAGER GIT_CONFIG_COUNT PAGER EDITOR VISUAL; do
        run _fw_env_prefix_is_denied "$n"
        [ "$status" -eq 0 ] || { echo "expected DENY for $n"; return 1; }
    done
}

@test "_fw_env_prefix_is_denied: allows ordinary names" {
    # Assert the predicate EXISTS before trusting a non-zero status from it.
    # Without this the test passes vacuously against any source that lacks the
    # function at all: `run` on a missing command yields 127, which is non-zero,
    # which reads identically to "allowed". Caught by running this file against
    # the pre-fix library as the control leg — it was the one denylist assertion
    # that came back green when nothing was implemented.
    declare -F _fw_env_prefix_is_denied >/dev/null || {
        echo "predicate _fw_env_prefix_is_denied is not defined"; return 1; }
    for n in FW_SWITCH_FOCUS FW_DEBUG FOO BAR MY_VAR GIT_COMMITTER_NAME \
             GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; do
        run _fw_env_prefix_is_denied "$n"
        [ "$status" -eq 1 ] || { echo "expected ALLOW (status 1) for $n, got $status"; return 1; }
    done
}

# ---- Structural: ONE implementation of the strip loop. Two copies of a security
# predicate is two chances to fix only one — which is the exact shape of the bug
# this file pins (the wrapper loop had its own copy of the regex). ----

@test "only one env-prefix strip implementation exists" {
    local src="${FW_SAFE_COMMANDS_SRC:-$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh}"
    # The strip regex must appear exactly once — inside the shared helper.
    local n
    n="$(grep -c '\[A-Za-z_\]\[A-Za-z0-9_\]\*=\[\^\[:space:\]\]' "$src" || true)"
    [ "$n" -eq 1 ]
}
