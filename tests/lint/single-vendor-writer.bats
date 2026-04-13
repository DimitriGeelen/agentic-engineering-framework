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

@test "lib/upgrade.sh step 4b uses do_vendor not inline cp" {
    # Extract step 4b block and verify it calls do_vendor, not cp
    # Step 4b starts with "4b. Vendored framework scripts" and ends before "4c."
    step4b=$(sed -n '/4b.*Vendored/,/4c\./p' lib/upgrade.sh)
    echo "$step4b" | grep -q 'do_vendor'
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
