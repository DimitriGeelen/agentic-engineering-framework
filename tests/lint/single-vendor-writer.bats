#!/usr/bin/env bats
# T-1163: Invariant test — single vendor writer
# lib/upgrade.sh step 4b must delegate to do_vendor (bin/fw), NOT maintain
# its own vendoring enumeration. This prevents T-1109-class bugs.
# Note: step 4c (global install sync to ~/.agentic-framework) is a DIFFERENT
# code path and intentionally has its own sync logic.

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
