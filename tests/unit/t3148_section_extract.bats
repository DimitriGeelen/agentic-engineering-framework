#!/usr/bin/env bats
#
# T-3148 — five more sed-range extractors carried the same three defects
# lib/verification-port.sh:extract_verification_block (T-3134) fixed for the
# Verification section alone:
#   D1 — trailing `sed '$d'` drops real content when the section is last.
#   D2 — unanchored PREFIX start match over-includes a same-named heading.
#   D3 — the dangerous direction of D2: a prefix heading BEFORE the real one
#        is consumed as the terminator, so the real heading opens nothing —
#        silent skip.
#
# lib/section-extract.sh:extract_ac_section and extract_recommendation_block
# are the fix. Per AC1, copying extract_verification_block's FIRST-WINS awk
# verbatim would be wrong for Recommendation — this file's control tests
# (T-3144 shape) prove why: the template ships a stub heading and the real
# content is appended afterward, so Recommendation must be LAST-WINS while
# Acceptance Criteria stays FIRST-WINS.
#
# FIXTURES ONLY (L-599, same discipline as verification_extractor_anchoring.bats).
# Every task file below is written by the test.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/section-extract.sh"
    T="$BATS_TEST_TMPDIR/task.md"
}

# ── extract_ac_section (FIRST-WINS) ──────────────────────────────────────────

@test "T-3148/AC1: AC anchor rejects a prefix-matching heading (D3 avoided)" {
    cat > "$T" <<'EOF'
## Acceptance Criteria

- [x] REAL_ONE
- [x] REAL_TWO

## Acceptance Criteria Extended

should never be captured, and must not close the real range either

## Verification
EOF
    run extract_ac_section "$T"
    echo "$output" | grep -q 'REAL_ONE'
    echo "$output" | grep -q 'REAL_TWO'
    [[ "$output" != *'should never be captured'* ]]
}

@test "T-3148/AC1 [regression guard]: anchored match still accepts trailing whitespace" {
    printf '## Acceptance Criteria   \n\n- [x] TRAILING_WS_OK\n\n## Next\n' > "$T"
    run extract_ac_section "$T"
    echo "$output" | grep -q 'TRAILING_WS_OK'
}

@test "T-3148/D1: the final AC line survives when Acceptance Criteria is the last section" {
    cat > "$T" <<'EOF'
# T-9998: fixture

## Acceptance Criteria

- [x] LEG-ONE
- [x] LEG-TWO
- [x] LEG-THREE-LAST
EOF
    run extract_ac_section "$T"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^- \[x\] LEG-THREE-LAST$'
    [ "$(echo "$output" | grep -c '^- \[x\] LEG-')" -eq 3 ]
}

@test "T-3148/D1 [control]: the pre-fix form DOES drop the final leg, so the fixture discriminates" {
    cat > "$T" <<'EOF'
# T-9998: fixture

## Acceptance Criteria

- [x] LEG-ONE
- [x] LEG-TWO
- [x] LEG-THREE-LAST
EOF
    local old_expr
    old_expr=$(grep "The previous form was" "$FRAMEWORK_ROOT/lib/section-extract.sh" \
        | grep "Acceptance Criteria" \
        | sed -E "s/.*\`(sed -n [^\`]*)\`.*/\1/")
    [[ "$old_expr" == sed\ -n\ * ]]
    local old_out
    old_out=$(eval "$old_expr \"\$T\"")
    [[ "$old_out" != *LEG-THREE-LAST* ]]
    [[ "$old_out" == *LEG-TWO* ]]
}

@test "T-3148/D2: a second exact AC heading contributes nothing (first-wins)" {
    cat > "$T" <<'EOF'
## Acceptance Criteria

- [x] FIRST_BLOCK

## Something

in between

## Acceptance Criteria

- [x] SECOND_BLOCK_MUST_NOT_COUNT
trailing line so the payload is not the last line
EOF
    run extract_ac_section "$T"
    echo "$output" | grep -q 'FIRST_BLOCK'
    [[ "$output" != *'SECOND_BLOCK_MUST_NOT_COUNT'* ]]
}

