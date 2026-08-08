#!/usr/bin/env bats
# T-2865 — DEFER decisions carrying no revisit date must be surfaced, separately.
#
# Origin: agents/context/revisit-due-scan.sh filtered on
#
#     [[ "$revisit_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
#
# and `continue`d on empty — so a task whose `## Decision` block records DEFER but
# which carries no `revisit_at` was skipped before any reporting logic ran. The
# scanner also removes its output file when nothing is ripe, deliberately making
# "absent" and "empty" the same signal. Composed, those two facts meant the ripe
# file's absence read as "no deferrals pending" while 14 of 14 active DEFER
# decisions sat unscheduled and unobservable.
#
# WHAT IS PINNED: the real scanner, driven against a synthetic PROJECT_ROOT. Not a
# reimplementation of its predicate — quoting the source would prove the line
# exists, not that the behaviour follows from it, with PROJECT_ROOT resolution and
# frontmatter parsing sitting in between.
#
# ANTI-VACUITY: `test_pre_fix_scanner_goes_red_on_the_finding_leg` extracts the
# PRE-FIX scanner with `git show HEAD:` and runs the same three controls plus the
# finding against it. The finding leg must go red and all three controls must stay
# green — so the red is the defect and not a broken harness. Without that, a green
# run proves only that today's corpus happens to be clean.
#
# CONTROLS (all must stay green, in both arms):
#   1. a ripe dated deferral       → .revisits-due.txt only, never the undated file
#   2. a future-dated deferral     → neither file
#   3. an ordinary non-deferred task → neither file
# Control 3 matters most: a rule that reported every dateless task would report all
# 324 active tasks and bury the 14 the signal exists to raise.

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/context/revisit-due-scan.sh"

# Build a synthetic project root the scanner will accept, seeded with the four
# task shapes under test. Echoes the root path.
_seed_project() {
    local root="$1"
    mkdir -p "$root/.tasks/active" "$root/.context/working"
    # Project shape marker — the scanner walks up looking for one of these.
    touch "$root/FRAMEWORK.md"

    # (a) THE FINDING: DEFER recorded, no revisit_at at all.
    cat > "$root/.tasks/active/T-9001-undated.md" <<'EOF'
---
id: T-9001
name: "undated deferral"
status: started-work
---

## Decision

**Decision**: DEFER

**Rationale**: waiting on an upstream answer

**Date**: 2026-01-01T00:00:00Z
EOF

    # (b) CONTROL 1: DEFER with a ripe date — belongs in .revisits-due.txt ONLY.
    cat > "$root/.tasks/active/T-9002-ripe.md" <<'EOF'
---
id: T-9002
name: "ripe deferral"
status: started-work
revisit_at: 2000-01-01
---

## Decision

**Decision**: DEFER

**Rationale**: revisit once the dependency lands
EOF

    # (c) CONTROL 2: DEFER with a future date — belongs in NEITHER file.
    cat > "$root/.tasks/active/T-9003-future.md" <<'EOF'
---
id: T-9003
name: "future deferral"
status: started-work
revisit_at: 2999-12-31
---

## Decision

**Decision**: DEFER

**Rationale**: not yet
EOF

    # (d) CONTROL 3: ordinary task, no DEFER, no date — belongs in NEITHER file.
    # Carries the shipped template comment inside `## Decision`, which mentions the
    # literal word "defer" in `go|no-go|defer`. If the predicate matched that, every
    # task in the project would land in the undated signal.
    cat > "$root/.tasks/active/T-9004-ordinary.md" <<'EOF'
---
id: T-9004
name: "ordinary build task"
status: started-work
---

## Decisions

### 2026-01-01 — some choice
- **Chose:** a thing

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..." -->
EOF
}

# Run a given scanner against a seeded root. Sets $due / $undated to file contents
# ("" when the file is absent, which is the scanner's empty signal).
_run_scanner() {
    local scanner="$1" root="$2"
    PROJECT_ROOT="$root" bash "$scanner"
    due=$(cat "$root/.context/working/.revisits-due.txt" 2>/dev/null || true)
    undated=$(cat "$root/.context/working/.revisits-undated.txt" 2>/dev/null || true)
}

@test "T-2865: an undated DEFER is surfaced in the undated signal" {
    local root="$BATS_TEST_TMPDIR/proj"
    _seed_project "$root"
    _run_scanner "$SCANNER" "$root"
    [[ "$undated" == *"T-9001"* ]]
}

@test "T-2865: control 1 — a ripe dated deferral goes to .revisits-due only" {
    local root="$BATS_TEST_TMPDIR/proj"
    _seed_project "$root"
    _run_scanner "$SCANNER" "$root"
    [[ "$due" == *"T-9002"* ]]
    [[ "$undated" != *"T-9002"* ]]
}

