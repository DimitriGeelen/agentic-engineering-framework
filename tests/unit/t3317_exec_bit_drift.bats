#!/usr/bin/env bats
# T-3317 / OBS-336 — exec-bit drift detector (lib/exec-bit-drift.sh).
#
# A worker rewrite of agents/audit/audit.sh dropped the executable bit (index
# 100755, on-disk 664); `fw audit` died exit 126 and the whole audit rail was
# silently dead. The shared helper compares git index mode against on-disk
# executability for tracked *.sh + bin/fw.
#
# Behaviour is pinned HERMETICALLY at helper level against fixture git repos in
# BATS_TEST_TMPDIR. The doctor/audit wiring is pinned at source level — running
# full `fw doctor` (~2min on this corpus) or the real audit inside a unit test
# is the anti-pattern T-3324/F7 names; the helper IS the predicate both
# surfaces render (G-079), so fixture tests on it cover the verdict logic.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FIX="$TEST_TEMP_DIR/fixture"
    mkdir -p "$FIX/bin" "$FIX/sub dir"
    git -C "$FIX" init -q
    git -C "$FIX" config user.email t3317@test.local
    git -C "$FIX" config user.name  "T-3317 fixture"

    printf '#!/bin/bash\necho good\n'  > "$FIX/good.sh"
    printf '#!/bin/bash\necho drift\n' > "$FIX/drifty.sh"
    printf '#!/bin/bash\necho sub\n'   > "$FIX/sub dir/nested.sh"
    printf '#!/bin/bash\necho fw\n'    > "$FIX/bin/fw"
    # Control: a .sh file added WITHOUT the exec bit — index mode 100644.
    printf '#!/bin/bash\necho plain\n' > "$FIX/plain.sh"
    # Control: a non-script 100755 file — outside the *.sh/bin/fw pathspec.
    printf 'not a script\n' > "$FIX/data.bin"
    chmod +x "$FIX/good.sh" "$FIX/drifty.sh" "$FIX/sub dir/nested.sh" "$FIX/bin/fw" "$FIX/data.bin"
    git -C "$FIX" add -A
    git -C "$FIX" commit -qm "T-3317 fixture"

    # The drift under test: index keeps 100755, working copy loses the bit.
    chmod -x "$FIX/drifty.sh"

    source "$FRAMEWORK_ROOT/lib/exec-bit-drift.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-3317: drifted file fires — named, rc=0" {
    run exec_bit_drifted_files "$FIX"
    [ "$status" -eq 0 ]
    [ "$output" = "drifty.sh" ]
}

@test "T-3317: control — 100644 non-executable plain.sh does NOT fire" {
    run exec_bit_drifted_files "$FIX"
    [[ "$output" != *plain.sh* ]]
}

@test "T-3317: control — 100755 non-.sh file outside pathspec does NOT fire when drifted" {
    chmod -x "$FIX/data.bin"
    run exec_bit_drifted_files "$FIX"
    [[ "$output" != *data.bin* ]]
}

@test "T-3317: clean tree passes — no output, rc=1" {
    chmod +x "$FIX/drifty.sh"
    run exec_bit_drifted_files "$FIX"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "T-3317: drifted bin/fw is caught (non-.sh but explicitly in pathspec)" {
    chmod -x "$FIX/bin/fw"
    run exec_bit_drifted_files "$FIX"
    [ "$status" -eq 0 ]
    [[ "$output" == *bin/fw* ]]
}

@test "T-3317: drifted path containing a space survives the tab-split" {
    chmod -x "$FIX/sub dir/nested.sh"
    run exec_bit_drifted_files "$FIX"
    [[ "$output" == *"sub dir/nested.sh"* ]]
}

@test "T-3317: deleted candidate is NOT reported as drift (chmod is the wrong remedy)" {
    chmod +x "$FIX/drifty.sh"
    rm "$FIX/good.sh"
    run exec_bit_drifted_files "$FIX"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "T-3317: FW_EXEC_BIT_REPO env override resolves the repo (hermetic hook)" {
    cd "$TEST_TEMP_DIR"   # NOT the fixture — only the env var points there
    FW_EXEC_BIT_REPO="$FIX" run exec_bit_drifted_files
    [ "$status" -eq 0 ]
    [ "$output" = "drifty.sh" ]
}

@test "T-3317: non-git dir is unenumerable — candidates rc=1, not an empty PASS set" {
    mkdir -p "$TEST_TEMP_DIR/notgit"
    # This host has a git work tree at / itself, so discovery must be ceilinged
    # or the "non-git" dir resolves into the enclosing repo.
    GIT_CEILING_DIRECTORIES="$TEST_TEMP_DIR" run exec_bit_candidates "$TEST_TEMP_DIR/notgit"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "T-3317: candidates enumerate index-100755 *.sh + bin/fw only" {
    run exec_bit_candidates "$FIX"
    [ "$status" -eq 0 ]
    [[ "$output" == *good.sh* ]]
    [[ "$output" == *drifty.sh* ]]
    [[ "$output" == *bin/fw* ]]
    [[ "$output" != *plain.sh* ]]
    [[ "$output" != *data.bin* ]]
}

# ── Source-level wiring pins (see header for why not full doctor/audit runs) ──

@test "T-3317: doctor wires the SHARED helper and is not quick-skipped" {
    grep -q 'lib/exec-bit-drift.sh' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'Exec-bit drift' "$FRAMEWORK_ROOT/bin/fw"
    # Cheap check: must run under --quick — no _doctor_quick_skip guard on it.
    ! grep -E '_doctor_quick_skip.*[Ee]xec-bit' "$FRAMEWORK_ROOT/bin/fw" || return 1
    # WARN surface names the one-line remedy.
    grep -q 'chmod +x \$_xbit_join' "$FRAMEWORK_ROOT/bin/fw"
}

@test "T-3317: audit wires the SAME helper as a FAIL, not a re-derived copy (G-079)" {
    grep -q 'lib/exec-bit-drift.sh' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -A6 'if _xbit_list=\$(exec_bit_drifted_files' "$FRAMEWORK_ROOT/agents/audit/audit.sh" | grep -q 'fail "Exec-bit drift'
    # G-079: exactly one implementation of the predicate — callers must not
    # carry their own ls-files/awk mode filter.
    ! grep -E '^[^#]*ls-files -s' "$FRAMEWORK_ROOT/agents/audit/audit.sh" || return 1
    ! grep -E 'ls-files -s.*100755' "$FRAMEWORK_ROOT/bin/fw"
}
