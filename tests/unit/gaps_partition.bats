#!/usr/bin/env bats
#
# T-3140 — `fw gaps` enumerated an ALLOWLIST of statuses instead of partitioning
# the register, so any status outside the allowlist was invisible: not rendered,
# not counted, not summarised.
#
# Measured on the live register at fix time (92 entries): 12 unresolved gaps were
# hidden, 6 of them severity `high`, including six whose status was literally
# `open`. The header compounded it by labelling the `closed` count "resolved"
# while the 30 entries actually carrying `status: resolved` were counted nowhere.
#
# This is the false-zero shape this repo keeps finding. `fw gaps` printed
# "No gaps being watched" when `watching` was empty — the same words for a clean
# register and for one holding six unrendered high-severity gaps.
#
# WHY NEGATIVE ASSERTIONS HERE ARE `[[ "$output" != *x* ]]` AND NOT `! ... | grep -q`
# -----------------------------------------------------------------------------
# Bash exempts from errexit any command whose return value is inverted with `!`.
# A non-final `! echo "$output" | grep -q x` inside a bats test therefore CANNOT
# fail it — bats reports only the last command's status. T-3138 counted 106 such
# dead assertions across 66 files in this suite. `[[ x != y ]]` puts the negation
# inside a single command, so errexit applies and the assertion is real.
#
# FIXTURES ONLY (L-599). Every register below is written by the test into a
# synthetic PROJECT_ROOT. The live gap ids in the comment above are the origin
# record and appear in no assertion — pinning a control to the register would
# make it a report about the corpus, and the register is edited continuously.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    FIX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$FIX/.tasks/active" "$FIX/.context/project"
    export FIX
    # PROJECT_ROOT is honoured when it is set and non-stale (has .tasks/), so the
    # fixture register is what `fw gaps` reads. Unset CLAUDE_PROJECT_DIR so the
    # T-2390 hook-context branch cannot win the resolution instead.
    unset CLAUDE_PROJECT_DIR
}

_register() {
    cat > "$FIX/.context/project/concerns.yaml"
}

_gaps() {
    PROJECT_ROOT="$FIX" run "$FRAMEWORK_ROOT/bin/fw" gaps
}

# ── The defect proper: statuses outside the old allowlist ────────────────────

@test "T-3140/AC1: a status:open gap is rendered" {
    _register <<'EOF'
concerns:
  - id: G-900
    severity: high
    status: open
    title: An open gap
    decision_trigger: when it triggers
EOF
    _gaps
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'G-900'
}

@test "T-3140/AC1: statuses nobody has invented yet are rendered, not dropped" {
    # The direction of the classification is the whole fix. An allowlist drops an
    # unknown status silently; a terminal denylist surfaces it for a decision.
    _register <<'EOF'
concerns:
  - id: G-901
    severity: medium
    status: escalated-to-vendor
    title: Some future status
EOF
    _gaps
    echo "$output" | grep -q 'G-901'
    echo "$output" | grep -q 'escalated-to-vendor'
}

@test "T-3140/AC1: an entry with no status field at all is rendered and flagged" {
    _register <<'EOF'
concerns:
  - id: G-902
    severity: high
    title: No status field
EOF
    _gaps
    echo "$output" | grep -q 'G-902'
    echo "$output" | grep -q 'unset'
}

@test "T-3140/AC2: mitigated is outstanding, not terminal" {
    # CLAUDE.md §Post-Fix Root Cause Escalation: "mitigation (cleaned up the mess)
    # is not prevention (can't happen again) ... Do not close the gap until
    # prevention exists." The old code hid all 18 live mitigated entries.
    _register <<'EOF'
concerns:
  - id: G-903
    severity: high
    status: mitigated
    title: Mitigated but not prevented
EOF
    _gaps
    echo "$output" | grep -q 'G-903'
    echo "$output" | grep -q '1 outstanding'
}

@test "T-3140/AC3: resolved is counted as closed, not counted nowhere" {
    # Old header: "{watching} watching, {closed|decided-*} resolved" — the label
    # named a status the number did not count, and the real `resolved` entries
    # were in neither number.
    _register <<'EOF'
concerns:
  - id: G-904
    severity: low
    status: resolved
    title: Actually resolved
  - id: G-905
    severity: low
    status: closed
    title: Actually closed
  - id: G-906
    severity: low
    status: watching
    title: Still watching
EOF
    _gaps
    echo "$output" | grep -q '1 outstanding, 2 closed, 3 total'
}

