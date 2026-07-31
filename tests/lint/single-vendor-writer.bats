#!/usr/bin/env bats
# T-1163/T-1184: Invariant test — single vendor writer
# lib/upgrade.sh step 4b and lib/update.sh must delegate to do_vendor (bin/fw),
# NOT maintain their own vendoring enumerations. This prevents T-1109-class bugs.
# Note: lib/upgrade.sh step 4c (global install sync to ~/.agentic-framework) is a
# DIFFERENT code path and intentionally has its own sync logic.
#
# T-1218: Self-vendor tests — upgrade.sh must sync lib/*.sh to .agentic-framework/
# before pushing to consumers (prevents T-1216-class stale vendored file bugs).

@test "lib/upgrade.sh does not have its own agent_dirs enumeration" {
    # The old code had: agent_dirs="task-create handover git healing..."
    run grep 'agent_dirs=' lib/upgrade.sh
    [ "$status" -ne 0 ]
}

@test "lib/upgrade.sh calls do_vendor for vendored script sync" {
    run grep 'do_vendor' lib/upgrade.sh
    [ "$status" -eq 0 ]
}

# Extract step 4b, bounded STRUCTURALLY on the next step header rather than on
# the named successor "4c." (832 T-312 class, swept in T-2696).
#
# The old bound was `/4b.*Vendored/,/4c\./`. Renaming the 4c header to
# `── 4c-shim: …` runs the sed range to EOF: the span grows from 36 lines to
# 806, and the presence assertion then passes on the string `do_vendor` inside
# a COMMENT ~650 lines further down. A header rename nobody would flag as risky
# turns this into a test that cannot fail — and it lands on prose, which a text
# match cannot tell from code (L-519).
#
# Bounding on `── Nx.` (any step header) means an inserted step ENDS the span
# instead of being swallowed by it. Widening now requires deleting every
# subsequent step header, which is not a thing that happens by accident.
_step_4b() {
    sed -n '/── 4b\./,/── [0-9][a-z]\?\./p' lib/upgrade.sh | sed '$d'
}

@test "lib/upgrade.sh step 4b span is bounded, not run-to-EOF" {
    # Total-vacuity guard. Without this, every assertion below could be
    # satisfied by content from an unrelated part of the file.
    local n; n=$(_step_4b | wc -l)
    [ "$n" -gt 5 ]    # found something
    [ "$n" -lt 120 ]  # …and it is a step, not the rest of the file
}

@test "lib/upgrade.sh step 4b delegates to do_vendor" {
    # Comments stripped first: the invariant is about the CALL, and the block
    # carries a T-1157 comment explaining the delegation that would satisfy a
    # naive grep on its own.
    _step_4b | grep -vE '^\s*#' | grep -q 'do_vendor'
}

@test "lib/upgrade.sh step 4b does not copy files itself" {
    # The other half of this test's own name, which it never used to check.
    # The invariant is "delegates, does not enumerate" — asserting only the
    # presence of do_vendor leaves an inline cp alongside it undetected.
    run bash -c "_step_4b() { sed -n '/── 4b\./,/── [0-9][a-z]\?\./p' lib/upgrade.sh | sed '\$d'; }; _step_4b | grep -vE '^\s*#' | grep -cE '(^|[;&|[:space:]])(cp|rsync|install)[[:space:]]'"
    [ "$output" = "0" ]
}

@test "lib/upgrade.sh step 4b comment references T-1157 collapse" {
    run grep 'T-1157.*Collapsed\|T-1157.*collapse\|collapse.*do_vendor' lib/upgrade.sh
    [ "$status" -eq 0 ]
}

# T-1184: lib/update.sh must also delegate to do_vendor (G-037)
@test "lib/update.sh does not have its own includes array" {
    run grep 'local includes=(' lib/update.sh
    [ "$status" -ne 0 ]
}

@test "lib/update.sh calls do_vendor for vendored file sync" {
    run grep 'do_vendor' lib/update.sh
    [ "$status" -eq 0 ]
}

# T-1218: Self-vendor mechanism tests
@test "lib/upgrade.sh has self-vendor step for .agentic-framework" {
    run grep 'T-1217.*Self-vendor\|self_vendor\|Self-vendor' lib/upgrade.sh
    [ "$status" -eq 0 ]
}

@test "lib/upgrade.sh self-vendor syncs lib/*.sh via glob not hardcoded list" {
    # Must use glob pattern (lib/"*.sh), not enumerated file names
    # The self-vendor block (T-1217) loops over _sv_src in lib/*.sh
    run grep '_sv_src.*lib/.*\*\.sh' lib/upgrade.sh
    [ "$status" -eq 0 ]
}

@test "lib/upgrade.sh self-vendor targets .agentic-framework" {
    run grep '_self_vendor.*\.agentic-framework\|self_vendor.*agentic-framework' lib/upgrade.sh
    [ "$status" -eq 0 ]
}
