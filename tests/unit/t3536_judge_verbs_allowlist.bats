#!/usr/bin/env bats
# T-3536: the judge/review verbs shipped 2026-09-28 are read-only and must be
# reachable at focus-null; their write siblings must not be.
#
# WHY THIS EXISTS AS A TEST AND NOT A ONE-OFF CHECK
#
# T-3096 derived the fw read-only allowlist by classifying every arm of bin/fw's
# dispatch case. That derivation is a SNAPSHOT. `fw bvp judge` (T-3526),
# `fw arc judge-driver` (T-3527) and `fw arc review-driver` (T-3429) all shipped
# afterwards, so they were absent by omission rather than by decision — and the
# omission is invisible, because a gated read looks exactly like a correctly
# gated write until someone tries it at focus-null.
#
# The negative controls are the load-bearing half. An allowlist test that only
# asserts things PASS cannot tell a correct rule from one that allows
# everything — the same false-green shape as a length threshold standing in for
# a sufficiency check (OBS-560). Each read added here is paired with a sibling
# that writes and must stay refused.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/agents/context/lib/safe-commands.sh"
}

# ── the reads: verbs whose modules contain zero write calls ────────────────────

@test "t3536: fw bvp judge is allowed (lib/bvp_judge.py: 'Never writes anything')" {
    is_bash_safe_command "bin/fw bvp judge T-3471"
}

@test "t3536: fw arc judge-driver is allowed (lib/arc.sh:1971 documents it read-only)" {
    is_bash_safe_command "bin/fw arc judge-driver arc-020 --all"
}

@test "t3536: fw arc review-driver is allowed (T-3429 static check)" {
    is_bash_safe_command "bin/fw arc review-driver arc-020 --all --dry-run"
}

@test "t3536: bare fw bvp ranking still allowed (not narrowed by this change)" {
    is_bash_safe_command "bin/fw bvp"
}

@test "t3536: fw arc list still allowed (not narrowed by this change)" {
    is_bash_safe_command "bin/fw arc list"
}

# ── negative controls: the write siblings, which share a verb prefix ───────────

@test "t3536 CONTROL: fw bvp confirm stays gated (writes bvp_scores:)" {
    run is_bash_safe_command "bin/fw bvp confirm T-3471"
    [ "$status" -ne 0 ]
}

@test "t3536 CONTROL: fw bvp estimate-cost stays gated (writes cost_estimate:)" {
    run is_bash_safe_command "bin/fw bvp estimate-cost T-3471"
    [ "$status" -ne 0 ]
}

@test "t3536 CONTROL: fw arc approve-driver stays gated (mutates scoped_drivers[])" {
    run is_bash_safe_command "bin/fw arc approve-driver arc-020 foo --weight 5"
    [ "$status" -ne 0 ]
}

@test "t3536 CONTROL: fw arc set-scoped-weight stays gated (mutates the arc YAML)" {
    run is_bash_safe_command "bin/fw arc set-scoped-weight arc-020 foo 5"
    [ "$status" -ne 0 ]
}

@test "t3536 CONTROL: fw arc remove-driver stays gated (mutates the arc YAML)" {
    run is_bash_safe_command "bin/fw arc remove-driver arc-020 foo"
    [ "$status" -ne 0 ]
}

@test "t3536 CONTROL: fw arc close stays gated (closure is a human decision, T-1671)" {
    run is_bash_safe_command "bin/fw arc close arc-020 --demo none"
    [ "$status" -ne 0 ]
}

# ── the chain rule must survive: one unsafe segment poisons the chain ──────────

@test "t3536: a chain of allowed reads is safe" {
    is_bash_safe_command "bin/fw bvp judge T-3471 && bin/fw arc judge-driver arc-020 --all"
}

@test "t3536 CONTROL: an allowed read chained with a write is NOT safe" {
    run is_bash_safe_command "bin/fw bvp judge T-3471 && bin/fw bvp confirm T-3471"
    [ "$status" -ne 0 ]
}
