#!/usr/bin/env bats
# T-5114 — the first real Proxmox run (2026-11-13) lost every phase: guest-run.sh chowned the
# raw log (mktemp in /tmp) to testhost, but root's tee writes it, and Debian's
# fs.protected_regular refuses root an O_CREAT open of another user's file in sticky /tmp.
# tee wrote stdout only and exited 1 (pipefail), checks.log was empty, no phases parsed.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    G="$ROOT/agents/testhost/guest-run.sh"
}

@test "T-5114: guest-run never hands the raw log to testhost" {
    # every chown line in the script, joined: none may name raw_log
    run grep -nE '^[[:space:]]*chown ' "$G"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q 'raw_log'
}

@test "T-5114: the raw log is written by tee outside runuser (so root must own it)" {
    grep -qE '\| tee "\$raw_log"' "$G"
    ! grep -qE 'runuser[^|]*tee "\$raw_log"' "$G"
}

@test "T-5114: failure mode — root's tee into another user's /tmp file fails under protected_regular" {
    [ "$(id -u)" -eq 0 ] || skip "needs root"
    pr=$(sysctl -n fs.protected_regular 2>/dev/null || echo 0)
    [ "$pr" -ge 1 ] || skip "fs.protected_regular is off here"
    id nobody >/dev/null 2>&1 || skip "no 'nobody' user"
    f=$(mktemp /tmp/t5114.XXXXXX)
    chown nobody "$f"
    run bash -c "echo x | tee '$f' >/dev/null"
    rm -f "$f"
    [ "$status" -ne 0 ]
    g=$(mktemp /tmp/t5114.XXXXXX)          # root-owned: the fixed layout
    run bash -c "echo x | tee '$g' >/dev/null"
    out=$(cat "$g"); rm -f "$g"
    [ "$status" -eq 0 ] && [ "$out" = x ]
}
