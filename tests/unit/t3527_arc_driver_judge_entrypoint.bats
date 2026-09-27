#!/usr/bin/env bats
# T-3527 — end-to-end reachability of `fw arc judge-driver` on the real entry
# point.
#
# AC: "Reachable on the live agent path, verified by invoking with NO override
# flags." T-3523's L-573 class (a guard tested with --i-am-human that no live
# path could reach) is exactly the mistake this pins against: these tests run
# the actual `bin/fw arc judge-driver` command — no --i-am-human, no
# --from-watchtower, no FW_ALLOW_* — against real probe arc files dropped into
# .context/arcs/, mirroring tests/unit/t3526_bvp_judge_entrypoint.bats.
#
# This verb carries no §ACD gate at all (read-only, nothing to approve or
# refuse), so reachability here is a lower bar than the sibling judge's — the
# thing being pinned is that the command exists, is wired end-to-end through
# lib/arc.sh, and produces the real verdict shape, not a synthetic one.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"

    GREEN_SLUG="t3527-judge-probe-green"
    GREEN_FILE=".context/arcs/${GREEN_SLUG}.yaml"
    cat > "$GREEN_FILE" <<'EOF'
id: arc-99991
slug: t3527-judge-probe-green
name: T-3527 judge probe (green)
description: "A real, specific probe objective for the arc-driver-judge entrypoint test."
headline_mechanic: "agent does X, human observes Y"
status: in-progress
proposed_scoped_drivers:
  - name: probe-driver-green
    rationale: "Distinguishes from D2 (Reliability) by measuring something D2 does not, at real length so check (c) passes cleanly."
    weight_suggestion: 3
    scoring:
      kind: signals
      levels:
        1:
          keywords: ["probe"]
scoped_drivers: []
EOF

    RED_SLUG="t3527-judge-probe-red"
    RED_FILE=".context/arcs/${RED_SLUG}.yaml"
    cat > "$RED_FILE" <<'EOF'
id: arc-99992
slug: t3527-judge-probe-red
name: T-3527 judge probe (red)
description: "Another probe arc, but the driver has no scoring spec at all."
headline_mechanic: "agent does X, human observes Y"
status: in-progress
proposed_scoped_drivers:
  - name: probe-driver-red
    rationale: "Distinguishes from D2 (Reliability) at real length so check (c) passes, but check (a) must fail: no scoring spec anywhere."
    weight_suggestion: 3
scoped_drivers: []
EOF

    CLOSED_SLUG="t3527-judge-probe-closed"
    CLOSED_FILE=".context/arcs/${CLOSED_SLUG}.yaml"
    cat > "$CLOSED_FILE" <<'EOF'
id: arc-99993
slug: t3527-judge-probe-closed
name: T-3527 judge probe (closed)
description: "A closed probe arc — must never be rescored."
headline_mechanic: "agent does X, human observes Y"
status: closed
proposed_scoped_drivers:
  - name: probe-driver-closed
    rationale: "Irrelevant — the arc is closed."
scoped_drivers: []
EOF
}

teardown() {
    rm -f "$GREEN_FILE" "$RED_FILE" "$CLOSED_FILE"
}

@test "fw arc judge-driver --help exits 0 with no flags at all" {
    run bin/fw arc judge-driver --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"judge-driver"* ]]
}

@test "fw arc judge-driver on a well-formed driver returns green, no override flags" {
    run bin/fw arc judge-driver "$GREEN_SLUG" "probe-driver-green" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state": "green"'* ]]
    [[ "$output" != *'"state": "unknown"'* ]]
}

@test "fw arc judge-driver on a scoring-spec-free driver returns red, no override flags" {
    run bin/fw arc judge-driver "$RED_SLUG" "probe-driver-red" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"state": "red"'* ]]
    [[ "$output" == *'"guidance"'* ]]
    [[ "$output" != *'"guidance": ""'* ]]
    [[ "$output" == *"no handler, no inline scoring"* ]]
}

@test "fw arc judge-driver on a closed arc is skipped, never rescored" {
    run bin/fw arc judge-driver "$CLOSED_SLUG" "probe-driver-closed" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"skipped": true'* ]]
    [[ "$output" == *"closed"* ]]
}

@test "fw arc judge-driver --all judges every driver on the arc" {
    run bin/fw arc judge-driver "$GREEN_SLUG" --all --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"probe-driver-green"* ]]
    [[ "$output" == *'"state": "green"'* ]]
}

@test "fw arc judge-driver on an unknown driver name is skipped, not judged" {
    run bin/fw arc judge-driver "$GREEN_SLUG" "does-not-exist" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"skipped": true'* ]]
}