@test "T-3148 [regression guard]: a task with no Acceptance Criteria section yields nothing" {
    printf '# T-1\n\n## Context\n\nnothing here\n' > "$T"
    run extract_ac_section "$T"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── extract_recommendation_block (LAST-WINS) ─────────────────────────────────

@test "T-3148/T-3144: template stub followed by a real block yields the real block, not the stub" {
    cat > "$T" <<'EOF'
## Recommendation

<!-- T-2945: same shape as inception.md's block ...
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why
-->

## Decisions

nothing

## Recommendation

**Recommendation:** GO
**Rationale:** the real, filled-in recommendation
**Evidence:**
- Finding 1
EOF
    run extract_recommendation_block "$T"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '\*\*Recommendation:\*\* GO'
    echo "$output" | grep -q 'the real, filled-in recommendation'
    [[ "$output" != *'T-2945: same shape'* ]]
}

@test "T-3148/T-3144 [control]: the pre-fix first-wins form reads the STUB, not the real block" {
    cat > "$T" <<'EOF'
## Recommendation

<!-- STUB_MARKER_ONLY -->

## Decisions

nothing

## Recommendation

**Recommendation:** GO
**Rationale:** the real, filled-in recommendation
EOF
    local old_expr
    old_expr=$(grep "The previous form was" "$FRAMEWORK_ROOT/lib/section-extract.sh" \
        | grep "Recommendation" \
        | sed -E "s/.*\`(sed -n [^\`]*)\`.*/\1/")
    [[ "$old_expr" == sed\ -n\ * ]]
    local old_out
    old_out=$(eval "$old_expr \"\$T\"" | sed '$d')
    [[ "$old_out" == *STUB_MARKER_ONLY* ]]
    [[ "$old_out" != *'the real, filled-in recommendation'* ]]
}

@test "T-3148/D1: the final Recommendation line survives when it is the last section" {
    cat > "$T" <<'EOF'
# T-9997: fixture

## Recommendation

LEG-ONE
LEG-TWO
LEG-THREE-LAST
EOF
    run extract_recommendation_block "$T"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^LEG-THREE-LAST$'
    [ "$(echo "$output" | grep -c '^LEG-')" -eq 3 ]
}

@test "T-3148/AC1: Recommendation anchor rejects a prefix-matching heading" {
    cat > "$T" <<'EOF'
## Recommendation

**Recommendation:** NO-GO
**Rationale:** the only real block

## Recommendation Verdict (v1.0)

should never be captured by the Recommendation extractor
EOF
    run extract_recommendation_block "$T"
    echo "$output" | grep -q 'the only real block'
    [[ "$output" != *'should never be captured'* ]]
}

@test "T-3148 [regression guard]: a task with no Recommendation section yields nothing" {
    printf '# T-1\n\n## Context\n\nnothing here\n' > "$T"
    run extract_recommendation_block "$T"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── G-020 gate site: even looser /^## [^A]/ terminator (check-active-task.sh) ─

@test "T-3148: the old G-020 terminator was looser than the sibling sites — regression fixture" {
    # /^## [^A]/ never closes the range on a heading beginning '## A', so a
    # hypothetical '## Additional Notes' section between AC and EOF would have
    # been folded into the AC count under the pre-fix expression. The fixed
    # extractor (anchored, closes on ANY '^## ') must not do that.
    cat > "$T" <<'EOF'
## Acceptance Criteria

- [x] REAL_ONE

## Additional Notes

- [ ] this is NOT an acceptance criterion
EOF
    run extract_ac_section "$T"
    echo "$output" | grep -q 'REAL_ONE'
    [[ "$output" != *'this is NOT an acceptance criterion'* ]]
}

@test "T-3148 [control]: the old /^## [^A]/ terminator DOES fold in the following section" {
    # Trailing line after the payload is required — `sed '$d'` drops the last
    # line of the stream, and without it the fixture would silently delete
    # the very evidence this control exists to show (same trap T-3146's
    # analogous control names).
    cat > "$T" <<'EOF'
## Acceptance Criteria

- [x] REAL_ONE

## Additional Notes

- [ ] this is NOT an acceptance criterion
trailing line so the payload is not the last line
EOF
    old_out=$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' "$T" 2>/dev/null | sed '$d')
    [[ "$old_out" == *'this is NOT an acceptance criterion'* ]]
}
