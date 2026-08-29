#!/usr/bin/env bats
# T-3178: `fw review-queue` renders decided-unclosed inceptions.
#
# WHAT THIS PINS, AND THE ONE THING IT REFUSES TO DO.
#
# The failure being guarded is an EMPTY SECTION that looks identical to a
# correctly-empty one. So a test that merely asserts "the command exits 0" or
# "the corpus has N decided inceptions" would stay green after the feature is
# deleted. Every test below either seeds a task and demands it appear, or seeds
# the negative case and demands it NOT appear. The `mutation` test at the bottom
# is the control leg: it removes the shipped predicate from the path and asserts
# the section disappears, which is what makes the positive tests evidence rather
# than decoration (same control the sibling T-3175 and T-3099 tests carry).
#
# The suite runs the SHIPPED bin/fw against a synthetic PROJECT_ROOT. It does not
# reimplement the query and it does not fake `decided_unclosed`. A test that fakes
# its own data source cannot detect that source behaving differently — T-3209 shipped
# a green suite over a live false positive exactly that way, and peer 010-termlink
# posted the generalised class on the chat arc: a guard that reimplements the code
# it guards cannot detect that code being fixed.

setup() {
    FWROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FWROOT
    TMPROOT="$(mktemp -d)"
    export TMPROOT
    mkdir -p "$TMPROOT/.tasks/active" "$TMPROOT/.context/arcs" "$TMPROOT/.context/working"
}

teardown() {
    [ -n "$TMPROOT" ] && rm -rf "$TMPROOT"
}

# Seed one inception. $1=id $2=status $3=owner $4=decision-or-empty $5=arc-or-empty
seed_inception() {
    local id="$1" status="$2" owner="$3" decision="$4" arc="${5:-}"
    local f="$TMPROOT/.tasks/active/$id-seeded.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"seeded inception $id\""
        echo "status: $status"
        echo "workflow_type: inception"
        echo "owner: $owner"
        echo "horizon: now"
        [ -n "$arc" ] && echo "arc_id: $arc"
        echo "created: 2026-08-01T00:00:00Z"
        echo "last_update: '2026-08-01T00:00:00Z'"
        echo "---"
        echo ""
        echo "## Recommendation"
        echo ""
        echo "**Recommendation:** GO"
        echo "**Rationale:** seeded fixture, long enough to be substantive."
        echo ""
        if [ -n "$decision" ]; then
            echo "## Decision"
            echo ""
            echo "**Decision**: $decision"
            echo "**Rationale**: seeded"
        fi
    } > "$f"
}

seed_arc() {
    cat > "$TMPROOT/.context/arcs/$1.yaml" <<EOF
id: $2
slug: $1
name: "seeded arc"
status: in-progress
EOF
}

rq() {
    PROJECT_ROOT="$TMPROOT" run "$FWROOT/bin/fw" review-queue "$@"
}

# ── The positive case ────────────────────────────────────────────────────────

@test "T-3178: a GO'd, human-owned, still-open inception appears under DECIDED" {
    seed_inception "T-9001" "started-work" "human" "GO"
    rq
    [ "$status" -eq 0 ]
    [[ "$output" == *"DECIDED"*"awaiting operator closure"* ]]
    [[ "$output" == *"T-9001"* ]]
}

@test "T-3178: NO-GO also concludes an inception and appears" {
    seed_inception "T-9002" "started-work" "human" "NO-GO"
    rq
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" == *"NO-GO"* ]]
}

@test "T-3178: an agent-owned decided inception is shown too" {
    # Ownership is what makes the GATE refuse; the operator-visible fact is
    # "decided and still open". Hiding the agent-owned ones would reproduce the
    # defect one bucket over — lib/decided_unclosed.py says so explicitly.
    seed_inception "T-9003" "started-work" "agent" "GO"
    rq
    [[ "$output" == *"T-9003"* ]]
}

# ── The negative cases: each is a way the section could over-report ──────────

@test "T-3178: DEFER is a park, not a pending closure — excluded" {
    seed_inception "T-9004" "started-work" "human" "DEFER"
    rq
    [[ "$output" != *"awaiting operator closure"* ]]
}

@test "T-3178: an UNdecided inception stays in DECISIONS and is not double-listed" {
    seed_inception "T-9005" "started-work" "human" ""
    rq
    [[ "$output" == *"DECISIONS"* ]]
    [[ "$output" != *"awaiting operator closure"* ]]
}

@test "T-3178: work-completed-in-active is partial-complete, carried elsewhere" {
    seed_inception "T-9006" "work-completed" "human" "GO"
    rq
    [[ "$output" != *"awaiting operator closure"* ]]
}

