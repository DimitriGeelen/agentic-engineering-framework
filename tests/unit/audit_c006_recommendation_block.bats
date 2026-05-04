#!/usr/bin/env bats
# T-1716 Stream B: lib/inception_recommendation.sh — detection helper for
# the T-679 rule decay pattern (T-1715 meta-RCA). Used by audit.sh C-006
# and (future) Stream C sweep.
#
# Tests target the extracted helper functions directly, avoiding the
# heavy audit.sh harness which times out under bats `run`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Synthesize an inception task file. Args: task_id, slug, recommendation_body
_make_inception() {
    local tid="$1" slug="$2" rec_body="$3"
    cat > "$TEST_TEMP_DIR/.tasks/active/${tid}-${slug}.md" << EOF
---
id: ${tid}
name: "synthesized ${tid}"
status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
---

# ${tid}: synthesized

## Recommendation

${rec_body}

## Decisions

EOF
}

_template_only_body() {
    cat <<'EOF'
<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->
EOF
}

# ---- has_real_recommendation ----

@test "has_real_recommendation: true for GO" {
    _make_inception T-9001 go "$(printf '**Recommendation:** GO\n\n**Rationale:** synth\n')"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9001-go.md"
    [ "$status" -eq 0 ]
}

@test "has_real_recommendation: true for NO-GO" {
    _make_inception T-9002 nogo "$(printf '**Recommendation:** NO-GO\n\n**Rationale:** synth\n')"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9002-nogo.md"
    [ "$status" -eq 0 ]
}

@test "has_real_recommendation: true for DEFER" {
    _make_inception T-9003 defer "$(printf '**Recommendation:** DEFER\n\n**Rationale:** synth\n')"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9003-defer.md"
    [ "$status" -eq 0 ]
}

@test "has_real_recommendation: false for template-only body" {
    _make_inception T-9004 templ "$(_template_only_body)"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9004-templ.md"
    [ "$status" -eq 1 ]
}

@test "has_real_recommendation: false for empty Recommendation body" {
    _make_inception T-9005 empty ""
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9005-empty.md"
    [ "$status" -eq 1 ]
}

@test "has_real_recommendation: false for invalid value (MAYBE)" {
    _make_inception T-9006 maybe "$(printf '**Recommendation:** MAYBE\n')"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9006-maybe.md"
    [ "$status" -eq 1 ]
}

@test "has_real_recommendation: false for lowercase 'go' (case-sensitive)" {
    _make_inception T-9007 lowercase "$(printf '**Recommendation:** go\n')"
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9007-lowercase.md"
    [ "$status" -eq 1 ]
}

@test "has_real_recommendation: false for missing file" {
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/nonexistent.md"
    [ "$status" -eq 1 ]
}

@test "has_real_recommendation: ignores Recommendation in unrelated section" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9008-stranded.md" << 'EOF'
---
id: T-9008
workflow_type: inception
---
## Problem

**Recommendation:** GO   <-- inside problem section, not Recommendation

## Recommendation

<!-- REQUIRED before fw inception decide. -->

## Decisions
EOF
    run has_real_recommendation "$TEST_TEMP_DIR/.tasks/active/T-9008-stranded.md"
    [ "$status" -eq 1 ]
}

# ---- find_inceptions_without_recommendation ----

@test "find_inceptions_without_recommendation: empty dir returns nothing" {
    run find_inceptions_without_recommendation "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "find_inceptions_without_recommendation: lists template-only inceptions" {
    _make_inception T-9001 templ "$(_template_only_body)"
    _make_inception T-9002 real "$(printf '**Recommendation:** GO\n')"
    _make_inception T-9003 templ2 "$(_template_only_body)"
    run find_inceptions_without_recommendation "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"T-9003"* ]]
    ! [[ "$output" == *"T-9002"* ]]
}

@test "find_inceptions_without_recommendation: skips non-inception tasks" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9100-build.md" << 'EOF'
---
id: T-9100
workflow_type: build
---
## Recommendation

<!-- REQUIRED before fw inception decide. Template-only. -->

## Decisions
EOF
    run find_inceptions_without_recommendation "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"T-9100"* ]]
}

@test "find_inceptions_without_recommendation: nonexistent dir is no-op" {
    run find_inceptions_without_recommendation "/nonexistent/path/xyz"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "find_inceptions_without_recommendation: handles file at one level (no recurse)" {
    mkdir -p "$TEST_TEMP_DIR/.tasks/active/nested"
    cat > "$TEST_TEMP_DIR/.tasks/active/nested/T-9200-nested.md" << 'EOF'
---
id: T-9200
workflow_type: inception
---
## Recommendation

<!-- template -->
EOF
    run find_inceptions_without_recommendation "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    # Should NOT find the nested file (-maxdepth 1)
    ! [[ "$output" == *"T-9200"* ]]
}
