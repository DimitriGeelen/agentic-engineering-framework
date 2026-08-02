#!/usr/bin/env bats
# T-2727 — `fw init` must validate the tree it leaves behind, not an intermediate
# state that no longer exists by the time it returns.
#
# Origin: validation ran ~114 lines before the onboarding tasks were seeded.
# `func-tasks` (parses .tasks/active/, checks frontmatter) is guarded by
# `active_tasks > 0`, so on a fresh init it saw an empty directory, did not run,
# and — because the guard sits outside the `total++` — was not counted either.
# Absent from numerator and denominator, printing nothing: a check that never ran
# was indistinguishable from a check that does not exist.
#
#   fw init <fresh>         → "41/42 checks OK", no func-tasks row
#   fw validate-init <same> → ✓ func-tasks  5 onboarding tasks ...
#
# 832 rail 382 named this shape: not a check that always fails, but one whose
# WITNESSING state is unreachable for the instrument that would witness it —
# "a missing fixture and an impossible one look the same".

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    FW="$FRAMEWORK_ROOT/bin/fw"
    TEST_TEMP_DIR="$(mktemp -d -t fw-initorder-XXXXXX)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_init_out() {
    local proj="$1"
    mkdir -p "$proj"
    "$FW" init "$proj" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
}

@test "T-2727: func-tasks is evaluated during fw init, not only standalone" {
    local out; out=$(_init_out "$TEST_TEMP_DIR/fresh")
    echo "$out"
    [[ "$out" == *"func-tasks"* ]]
}

@test "T-2727: the onboarding-task check is counted in init's own denominator" {
    local out; out=$(_init_out "$TEST_TEMP_DIR/count")
    local total
    total=$(printf '%s\n' "$out" | grep -E "Validation" | head -1 \
            | sed -n 's/.*[^0-9]\([0-9][0-9]*\) checks.*/\1/p')
    echo "total=$total"
    # 42 was the pre-fix denominator; the check must be inside it, not beside it.
    [ -n "$total" ] && [ "$total" -ge 43 ]
}

@test "T-2727: validation runs AFTER the onboarding tasks are seeded" {
    # The structural pin. Presence of the row is a consequence; the ordering is
    # the invariant, and it is what a future edit would silently undo.
    local out; out=$(_init_out "$TEST_TEMP_DIR/order")
    local seed_line val_line
    seed_line=$(printf '%s\n' "$out" | grep -n "onboarding tasks (" | head -1 | cut -d: -f1)
    val_line=$(printf '%s\n' "$out" | grep -n "^Validating\.\.\." | head -1 | cut -d: -f1)
    echo "seed=$seed_line validate=$val_line"
    [ -n "$seed_line" ] && [ -n "$val_line" ]
    [ "$val_line" -gt "$seed_line" ]
}

@test "T-2727: the check has teeth in the init path — a malformed task fails init's validation" {
    # Presence in the output is not the claim. This seeds a task whose frontmatter
    # cannot parse and requires that `fw init`'s OWN validation names it. Without
    # this, moving the block could satisfy every other assertion here while the
    # check silently passed on everything.
    #
    # Scope note: this test and the control below use a PRE-EXISTING task, so
    # `active_tasks > 0` holds even at the old early-validation point — they stay
    # green if the ordering is reverted. They pin the check's teeth, not the
    # ordering. Tests 1-3 are the ordering guards; verified by reverting the move
    # and observing exactly those three go red.
    local proj="$TEST_TEMP_DIR/teeth"
    mkdir -p "$proj/.tasks/active"
    printf -- '---\nid: T-001\nthis is not: [valid\n---\n# broken\n' \
        > "$proj/.tasks/active/T-001-broken.md"
    local out; out=$("$FW" init "$proj" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    echo "$out"
    [[ "$out" == *"✗ func-tasks"* ]]
    [[ "$out" == *"T-001-broken.md"* ]]
    [[ "$out" == *"Init completed with validation errors"* ]]
}

@test "T-2727 negative control: a well-formed pre-existing task does not trip func-tasks" {
    # Proves the teeth test discriminates on frontmatter validity and not merely
    # on a task file being present.
    local proj="$TEST_TEMP_DIR/clean"
    mkdir -p "$proj/.tasks/active"
    printf -- '---\nid: T-001\nname: "ok"\nstatus: captured\n---\n# fine\n' \
        > "$proj/.tasks/active/T-001-ok.md"
    local out; out=$("$FW" init "$proj" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    echo "$out"
    [[ "$out" == *"✓ func-tasks"* ]]
    [[ "$out" != *"✗ func-tasks"* ]]
}
