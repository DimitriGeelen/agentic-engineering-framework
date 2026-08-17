#!/usr/bin/env bats
# T-3062: the pre-push gate must stay inside the window the push gives it.
#
# The pre-push hook runs `audit.sh --section structure`. The handover bounds a
# push at FW_HANDOVER_PUSH_TIMEOUT seconds. When the gate outgrows that bound
# the push is not blocked — it is KILLED, partway through, and both outcomes
# land in the same warning branch in handover.sh. That is what makes this class
# invisible: seven commits sat unpushed across four sessions and every session
# reported the same single non-blocking WARNING line.
#
# The measured cause was one whole-tracked-tree scan pair (T-1845's secret scan
# and large-file gate, 283s of a 347s section) sitting in `structure`, which is
# a per-push horizon, when T-1845 had asked for the daily audit horizon. Nobody
# chose that; the checks accreted into a section whose contract they never knew
# about, and no assertion held the two facts next to each other.
#
# These are static checks on purpose — they run inside the audit itself (via
# check_invariant_suite), so they must stay cheap. The wall-clock measurement
# lives in tests/unit/t3062_prepush_runtime.bats, which is not in that path.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    AUDIT="$FW_ROOT/agents/audit/audit.sh"
    HANDOVER="$FW_ROOT/agents/handover/handover.sh"
}

# Print the line range of the `structure` section: from its `should_run_section
# "structure"` guard to the `fi # end structure` that closes it.
structure_range() {
    local start end
    start=$(grep -n 'if should_run_section "structure"; then' "$AUDIT" | head -1 | cut -d: -f1)
    end=$(grep -n '^fi # end structure' "$AUDIT" | head -1 | cut -d: -f1)
    [ -n "$start" ] && [ -n "$end" ] || return 1
    printf '%s %s\n' "$start" "$end"
}

@test "T-3062: the structure section's boundaries are still findable" {
    # Positive control. Every other test here slices audit.sh by these two
    # markers; if a refactor renames either, the slice comes back empty and the
    # scan-tree assertions below pass by finding nothing in nothing. A green
    # suite would then mean the opposite of what it claims.
    run structure_range
    [ "$status" -eq 0 ]

    read -r start end <<< "$output"
    [ "$end" -gt "$start" ]
    # Sanity: the section is substantial, not a stub left behind by a bad edit.
    [ $(( end - start )) -gt 200 ]
}

@test "T-3062: no whole-tree scan runs inside the per-push structure section" {
    read -r start end <<< "$(structure_range)"
    slice=$(sed -n "${start},${end}p" "$AUDIT")

    # Positive control for the slice itself: a known structure check must be in
    # it, otherwise `grep -c scan-tree` returning 0 proves nothing.
    echo "$slice" | grep -q 'Cron registry in sync' \
        || { echo "slice does not contain a known structure check — extraction is wrong"; false; }

    hits=$(echo "$slice" | grep -c 'scan-tree' || true)
    if [ "$hits" -ne 0 ]; then
        echo "A whole-tracked-tree scan is back inside \`structure\`:"
        echo "$slice" | grep -n 'scan-tree'
        echo ""
        echo "\`structure\` is what the pre-push hook runs on EVERY push."
        echo "A scan-tree costs O(repo) and pushed this section to 347s once"
        echo "already (T-3062). Whole-tree scans belong in the \`tree\` section,"
        echo "which the daily full audit still runs."
        false
    fi
}

@test "T-3062: the tree section exists and still holds both scanners" {
    # The other half of the split. Moving the scanners out of `structure` is
    # only correct if they kept running somewhere — otherwise this "fix" is a
    # silent removal of two security gates, which is strictly worse than slow.
    grep -q 'if should_run_section "tree"; then' "$AUDIT"
    grep -q '^fi # end tree' "$AUDIT"

    start=$(grep -n 'if should_run_section "tree"; then' "$AUDIT" | head -1 | cut -d: -f1)
    end=$(grep -n '^fi # end tree' "$AUDIT" | head -1 | cut -d: -f1)
    slice=$(sed -n "${start},${end}p" "$AUDIT")

    # Assert the scanners are INVOKED, not merely named. Matching the variable
    # name alone passes for `SECRET_SCANNER_DISABLED=...` — caught by mutation:
    # a rename that switches a gate off reads as a gate that is still there.
    echo "$slice" | grep -q 'secret-scan\.sh' \
        || { echo "secret scan is not invoked in the tree section — dropped, not moved"; false; }
    echo "$slice" | grep -q 'large-file-scan\.sh' \
        || { echo "large-file gate is not invoked in the tree section — dropped, not moved"; false; }
    [ "$(echo "$slice" | grep -c 'scan-tree')" -eq 2 ] \
        || { echo "expected both scanners to run scan-tree in the tree section"; false; }
}

@test "T-3062: the push timeout leaves headroom above the pre-push gate" {
    # The two numbers this class is about, asserted against each other rather
    # than each being separately plausible.
    default=$(grep -oP '_push_timeout="\$\{FW_HANDOVER_PUSH_TIMEOUT:-\K[0-9]+' "$HANDOVER" | head -1)
    [ -n "$default" ] || { echo "could not read the push timeout default"; false; }

    # Measured post-split cost of `--section structure` on this repo is ~59s.
    # The floor is deliberately well above it: a bound that only just clears
    # the current measurement re-arms the moment any check grows, which is the
    # exact failure being fixed.
    [ "$default" -ge 180 ] \
        || { echo "push timeout default is ${default}s; the pre-push gate alone measures ~59s"; false; }
}

@test "T-3062: the pre-push hook runs a scoped section, not the full audit" {
    hook="$FW_ROOT/.git/hooks/pre-push"
    [ -f "$hook" ] || skip "pre-push hook not installed in this checkout"

    grep -q -- '--section structure' "$hook" \
        || { echo "pre-push hook no longer scopes the audit; a full audit here is minutes"; false; }
}