@test "T-3140/AC3: every entry lands in exactly one half of the partition" {
    # The arithmetic is the assertion: outstanding + closed == total. A future
    # edit that reintroduces an allowlist breaks this without needing to know
    # which statuses it forgot.
    _register <<'EOF'
concerns:
  - id: G-910
    severity: low
    status: watching
    title: a
  - id: G-911
    severity: low
    status: mitigated
    title: b
  - id: G-912
    severity: low
    status: open
    title: c
  - id: G-913
    severity: low
    status: resolved
    title: d
  - id: G-914
    severity: low
    status: decided-simplify
    title: e
  - id: G-915
    severity: low
    title: f
EOF
    _gaps
    echo "$output" | grep -q '4 outstanding, 2 closed, 6 total'
}

# ── The false-zero: the empty states must be distinguishable ─────────────────

@test "T-3140/AC4: an all-closed register does not report like an empty one" {
    _register <<'EOF'
concerns:
  - id: G-920
    severity: low
    status: closed
    title: done
EOF
    _gaps
    echo "$output" | grep -q '0 outstanding'
    echo "$output" | grep -q 'all 1 entries are closed'
    [[ "$output" != *'register is empty'* ]]
}

@test "T-3140/AC4: an empty register says so in its own words" {
    _register <<'EOF'
concerns: []
EOF
    _gaps
    echo "$output" | grep -q 'register is empty'
}

@test "T-3140/AC4: the old 'No gaps being watched' line cannot appear over hidden work" {
    # The exact false-zero. `watching` is empty, so the old code printed the
    # all-clear — while three unresolved gaps sat in the register unrendered.
    _register <<'EOF'
concerns:
  - id: G-930
    severity: high
    status: open
    title: hidden one
  - id: G-931
    severity: high
    status: partial-mitigation
    title: hidden two
  - id: G-932
    severity: high
    status: mitigated
    title: hidden three
EOF
    _gaps
    # Presence FIRST. "the all-clear line is absent" is vacuously true of empty
    # output, so on its own it cannot tell a fixed surface from a broken one.
    echo "$output" | grep -q 'G-930'
    echo "$output" | grep -q 'G-931'
    echo "$output" | grep -q 'G-932'
    [[ "$output" != *'No gaps being watched'* ]]
}

@test "T-3140: high severity sorts above low so it cannot be buried" {
    _register <<'EOF'
concerns:
  - id: G-940
    severity: low
    status: watching
    title: low one
  - id: G-941
    severity: high
    status: open
    title: high one
EOF
    _gaps
    [ "$(echo "$output" | grep -n 'G-941' | cut -d: -f1)" -lt \
      "$(echo "$output" | grep -n 'G-940' | cut -d: -f1)" ]
}

# ── Regression guards: pass on both sides by construction (not coverage) ─────

@test "T-3140 [regression guard]: watching gaps still render with their trigger" {
    _register <<'EOF'
concerns:
  - id: G-950
    severity: medium
    status: watching
    title: Still watched
    decision_trigger: |
      first line of the trigger
      second line that must not render
EOF
    _gaps
    echo "$output" | grep -q 'G-950'
    echo "$output" | grep -q 'first line of the trigger'
    [[ "$output" != *'second line that must not render'* ]]
}

@test "T-3140 [regression guard]: a legacy 'gaps:' key is still read" {
    # T-397: `concerns` is canonical, `gaps` is the legacy fallback.
    _register <<'EOF'
gaps:
  - id: G-960
    severity: low
    status: watching
    title: Legacy key
EOF
    _gaps
    echo "$output" | grep -q 'G-960'
}

@test "T-3140 [regression guard]: a missing title does not crash the render" {
    # T-1840: legacy consumer entries predating the title requirement raised
    # KeyError. The defensive .get() must survive this change.
    #
    # status is `watching` on purpose. With `open` this test also failed against
    # the pre-change code — but for the wrong reason (the entry was never
    # rendered at all, so the title path was never reached), which would have
    # counted it as mutation coverage it does not provide. A guard has to
    # exercise the same code path on both sides or it is not guarding anything.
    _register <<'EOF'
concerns:
  - id: G-970
    severity: low
    status: watching
EOF
    _gaps
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'untitled'
}
