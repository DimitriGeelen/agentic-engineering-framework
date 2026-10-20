#!/usr/bin/env bats
#
# T-4509 (SECURITY, G-121): the read-only allowlist admitted awk on the argument that
# its only write form needs a literal `>`. awk also RUNS commands: system("…"),
# "cmd" | getline, print | "cmd", gawk's |& coprocess. Reported by ring20-dashboard
# (msg af2bbc85).
#
# Fix: agents/context/lib/safe-commands.sh _fw_awk_runs_command — options are a
# whitelist (-f/-E/-i/-l load code, -d/-D/-o/-p write files), and the program text is
# judged by lib/shell_write_scan.py awk_program_risk, which skips strings, regex
# literals and comments. Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
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

@test "T-4509: the probe's awk lines are NOT SAFE" {
    _refused "awk 'BEGIN{system(\"touch pwned\")}'" \
        "awk 'BEGIN{\"touch pwned\"|getline x}'" \
        "awk 'BEGIN{print \"d\"|\"cat\"}'"
}

@test "T-4509: printf to a pipe, coprocess, spaced system and gawk loading are NOT SAFE" {
    _refused "awk '{printf \"%s\", \$1 | \"sh\"}' F" "awk 'BEGIN{print \"x\" |& \"sh\"}'" \
        "awk 'BEGIN{system (\"x\")}'" "awk '@load \"x\"'" "awk '/[/]\"/ {print | \"sh\"}'" \
        "cat F | awk 'BEGIN{system(\"x\")}'"
}

@test "T-4509: a program the text does not show, or a code/file option, is NOT SAFE" {
    _refused 'awk -f P F' 'awk "$P" F' "awk -e 'BEGIN{system(\"x\")}'" \
        "awk -i inplace '{print}' F" "awk -p '{print}' F" "awk -o '{print}' F" \
        "awk --profile '{print}' F" "awk -'f' P F"
}

@test "T-4509: a string or regex that contains | or system is data" {
    _safe "awk '/a|b/' F" "awk '{print \"a|b\"}' F" "awk '\$1 == \"system\" {print}' F" \
        "awk '\$1 || \$2' F" "awk 'BEGIN { n = split(\$0, a, /,|;/) }'" \
        "awk '{print \$1/2 \" a|b\"}' F"
}

@test "T-4509: controls stay SAFE" {
    _safe "awk '{print \$1}' F" "awk -F: '{print \$1}' F" "awk -v n=2 'NR==n' F" \
        "awk '{x = \$1 / 2; print x}' F" 'git grep pattern' 'sed -n 1p F'
}

@test "T-4509: awk_program_risk directly" {
    run python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
for p in ("BEGIN{system(\"x\")}", "{\"x\"|getline}", "{print|\"x\"}", "{print \"a", "/a"):
    assert s.awk_program_risk(p), p
for p in ("{print $1}", "/a|b/", "$1 || $2", "{print \"|\"}", "# system(x) | y\n{print}"):
    assert s.awk_program_risk(p) is None, p
print("ok")' "$ROOT/lib"
    [ "$status" -eq 0 ]
    [ "$output" = ok ]
}
