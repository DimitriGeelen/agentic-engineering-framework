#!/usr/bin/env bats
# T-1908: pin env-var prefix stripping in is_bash_safe_command.
#
# L-399 / T-1890 contracted FW_SWITCH_FOCUS=1 as a universal bypass mechanism
# (the env-var form works where --switch-focus flags can't, e.g. git commit).
# But the safe-command extractor's awk '{print $1}' returned the env-prefix
# as the base command — `FW_SWITCH_FOCUS=1 fw work-on T-X` was classified as
# unsafe because `FW_SWITCH_FOCUS=1` didn't match any case in the allowlist.
# Result: agent followed the documented bypass and got blocked anyway.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

@test "bare 'fw work-on T-X' is classified safe (control)" {
    run is_bash_safe_command "fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "single env-var prefix: 'FW_SWITCH_FOCUS=1 fw work-on T-X' is classified safe" {
    run is_bash_safe_command "FW_SWITCH_FOCUS=1 fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "multiple env-var prefixes: 'FOO=1 BAR=2 fw work-on T-X' is classified safe" {
    run is_bash_safe_command "FOO=1 BAR=2 fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "env-prefix + path-prefixed command: 'FW_SWITCH_FOCUS=1 bin/fw work-on T-X' is classified safe" {
    # sed 's|.*/||' should still strip the bin/ prefix after env-var stripping
    run is_bash_safe_command "FW_SWITCH_FOCUS=1 bin/fw work-on T-1907"
    [ "$status" -eq 0 ]
}

@test "env-prefix + fw doctor: 'FW_DEBUG=1 fw doctor' is classified safe" {
    run is_bash_safe_command "FW_DEBUG=1 fw doctor"
    [ "$status" -eq 0 ]
}

@test "env-prefix + git status: 'GIT_DIR=foo git status' is classified safe (read-only)" {
    run is_bash_safe_command "GIT_DIR=foo git status"
    [ "$status" -eq 0 ]
}

@test "no regression: unknown command 'mysecretcmd' still classified unsafe" {
    run is_bash_safe_command "mysecretcmd --do-stuff"
    [ "$status" -eq 1 ]
}

@test "no regression: env-prefix + unknown command still classified unsafe" {
    run is_bash_safe_command "FOO=1 mysecretcmd --do-stuff"
    [ "$status" -eq 1 ]
}

@test "env-var with embedded equals and quoted value: 'KEY=a=b cmd' still strips" {
    # KEY=a=b is a valid env-var assignment (value is 'a=b'). Strip should
    # still remove it and find the command after.
    run is_bash_safe_command "FOO=bar=baz fw work-on T-1"
    [ "$status" -eq 0 ]
}

@test "fw work-on T-X with leading whitespace + env prefix: still classified safe" {
    # Defensive — leading whitespace can creep in via shell composition
    run is_bash_safe_command "FW_SWITCH_FOCUS=1   fw work-on T-1907"
    [ "$status" -eq 0 ]
}
