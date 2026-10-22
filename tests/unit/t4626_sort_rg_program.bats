#!/usr/bin/env bats
#
# T-4626 (SECURITY, G-121): the read-only allowlist admitted `sort` after checking only
# for -o, and `rg` by name. sort --compress-program=CMD runs CMD when it spills; rg
# --pre CMD runs CMD per searched file and --hostname-bin CMD runs it once. Reported by
# ring20-dashboard round 2 (msg 9e201103).
#
# Fix: agents/context/lib/safe-commands.sh _fw_option_runs_program — judged on the
# dequoted words (_fw_option_words); RIPGREP_CONFIG_PATH joins the env-prefix denylist.
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

@test "T-4626: the probe's sort and rg lines are NOT SAFE" {
    _refused "sort --compress-program=touch F" "rg --pre touch x" "rg --pre=touch x"
}

@test "T-4626: sort --compress-program abbreviations and separate value are NOT SAFE" {
    _refused "sort --compress-program touch F" "sort --co=touch F" "sort --compress=sh F" \
        "sort -n --compress-p touch F" "cat F | sort --compress-program=gzip"
}

@test "T-4626: rg --hostname-bin and an rg config path are NOT SAFE" {
    _refused "rg --hostname-bin=touch x" "rg --hostname-bin touch x" \
        "RIPGREP_CONFIG_PATH=/tmp/rc rg foo" "rg -n foo && rg --pre sh x"
}

@test "T-4626: quoted or expanded spellings are NOT SAFE" {
    _refused "sort '--compress-program=touch' F" "sort --compress-progr\"am=x\" F" \
        'sort "$P" F' "rg '--pre' touch x" "rg --{pre,x} touch x" 'rg "$O" x'
}

@test "T-4626: ordinary sort and rg and the G-121 controls stay SAFE" {
    _safe "sort -n F" "sort -k2 -t, F" "sort --check F" "sort -u F" "cat F | sort | uniq -c" \
        "rg pattern" "rg -n --pre-glob '*.x' foo" "rg -l 'T-4626' tests" "rg -- --pre x" \
        "grep -r foo ." "git grep -n foo"
}
