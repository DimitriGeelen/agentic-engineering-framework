#!/usr/bin/env bats
# T-2298: --section structure no-per-file-fork regression net.
#
# Surface under test: T-1855 stale-arc block (audit.sh:716-790-ish) and
# T-2096 GO-scope-not-propagated block (audit.sh:1198-1295-ish), both
# refactored from per-task awk/grep forks to single python3 pre-scans.
#
# These tests pin the no-per-file-fork shape without trying to re-host
# the full audit (which needs a full project layout). They:
#   - Pin "exactly zero awk inside the per-task inner loop" via grep
#     against the extracted T-1855 block.
#   - Pin "exactly one python3 pre-scan" in each block.
#   - Pin that the task_arc_map / candidates / referenced_ids variable
#     names are present (signal that the batched pattern is the active
#     code path, not a vestigial comment).

load ../test_helper

AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

@test "t1: T-1855 block uses pre-computed task_arc_map (not per-task awk inner loop)" {
    # Extract from `# T-1855 (T-NEW-7)` to `# T-2169 (T-NEW-C`.
    local block
    block="$(awk '/^# T-1855 \(T-NEW-7\): Stale-arc/,/^# T-2169 \(T-NEW-C/' "$AUDIT_SH")"
    # Must reference the batched pre-scan variable
    echo "$block" | grep -q 'task_arc_map=' || { echo "task_arc_map= not present in T-1855 block"; return 1; }
    # Must NOT have an inner per-task awk fork on arc_id
    # (The original pattern: `ttag=$(awk '/^arc_id:/ ...' "$tf"`)
    if echo "$block" | grep -qE 'ttag=\$\(awk'; then
        echo "found old per-task awk fork pattern (ttag=\$(awk ...)) — refactor regressed"
        return 1
    fi
}

@test "t2: T-1855 block has exactly one python3 -c invocation" {
    local block
    block="$(awk '/^# T-1855 \(T-NEW-7\): Stale-arc/,/^# T-2169 \(T-NEW-C/' "$AUDIT_SH")"
    local n
    n="$(echo "$block" | grep -c 'python3 -c')"
    [ "$n" -eq 1 ] || { echo "expected 1 python3 -c in T-1855 block, got $n"; return 1; }
}

@test "t3: T-2096 block uses single python3 pre-scan (not per-task grep fan-out)" {
    # Extract from `# T-2096 (OBS-036` to `# Fabric drift detection`.
    local block
    block="$(awk '/^# T-2096 \(OBS-036/,/^# Fabric drift detection/' "$AUDIT_SH")"
    # Must reference batched pre-scan variable
    echo "$block" | grep -q 'go_scope_unprop_list=' || { echo "go_scope_unprop_list= not present in T-2096 block"; return 1; }
    # Must NOT have the old per-task grep fan-out pattern
    # (original: `grep -qE "^workflow_type: inception\$" "\$task_file" || continue`)
    if echo "$block" | grep -qE 'grep -qE.*workflow_type.*\$task_file'; then
        echo "found old per-task grep fan-out pattern — refactor regressed"
        return 1
    fi
    # Must NOT have the per-candidate grep -lE cross-file scan
    if echo "$block" | grep -qE 'grep -lE.*related_tasks.*\\\\b\$\{t_id\}'; then
        echo "found old per-candidate grep -lE cross-file scan — refactor regressed"
        return 1
    fi
}

@test "t4: T-2096 block has exactly one python3 -c invocation" {
    local block
    block="$(awk '/^# T-2096 \(OBS-036/,/^# Fabric drift detection/' "$AUDIT_SH")"
    local n
    n="$(echo "$block" | grep -c 'python3 -c')"
    [ "$n" -eq 1 ] || { echo "expected 1 python3 -c in T-2096 block, got $n"; return 1; }
}

@test "t5: audit.sh still syntactically valid (bash -n)" {
    run bash -n "$AUDIT_SH"
    [ "$status" -eq 0 ] || { echo "audit.sh failed bash -n: $output"; return 1; }
}
