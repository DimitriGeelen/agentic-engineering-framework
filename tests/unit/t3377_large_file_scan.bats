#!/usr/bin/env bats
# T-3377 — large-file scan_tree: behaviour pinned against a FIXTURE repo.
#
# scan_tree was rewritten to size-filter in bulk (one batched `stat` pass + an
# awk threshold cut) instead of forking `grep` and `stat` once per tracked file.
# At 17,270 tracked files the old shape cost ~35-50k process spawns, measured at
# user 19s / sys 49s and unfinished at a 60s timeout — which is why `fw doctor`,
# whose large-file check calls this inline, returned 124 instead of a verdict.
#
# The rewrite is supposed to be performance-only, so what needs pinning is that
# the REPORTING RULES did not move: which paths are named, at which threshold,
# in which order, and that the allowlist still exempts from BOTH levels.
#
# Everything here runs against a throwaway git repo built in setup(), with the
# thresholds set by env to small byte counts. No assertion touches the live
# corpus — no file counts, no real repo paths (T-3326: a live-count anchor rots
# under a moving corpus and goes red for reasons unrelated to the code).

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # PARITY CONTROL. These pin semantics the rewrite must NOT have changed, so
    # they are only meaningful if the PRE-FIX implementation satisfies them too.
    # Point the suite at the old source to check that both agree:
    #
    #   git show 949ed27a1:agents/git/lib/large-file-scan.sh > /tmp/old.sh
    #   chmod +x /tmp/old.sh
    #   FW_LARGE_FILE_SCAN_SRC=/tmp/old.sh bats tests/unit/t3377_large_file_scan.bats
    #
    # A failure THERE means the rewrite moved a reporting rule. Unlike a normal
    # control leg these assertions are expected to pass on both sides — the
    # defect fixed was cost, not behaviour, and behaviour is the invariant.
    SCANNER="${FW_LARGE_FILE_SCAN_SRC:-$FRAMEWORK_ROOT/agents/git/lib/large-file-scan.sh}"

    FIXTURE="$(mktemp -d)"
    git -C "$FIXTURE" init -q
    git -C "$FIXTURE" config user.email "t3377@test.local"
    git -C "$FIXTURE" config user.name  "T-3377 fixture"

    # Small, exact sizes beat real 10 MiB files: the thresholds are configurable,
    # so the fixture sets them low and the semantics under test are unchanged.
    export FW_LARGE_FILE_BLOCK_BYTES=2000
    export FW_LARGE_FILE_WARN_BYTES=1000

    mk() { head -c "$2" /dev/zero | tr '\0' 'x' > "$FIXTURE/$1"; }

    mk small.txt   500     # under warn  -> silent
    mk medium.txt  1500    # >= warn     -> [WARN]
    mk big.bin     3000    # >= block    -> [BLOCK]

    git -C "$FIXTURE" add -A
    git -C "$FIXTURE" commit -qm "fixture"
}

teardown() {
    [ -n "${FIXTURE:-}" ] && rm -rf "$FIXTURE"
}

run_scan() {
    run env PROJECT_ROOT="$FIXTURE" \
        FW_LARGE_FILE_BLOCK_BYTES="$FW_LARGE_FILE_BLOCK_BYTES" \
        FW_LARGE_FILE_WARN_BYTES="$FW_LARGE_FILE_WARN_BYTES" \
        "$SCANNER" scan-tree
}

@test "T-3377: file at/above block threshold is reported [BLOCK]" {
    run_scan
    [[ "$output" == *"[BLOCK] big.bin"* ]]
}

@test "T-3377: file between warn and block is reported [WARN]" {
    run_scan
    [[ "$output" == *"[WARN]  medium.txt"* ]]
}

@test "T-3377: file below warn threshold is reported not at all" {
    run_scan
    [[ "$output" != *"small.txt"* ]]
}

@test "T-3377: a block-level hit makes scan_tree exit non-zero" {
    run_scan
    [ "$status" -ne 0 ]
}

@test "T-3377: clean tree (nothing above warn) exits 0 and names nothing" {
    rm -f "$FIXTURE/medium.txt" "$FIXTURE/big.bin"
    git -C "$FIXTURE" add -A
    git -C "$FIXTURE" commit -qm "drop the large files"
    run_scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"[BLOCK]"* ]]
    [[ "$output" != *"[WARN]"* ]]
}

@test "T-3377: allowlist exempts from BLOCK, not merely from WARN" {
    # The ordering rewrite applies the allowlist AFTER the size cut. That is
    # only sound because an allowlisted path is exempt from both levels, so the
    # strongest level is the one worth pinning.
    printf 'big\\.bin\n' > "$FIXTURE/.large-file-allowlist"
    run_scan
    [[ "$output" != *"big.bin"* ]]
    [ "$status" -eq 0 ]
}

@test "T-3377: allowlist exempts a WARN-level path too" {
    printf 'medium\\.txt\n' > "$FIXTURE/.large-file-allowlist"
    run_scan
    [[ "$output" != *"medium.txt"* ]]
    [[ "$output" == *"[BLOCK] big.bin"* ]]
}

@test "T-3377: a tracked path missing from disk is skipped, not crashed on" {
    # git still lists it; `stat` produces no line for it. The old code reached
    # the same outcome via `stat ... || echo 0` followed by a zero-skip, so this
    # is a semantics-parity check, not a new behaviour.
    rm -f "$FIXTURE/big.bin"
    run_scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"big.bin"* ]]
    [[ "$output" == *"[WARN]  medium.txt"* ]]
}

@test "T-3377: report order follows git ls-files order" {
    # Order is part of the byte-identical claim against the pre-fix
    # implementation: xargs and awk are both order-preserving, and this pins
    # that rather than assuming it.
    head -c 1500 /dev/zero | tr '\0' 'x' > "$FIXTURE/aaa.txt"
    head -c 1500 /dev/zero | tr '\0' 'x' > "$FIXTURE/zzz.txt"
    git -C "$FIXTURE" add -A
    git -C "$FIXTURE" commit -qm "add ordering probes"
    run_scan
    local first_aaa first_zzz
    first_aaa="$(echo "$output" | grep -n "aaa.txt" | head -1 | cut -d: -f1)"
    first_zzz="$(echo "$output" | grep -n "zzz.txt" | head -1 | cut -d: -f1)"
    [ -n "$first_aaa" ] && [ -n "$first_zzz" ]
    [ "$first_aaa" -lt "$first_zzz" ]
}

@test "T-3377: a path containing spaces survives the stat/awk pipeline" {
    # The rewrite reads `size path` off one stat line, so the path is the read's
    # trailing field. A space in the name is the case that would break a naive
    # field split — and `.context/` in the real corpus does contain such names.
    head -c 1500 /dev/zero | tr '\0' 'x' > "$FIXTURE/has space.txt"
    git -C "$FIXTURE" add -A
    git -C "$FIXTURE" commit -qm "add spaced path"
    run_scan
    [[ "$output" == *"has space.txt"* ]]
}