@test "T-3178: a non-inception with a Decision block is not swept in" {
    seed_inception "T-9007" "started-work" "human" "GO"
    sed -i 's/^workflow_type: inception/workflow_type: build/' \
        "$TMPROOT/.tasks/active/T-9007-seeded.md"
    rq
    [[ "$output" != *"awaiting operator closure"* ]]
}

# ── The emptiness leg: the false-green this task exists to end ───────────────

@test "T-3178: a corpus whose ONLY item is a decided inception does not report empty" {
    # Before T-3178 this printed "No tasks awaiting human review." — a confident
    # false negative. This is the single most important assertion in the file.
    seed_inception "T-9008" "started-work" "human" "GO"
    rq
    [[ "$output" != *"No tasks awaiting human review."* ]]
    [[ "$output" == *"T-9008"* ]]
}

@test "T-3178: a genuinely empty corpus still reports empty" {
    # Control for the assertion above: proves that test detects a state change
    # rather than a string that is always absent.
    rq
    [[ "$output" == *"No tasks awaiting human review."* ]]
}

# ── Filter and machine-readable-output parity ────────────────────────────────

@test "T-3178: --arc narrows DECIDED, and the control proves it is not inert" {
    seed_arc "alpha-arc" "arc-901"
    seed_arc "beta-arc" "arc-902"
    seed_inception "T-9009" "started-work" "human" "GO" "alpha-arc"
    seed_inception "T-9010" "started-work" "human" "GO" "beta-arc"
    rq --arc alpha-arc
    [[ "$output" == *"T-9009"* ]]
    [[ "$output" != *"T-9010"* ]]
}

@test "T-3178: --ids does not widen to include decided inceptions" {
    # --ids feeds `fw verify-queue`'s population (T-2765, L-539). Widening it
    # here would silently change which tasks a different rail runs over.
    seed_inception "T-9011" "started-work" "human" "GO"
    rq --ids
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9011"* ]]
}

@test "T-3178: the summary line counts the decided rows" {
    seed_inception "T-9012" "started-work" "human" "GO"
    rq
    [[ "$output" == *"awaiting closure"* ]]
}

@test "T-3178: --help documents the DECIDED section" {
    rq --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"DECIDED"* ]]
}

# ── The control leg ──────────────────────────────────────────────────────────

@test "T-3178: MUTATION — with the predicate unreachable the section disappears" {
    # The control leg. Point FW_LIB_DIR at a directory with no
    # decided_unclosed.py: the import fails, _du is None, and the section must
    # vanish while the rest of the queue keeps rendering. That degradation is
    # deliberate — a review queue that dies on a missing helper hides the three
    # sections that DO work, which is worse than the gap it was added to close.
    #
    # This test is the reason the positive tests count as evidence. When it was
    # first written it passed against a BROKEN implementation, because the
    # section was absent under the harness for an unrelated reason (the import
    # resolved against PROJECT_ROOT instead of the framework). A mutation that
    # reddens nothing is a finding, not a pass: it sent me to the real defect.
    seed_inception "T-9013" "started-work" "human" "GO"
    seed_inception "T-9014" "started-work" "human" ""   # keeps DECISIONS non-empty

    # Baseline: the section IS there with the predicate reachable.
    rq
    [[ "$output" == *"awaiting operator closure"* ]]
    [[ "$output" == *"T-9013"* ]]

    # Mutated: a real framework tree with that ONE module missing.
    #
    # FW_LIB_DIR is derived unconditionally from FRAMEWORK_ROOT and is correctly
    # not an override surface — the lib must match the binary — so the mutation
    # has to be a genuine tree. Built in the vendored-consumer layout
    # (.agentic-framework/ under PROJECT_ROOT), which is also the exact shape the
    # original path bug would have shipped broken to.
    FAKE="$TMPROOT/.agentic-framework"
    mkdir -p "$FAKE/bin" "$FAKE/lib"
    cp "$FWROOT/bin/fw" "$FAKE/bin/fw"
    cp "$FWROOT/FRAMEWORK.md" "$FAKE/FRAMEWORK.md"
    for d in agents web policy .fabric; do
        [ -e "$FWROOT/$d" ] && ln -s "$FWROOT/$d" "$FAKE/$d"
    done
    # Every lib file EXCEPT the one under test.
    for f in "$FWROOT"/lib/*; do
        [ "$(basename "$f")" = "decided_unclosed.py" ] && continue
        ln -s "$f" "$FAKE/lib/$(basename "$f")"
    done
    [ ! -e "$FAKE/lib/decided_unclosed.py" ]

    PROJECT_ROOT="$TMPROOT" run "$FAKE/bin/fw" review-queue
    [ "$status" -eq 0 ]
    [[ "$output" != *"awaiting operator closure"* ]]
    # ...and the other sections survived, proving this is a scoped degradation
    # and not the whole command falling over.
    [[ "$output" == *"DECISIONS"* ]]
    [[ "$output" == *"T-9014"* ]]
}
