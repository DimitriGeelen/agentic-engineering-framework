#!/usr/bin/env bats
# T-4691: fw upgrade's advisory doctor step reported 141 (SIGPIPE) while a
# standalone fw doctor exited 0 (050 field report).
#
# Root cause: do_doctor (bin/fw, errexit+pipefail) printed bounded previews with
# `printf … | head -N | sed …`. head exits after N lines; when the list is larger
# than one write (right after an upgrade the Watchtower-stale list names every
# rewritten web/ file), printf takes SIGPIPE and errexit ends doctor with 141.
# Racy: measured 69/200 at 26 KB.
#
# Two legs: the advisory reports doctor's OWN exit code (stubbed doctor), and
# do_doctor carries no `| head -N | sed` statement (static, read from bin/fw).

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    CONSUMER="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$CONSUMER/.agentic-framework/bin"
    FRAMEWORK_ROOT="$BATS_TEST_TMPDIR/upstream"
    mkdir -p "$FRAMEWORK_ROOT/bin"
    export FRAMEWORK_ROOT
    BOLD=""; NC=""; YELLOW=""; GREEN=""
    source "$FW_ROOT/lib/upgrade.sh"
}

_stub_doctor() {  # $1 = exit code; prints > 64 KiB first
    printf '#!/usr/bin/env bash\nfor i in $(seq 1 3000); do echo "doctor line $i padding padding padding"; done\nexit %s\n' "$1" \
        > "$CONSUMER/.agentic-framework/bin/fw"
    chmod +x "$CONSUMER/.agentic-framework/bin/fw"
}

@test "clean doctor with > 64 KiB output: advisory reports PASS (exit 0)" {
    _stub_doctor 0
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"doctor PASS (exit 0)"* ]]
    [[ "$output" != *"exited"* ]]
    # preview stays bounded to 20 lines
    [[ "$output" == *"doctor line 20 "* ]]
    [[ "$output" != *"doctor line 21 "* ]]
}

@test "failing doctor: advisory reports doctor's own exit code" {
    _stub_doctor 3
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"doctor exited 3 "* ]]
}

@test "doctor exiting 141 is named as a SIGPIPE inside doctor" {
    _stub_doctor 141
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"doctor exited 141 (SIGPIPE inside doctor"* ]]
}

@test "do_doctor has no 'head -N | sed' preview pipeline (SIGPIPE under errexit)" {
    local hits
    hits=$(awk '/^do_doctor\(\) \{/ {in_d=1} in_d && /^}/ {in_d=0} in_d && /\| *head -[0-9]+ *\| *sed/' "$FW_ROOT/bin/fw")
    [ -z "$hits" ] || { echo "$hits"; false; }
}

@test "the awk preview form does not SIGPIPE its producer under pipefail" {
    run bash -c 'set -eo pipefail; x=$(seq 1 20000); for k in $(seq 1 50); do printf "%s\n" "$x" | awk "NR<=3 {print \"  - \" \$0}" >/dev/null; done; echo done'
    [ "$status" -eq 0 ]
    [[ "$output" == *done* ]]
}
