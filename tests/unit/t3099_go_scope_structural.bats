#!/usr/bin/env bats
# T-3099: the GO-scope-not-propagated detector's candidate gate is structural.
#
# The block under test lives inside a 6000-line audit.sh whose top-level run
# takes a global lock ("Another audit is already running — exiting"), so neither
# these tests nor the P-011 gate can invoke audit.sh directly. It is therefore
# EXTRACTED from the shipped source and evaluated against stub pass/warn/fail —
# the same technique tests/helpers/audit-branch-hygiene-block.sh uses (T-3095),
# for the same reason. Extracting keeps the assertions pinned to the real file:
# a copy of the predicate in the test would pass forever after audit.sh changed,
# which is exactly the defect class this rail exists to catch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_TMPDIR/fix"
    mkdir -p "$FIX/.tasks/active" "$FIX/.tasks/completed" "$FIX/.context/audits"

    RUNNER="$BATS_TEST_TMPDIR/run-block.sh"
    cat > "$RUNNER" <<'RUNNEREOF'
#!/usr/bin/env bash
REPO_ROOT="$1"; PROJECT_ROOT="$2"; FRAMEWORK_ROOT="$REPO_ROOT"
AUDITS_DIR="$PROJECT_ROOT/.context/audits"
PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
pass() { echo "PASS|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
info() { echo "INFO|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { echo "WARN|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { echo "FAIL|$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
eval "$(sed -n '/^# T-2096 (OBS-036, sibling to L-417\/T-1975): GO-scope-not-propagated scan\.$/,/^# end GO-scope-not-propagated scan (T-3099)$/p' "$REPO_ROOT/agents/audit/audit.sh")"
echo "COUNTS|pass=$PASS_COUNT|warn=$WARN_COUNT|fail=$FAIL_COUNT"
RUNNEREOF
    chmod +x "$RUNNER"
}

_block() { run "$RUNNER" "$REPO_ROOT" "$FIX"; }

# ── fixtures ─────────────────────────────────────────────────────────────────
#
# Every fixture inception records a GO and phrases its slice promise in wording
# the OLD claim regex (r'filed on GO|sub-tasks (filed|created)|build slices
# (filed|created)|child tasks (filed|spun off)') does NOT match — the wording
# T-2822 actually used. Under the old gate none of these were ever candidates.

# GO'd inception, related_tasks: [], nothing points back → MUST be detected.
_fixture_prose_only() {
    cat > "$FIX/.tasks/completed/T-9001-prose-only.md" <<'EOF'
---
id: T-9001
workflow_type: inception
status: work-completed
related_tasks: []
---
## Recommendation

**Recommendation:** GO

Bounded fix path, in dependency order — each is a separate build slice:
1. Detection plus refusal in the existing PreToolUse path.
2. fw doctor surfaces sibling worktrees.

## Decision

**Decision**: GO

**Rationale**: source-only, enforced at the write layer
EOF
}

# Same shape, but a build task back-references it on its related_tasks: line.
_fixture_backreferenced() {
    cat > "$FIX/.tasks/completed/T-9002-backreferenced.md" <<'EOF'
---
id: T-9002
workflow_type: inception
status: work-completed
related_tasks: []
---
## Recommendation

**Recommendation:** GO — each is a separate build slice.

## Decision

**Decision**: GO
EOF
    cat > "$FIX/.tasks/active/T-9102-child-of-9002.md" <<'EOF'
---
id: T-9102
workflow_type: build
status: started-work
related_tasks: [T-9002]
---
## Context
Slice 1 of T-9002.
EOF
}

# Same shape, but the inception's own related_tasks: is populated.
_fixture_populated_related_tasks() {
    cat > "$FIX/.tasks/completed/T-9003-populated.md" <<'EOF'
---
id: T-9003
workflow_type: inception
status: work-completed
related_tasks: [T-9103, T-9104]
---
## Recommendation

**Recommendation:** GO — each is a separate build slice.

## Decision

**Decision**: GO
EOF
}

# ── the three AC-named fixtures ──────────────────────────────────────────────

@test "prose the old regex missed: GO'd inception with no propagation is detected" {
    _fixture_prose_only
    _block
    [ "$status" -eq 0 ]
    # The old gate's own regex must not match this fixture — otherwise the test
    # would pass for the wrong reason.
    ! grep -qEi 'filed on GO|sub-tasks (filed|created)|build slices (filed|created)|child tasks (filed|spun off)' \
        "$FIX/.tasks/completed/T-9001-prose-only.md"
    echo "$output" | grep -q '^WARN|Found 1 GO-scope-not-propagated inception'
    echo "$output" | grep -q '^EVIDENCE|T-9001'
}

@test "back-referenced by another task's related_tasks: is NOT detected" {
    _fixture_backreferenced
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception'
    ! echo "$output" | grep -q '^WARN|'
}

@test "populated related_tasks: is NOT detected" {
    _fixture_populated_related_tasks
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception'
    ! echo "$output" | grep -q '^WARN|'
}

@test "unlocks_inception_decision: pointing at it is NOT detected" {
    _fixture_prose_only
    cat > "$FIX/.tasks/active/T-9101-unlocks.md" <<'EOF'
---
id: T-9101
workflow_type: build
status: started-work
related_tasks: []
unlocks_inception_decision: [T-9001:slice-1]
---
## Context
Ships slice 1.
EOF
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception'
    ! echo "$output" | grep -q '^WARN|'
}

# ── predicate carries no vocabulary (AC #1) ──────────────────────────────────

@test "NO-GO and DEFER inceptions are never candidates" {
    for verdict in NO-GO DEFER; do
        printf -- '---\nid: T-90%s\nworkflow_type: inception\nstatus: work-completed\nrelated_tasks: []\n---\n\n## Decision\n\n**Decision**: %s\n' \
            "$verdict" "$verdict" > "$FIX/.tasks/completed/T-9010-$verdict.md"
    done
    # Filenames must still carry a parseable id.
    mv "$FIX/.tasks/completed/T-9010-NO-GO.md" "$FIX/.tasks/completed/T-9010-nogo.md"
    mv "$FIX/.tasks/completed/T-9010-DEFER.md" "$FIX/.tasks/completed/T-9011-defer.md"
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception'
}

@test "non-inception workflow types are never candidates" {
    cat > "$FIX/.tasks/completed/T-9020-build.md" <<'EOF'
---
id: T-9020
workflow_type: build
status: work-completed
related_tasks: []
---
## Decision

**Decision**: GO
EOF
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception'
}

# ── output contract (ACs #3, #4, #5) ─────────────────────────────────────────

@test "severity is WARN, never FAIL" {
    _fixture_prose_only
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^COUNTS|pass=0|warn=1|fail=0'
    ! echo "$output" | grep -q '^FAIL|'
}

@test "output is bounded: at most 5 sampled ids plus an overflow marker" {
    for n in $(seq 1 9); do
        printf -- '---\nid: T-92%02d\nworkflow_type: inception\nstatus: work-completed\nrelated_tasks: []\n---\n\n## Decision\n\n**Decision**: GO\n' \
            "$n" > "$FIX/.tasks/completed/T-92$(printf '%02d' "$n")-x.md"
    done
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Found 9 GO-scope-not-propagated inception'
    evidence=$(echo "$output" | grep '^EVIDENCE|' | head -1)
    [ "$(echo "$evidence" | grep -o 'T-92[0-9][0-9]' | wc -l)" -eq 5 ]
    echo "$evidence" | grep -q '(+4 more)'
}

@test "full list is reachable by a named command in the mitigation" {
    _fixture_prose_only
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'MITIGATION|.*Full list: cat .*go-scope-unpropagated/LATEST.md'
    [ -f "$FIX/.context/audits/go-scope-unpropagated/LATEST.md" ]
    grep -q '^- T-9001' "$FIX/.context/audits/go-scope-unpropagated/LATEST.md"
}

@test "positive line states the size of the set actually examined" {
    _fixture_backreferenced
    _fixture_populated_related_tasks
    _block
    [ "$status" -eq 0 ]
    # 2 GO-recorded completed inceptions examined, of 2 completed inceptions.
    echo "$output" | grep -q '^PASS|No GO-scope-not-propagated inception(s) — examined 2 GO-recorded completed inception(s) of 2'
}

@test "empty corpus PASS names zero, and does not claim to have examined anything" {
    _block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'examined 0 GO-recorded completed inception(s) of 0'
}

# ── T-2298 structure preserved ───────────────────────────────────────────────

@test "two-pass O(M+N) structure preserved: no per-candidate cross-file scan" {
    block=$(sed -n '/^# T-2096 (OBS-036, sibling to L-417\/T-1975): GO-scope-not-propagated scan\.$/,/^# end GO-scope-not-propagated scan (T-3099)$/p' \
        "$REPO_ROOT/agents/audit/audit.sh")
    # Exactly one python3 pre-scan, and no grep fan-out over the task corpus.
    [ "$(echo "$block" | grep -c 'python3 -c')" -eq 1 ]
    ! echo "$block" | grep -qE 'grep .*\.tasks/(completed|active)'
    # Both passes present.
    echo "$block" | grep -q '# Pass 1:'
    echo "$block" | grep -q '# Pass 2:'
}
