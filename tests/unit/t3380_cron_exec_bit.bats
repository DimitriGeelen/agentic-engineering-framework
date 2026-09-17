#!/usr/bin/env bats
# T-3380 — a script the deployed crontab execs DIRECTLY must be executable.
#
# Observed 2026-09-17. agents/monitor/liveness-check.sh was committed 100644.
# Cron invoked it every minute (plus @reboot) for 34 days: 13,680 CRON lines in
# syslog, every one answered "Permission denied", and the script produced no
# output at all from 2026-08-14 onward. That script is the rail that samples
# Watchtower liveness — so when a host reboot at 17:09:04 killed Watchtower, the
# outage ran 5h35m with nothing reporting it, and was found only because a
# human-review handoff could not reach a server.
#
# The T-3317 exec-bit parity check could not see it. Its candidate set is
# "files the git index marks 100755", so a file committed 100644 is not examined
# at all — the audit printed "Exec-bit parity: every 100755-indexed script is
# executable on disk" over 60 files while a scheduled job was dead. That PASS is
# true and answers a narrower question than the reader hears (T-3105 class).
#
# The false-positive guard is load-bearing and is pinned here: a first pass that
# ignored the interpreter reported 50 broken paths across this host's crontabs,
# of which exactly 1 was real. `python3 foo.py` needs no exec bit.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    CRONTAB="$TEST_TEMP_DIR/agentic-audit-fixture"
    SCRIPT="$TEST_TEMP_DIR/sampler.sh"
    printf '#!/usr/bin/env bash\necho sampled\n' > "$SCRIPT"
    PREDICATE="$FRAMEWORK_ROOT/lib/cron_exec_bit.py"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# /etc/cron.d syntax carries a USER field between schedule and command.
_cron_line() {
    printf '* * * * * root cd "%s" && %s 2>&1 | logger -t agentic-cron\n' \
        "$TEST_TEMP_DIR" "$1" > "$CRONTAB"
}

@test "the incident: a directly-invoked non-executable script is reported NOEXEC" {
    chmod 644 "$SCRIPT"
    _cron_line "$SCRIPT"

    run python3 "$PREDICATE" "$CRONTAB"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOEXEC"* ]]
    [[ "$output" == *"$SCRIPT"* ]]
}

@test "control leg: the SAME crontab is clean once the exec bit is restored" {
    chmod 644 "$SCRIPT"
    _cron_line "$SCRIPT"
    run python3 "$PREDICATE" "$CRONTAB"
    [[ "$output" == *"NOEXEC"* ]]   # red first — else the green below proves nothing

    chmod +x "$SCRIPT"
    run python3 "$PREDICATE" "$CRONTAB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "an interpreter in front means the exec bit is irrelevant — not reported" {
    chmod 644 "$SCRIPT"
    _cron_line "python3 $SCRIPT"

    run python3 "$PREDICATE" "$CRONTAB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "bash-prefixed invocation is likewise not reported" {
    chmod 644 "$SCRIPT"
    _cron_line "bash $SCRIPT"

    run python3 "$PREDICATE" "$CRONTAB"
    [ -z "$output" ]
}

@test "a relative fragment following a shell variable is not treated as a path" {
    _cron_line '"$MONITOR_DIR"/check-canary-aliveness.sh'

    run python3 "$PREDICATE" "$CRONTAB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "an absolute path that does not exist is reported MISSING" {
    _cron_line "$TEST_TEMP_DIR/never-created.sh"

    run python3 "$PREDICATE" "$CRONTAB"
    [[ "$output" == *"MISSING"* ]]
    [[ "$output" == *"never-created.sh"* ]]
}

@test "@reboot lines are parsed — their USER field sits in a different column" {
    chmod 644 "$SCRIPT"
    printf '@reboot root cd "%s" && LIVENESS_BOOT_MARKER=1 %s\n' \
        "$TEST_TEMP_DIR" "$SCRIPT" > "$CRONTAB"

    run python3 "$PREDICATE" "$CRONTAB"
    [[ "$output" == *"NOEXEC"* ]]
    [[ "$output" == *"$SCRIPT"* ]]
}

@test "commented-out lines are ignored" {
    chmod 644 "$SCRIPT"
    printf '# * * * * * root %s\n' "$SCRIPT" > "$CRONTAB"

    run python3 "$PREDICATE" "$CRONTAB"
    [ -z "$output" ]
}

@test "--count reports how many scripts were examined, not how many are broken" {
    chmod +x "$SCRIPT"
    printf '* * * * * root %s\n@reboot root python3 %s/other.py\n' \
        "$SCRIPT" "$TEST_TEMP_DIR" > "$CRONTAB"

    run python3 "$PREDICATE" --count "$CRONTAB"
    [ "$status" -eq 0 ]
    # one direct invocation; the python3-prefixed one is not a candidate
    [ "$output" = "1" ]
}
