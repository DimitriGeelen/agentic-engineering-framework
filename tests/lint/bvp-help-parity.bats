#!/usr/bin/env bats
# T-3069: the bvp verb surface and its documentation must agree.
#
# Two errors pointing opposite ways, both live before this file existed:
# `estimate-cost` was fully implemented (lib/bvp.sh, four subverbs, its own --help,
# wired into cron) and appeared zero times in `fw bvp --help`; and CLAUDE.md named a
# `fw bvp rank` verb that does not exist, so following the documentation produced
# `ERROR: unknown verb 'rank'`.
#
# Both cost the same thing. A capability nobody can find is indistinguishable from
# one nobody built — our own register had recorded the cost half of BVP as unbuilt,
# and a peer project reached the identical wrong conclusion from theirs.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
}

@test "T-3069: every estimate-cost subverb the dispatcher accepts is mentioned in bvp --help" {
    # Positive control first: if the help block cannot be read at all, the
    # assertions below would pass vacuously against an empty string (L-616).
    help=$("$FW_ROOT/bin/fw" bvp --help 2>&1)
    [[ "$help" == *"fw bvp"* ]]
    [[ "$help" == *"--quadrant"* ]]

    # Deliberately NOT a substring match on the whole help text. A first attempt
    # asserted `*"estimate-cost"*` and survived a mutation that deleted both usage
    # lines, because the surrounding prose still said "see `fw bvp estimate-cost
    # --help`". Being mentioned is not being listed: the operator scans the usage
    # column, and a verb that only appears inside another entry's explanation is
    # exactly as undiscoverable as one that appears nowhere.
    #
    # So: require a USAGE LINE — leading whitespace, then the invocation.
    echo "$help" | grep -qE '^[[:space:]]+fw bvp estimate-cost ' \
        || { echo "no usage line for 'fw bvp estimate-cost' in bvp --help"; return 1; }

    # And require the sweep form specifically, on a usage line of its own: the
    # single-task form alone leaves the corpus-wide path invisible, which is the
    # path that actually populates the COST column.
    echo "$help" | grep -qE '^[[:space:]]+fw bvp estimate-cost .*sweep' \
        || { echo "no usage line covering the sweep form"; return 1; }
}

@test "T-3069: estimate-cost is still dispatched, so the help entry is not aspirational" {
    # Guards the opposite failure to the one above: documenting a verb that has
    # been removed is the CLAUDE.md 'fw bvp rank' error in a new place.
    grep -q '\[ "${1:-}" = "estimate-cost" \]' "$FW_ROOT/lib/bvp.sh"
}

@test "T-3069: CLAUDE.md does not name a bvp verb the dispatcher would reject" {
    # `fw bvp rank` was documented for months. Ranking is the bare `fw bvp`.
    ! grep -q 'fw bvp rank' "$FW_ROOT/CLAUDE.md"
}