@test "T-2865: control 2 — a future-dated deferral appears in neither file" {
    local root="$BATS_TEST_TMPDIR/proj"
    _seed_project "$root"
    _run_scanner "$SCANNER" "$root"
    [[ "$due" != *"T-9003"* ]]
    [[ "$undated" != *"T-9003"* ]]
}

@test "T-2865: control 3 — an ordinary non-deferred task appears in neither file" {
    local root="$BATS_TEST_TMPDIR/proj"
    _seed_project "$root"
    _run_scanner "$SCANNER" "$root"
    [[ "$due" != *"T-9004"* ]]
    [[ "$undated" != *"T-9004"* ]]
}

@test "T-2865: the two signals are separate files, not one widened file" {
    local root="$BATS_TEST_TMPDIR/proj"
    _seed_project "$root"
    _run_scanner "$SCANNER" "$root"
    # The ripe file must not have been widened to carry the dateless entry.
    [[ "$due" != *"T-9001"* ]]
    [ -f "$root/.context/working/.revisits-undated.txt" ]
}

@test "T-2865: absent==empty contract holds for the undated signal" {
    local root="$BATS_TEST_TMPDIR/empty"
    mkdir -p "$root/.tasks/active" "$root/.context/working"
    touch "$root/FRAMEWORK.md"
    # Pre-create the file so we prove the scanner REMOVES it, rather than merely
    # never having written it.
    echo "stale content" > "$root/.context/working/.revisits-undated.txt"
    PROJECT_ROOT="$root" bash "$SCANNER"
    [ ! -f "$root/.context/working/.revisits-undated.txt" ]
}

@test "T-2865: ANTI-VACUITY (durable) — mutating out the reporting line makes the finding leg red" {
    # The git-based teeth check below goes inert the moment this fix is committed
    # (HEAD then carries the fix, and it skips). That is the orphaned-guard class:
    # a control that reports success forever while testing nothing.
    #
    # This one mutates the LIVE scanner instead, so it keeps teeth on the shipped
    # source every run, at every future revision. Surgical mutation: delete the one
    # line that reports an undated deferral. Everything else — PROJECT_ROOT
    # resolution, frontmatter parsing, the DEFER predicate, the absent==empty
    # write-out — stays exactly as shipped.
    # Neutralise (rather than delete) the reporting line: it is the sole statement
    # inside its `if`, so deleting it would leave an empty then-block and the
    # mutant would die on a syntax error — which looks identical to "the finding
    # leg went red" while proving nothing. Replace with `:` to keep the shape.
    local mutant="$BATS_TEST_TMPDIR/mutant-scan.sh"
    sed 's|^\([[:space:]]*\)echo "\$id: \$name" >> "\$tmp_undated"|\1:|' "$SCANNER" > "$mutant"

    # The mutation must actually have changed something, or this test is vacuous
    # in precisely the way it exists to prevent...
    ! diff -q "$SCANNER" "$mutant" >/dev/null
    # ...and the mutant must still be a valid script, so a red finding leg below
    # means "the report was suppressed", not "the scanner failed to parse".
    bash -n "$mutant"

    local root="$BATS_TEST_TMPDIR/proj-mut"
    _seed_project "$root"
    _run_scanner "$mutant" "$root"

    # Finding leg red under mutation...
    [[ "$undated" != *"T-9001"* ]]
    # ...controls still green, so the red is the removed reporting line and not a
    # scanner that simply crashed.
    [[ "$due" == *"T-9002"* ]]
    [[ "$due" != *"T-9003"* ]]
    [[ "$due" != *"T-9004"* ]]
}

@test "T-2865: ANTI-VACUITY — the pre-fix scanner goes red on the finding leg, controls green" {
    local pre="$BATS_TEST_TMPDIR/pre-fix-scan.sh"
    # Extract the scanner as it was BEFORE this task's commit. Skip rather than
    # pass if the parent revision is unavailable — a silent pass here would be the
    # exact vacuity this test exists to rule out.
    if ! git -C "$FRAMEWORK_ROOT" show "HEAD:agents/context/revisit-due-scan.sh" > "$pre" 2>/dev/null; then
        skip "cannot extract pre-fix scanner from HEAD"
    fi
    # If HEAD already contains the fix, this test has nothing to prove — it must
    # say so, not report success.
    if grep -q 'revisits-undated' "$pre"; then
        skip "HEAD already carries the fix; teeth check belongs on the pre-fix parent"
    fi

    local root="$BATS_TEST_TMPDIR/proj-pre"
    _seed_project "$root"
    _run_scanner "$pre" "$root"

    # THE FINDING LEG — must be red against the pre-fix scanner.
    [[ "$undated" != *"T-9001"* ]]
    [ ! -f "$root/.context/working/.revisits-undated.txt" ]

    # ...while all three controls stay green, proving the harness is sound and the
    # red above is the defect rather than a broken fixture.
    [[ "$due" == *"T-9002"* ]]
    [[ "$due" != *"T-9003"* ]]
    [[ "$due" != *"T-9004"* ]]
}
