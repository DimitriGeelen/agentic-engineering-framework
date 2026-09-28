#!/usr/bin/env bats
# T-3545 / OBS-467 — a module header must not assert the opposite of its own code.
#
# `lib/branch-hygiene.sh`'s header read "Judged against TARGET = origin/master
# when present, else master" for as long as the code did not: T-3188 changed the
# resolution chain to prefer `origin/$FW_DEV_BRANCH` (default `bleeding-edge`)
# and left master only as the fallback for a master-only consumer.
#
# That is not a cosmetic drift. Under the release train (CLAUDE.md §Release-Train
# Branch Model) master lags deliberately, so "landings are judged against master"
# licenses exactly the wrong remediation — and the header is the only interface a
# reader has before they decide to trust the function. The findings this rail
# emits decide whether branches get deleted.
#
# The subject under test IS text, which is why grepping text is the right
# instrument here rather than the proxy it usually is. What the tests pin is the
# RELATIONSHIP between two texts: the order of refs the code actually tries, and
# the order the header claims.

load ../test_helper

BH="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
WT="$FRAMEWORK_ROOT/lib/worktree.sh"

setup() {
    [ -f "$BH" ] || skip "lib/branch-hygiene.sh not present"
    TEST_ROOT="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

# module_header FILE — the leading comment block, up to the first line that is
# neither a comment nor blank. That is the part a reader meets first.
module_header() {
    awk '/^[[:space:]]*#/ || /^[[:space:]]*$/ {print; next} {exit}' "$1"
}

# first_resolved_ref FILE — the branch named by the FIRST `rev-parse --verify`
# in fw_branch_hygiene's resolution chain, i.e. the comparand the code actually
# prefers.
first_resolved_ref() {
    awk '/^fw_branch_hygiene\(\) \{/{f=1} f && /rev-parse --verify/{print; exit}' "$1"
}

@test "the code prefers the DEV branch as its comparand, not master" {
    run first_resolved_ref "$BH"
    [ -n "$output" ]
    echo "$output" | grep -q '_bh_dev'
    ! echo "$output" | grep -q 'origin/master'
}

@test "the header does not claim master is the primary target" {
    run module_header "$BH"
    [ -n "$output" ]
    # The exact false sentence this task removed, and any re-phrasing of it.
    ! echo "$output" | grep -qi 'Judged against TARGET = origin/master when present'
    ! echo "$output" | grep -qiE '^#[[:space:]]*Judged against[^.]*origin/master[^.]*\.$'
}

@test "the header names the dev branch it actually resolves against" {
    run module_header "$BH"
    echo "$output" | grep -q 'FW_DEV_BRANCH'
    echo "$output" | grep -q 'bleeding-edge'
}

@test "the header says WHY master cannot be the comparand, not merely that it is not" {
    # A header that swaps one branch name for another teaches nothing; the next
    # reader needs the release-train reason or they will 'fix' it back.
    run module_header "$BH"
    echo "$output" | grep -qi 'release train'
    echo "$output" | grep -qi 'master-only consumer'
}

@test "master survives in the header ONLY as the documented fallback" {
    run module_header "$BH"
    # It must still be mentioned — a master-only consumer is a real supported
    # shape and dropping it would make the header wrong in the other direction.
    echo "$output" | grep -q 'origin/master'
}

@test "CONTROL: the parity check fails against the pre-T-3188 header" {
    # Without this, every assertion above could be passing vacuously — e.g. if
    # module_header returned nothing. Reconstruct the old header over the
    # current code and assert the check goes red.
    cp "$BH" "$TEST_ROOT/old.sh"
    python3 - "$TEST_ROOT/old.sh" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
start = t.index("# Judged against TARGET = the DEV branch")
end = t.index("# tests/unit/t3545_branch_hygiene_header_parity.bats, which exists to stop them.")
end = t.index("\n", end) + 1
p.write_text(t[:start] + "# Judged against TARGET = origin/master when present, else master. Repos with\n"
                         "# no master lineage produce no findings (nothing to judge against).\n" + t[end:])
PY
    header=$(module_header "$TEST_ROOT/old.sh")
    [ -n "$header" ]
    # The restored header trips the very assertion the real one passes.
    echo "$header" | grep -qi 'Judged against TARGET = origin/master when present'
    # ...while the code underneath is unchanged and still dev-first. That
    # contradiction is exactly what this suite exists to catch.
    run first_resolved_ref "$TEST_ROOT/old.sh"
    echo "$output" | grep -q '_bh_dev'
}

@test "worktree.sh's trunk header does not imply a worktree lands on master" {
    [ -f "$WT" ] || skip "lib/worktree.sh not present"
    block=$(awk '/^# Resolve the TRUNK ref/{f=1} f{print} f&&/^[a-z_]+\(\) \{/{exit}' "$WT")
    [ -n "$block" ]
    echo "$block" | grep -q 'bleeding-edge'
    echo "$block" | grep -qi 'never on master'
}

@test "no behaviour changed: the divergence comparand is still resolved dev-first" {
    chain=$(awk '/^fw_branch_divergence\(\) \{/{f=1} f && /rev-parse --verify/{print; exit}' "$BH")
    [ -n "$chain" ]
    echo "$chain" | grep -q '_bh_dev'
}
