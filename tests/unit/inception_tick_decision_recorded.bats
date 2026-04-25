#!/usr/bin/env bats
# Unit tests for T-1466 — tick_inception_decide_acs recognizes
# `[Inception decision recorded]` AC wording when ## Recommendation exists.
#
# Prevents recurrence of T-1455's GO 500 saga: AC stayed unchecked
# at decide-time → P-010 blocked work-completed → /inception/T-XXX 500'd.

load ../test_helper

setup() {
    TMP="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    rm -rf "$TMP"
}

write_task() {
    local file="$1" extra_acs="${2:-}"
    cat > "$file" <<EOF
---
id: T-9999
name: "fixture"
status: started-work
workflow_type: inception
owner: agent
---

# T-9999

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale
${extra_acs}

## Recommendation

**Recommendation:** GO
EOF
}

@test "tick_inception_decide_acs: ticks [Inception decision recorded] AC when Recommendation present" {
    local f="$TMP/task.md"
    write_task "$f" "- [ ] [Inception decision recorded] go/no-go/defer with chosen option (A/B/C)"

    tick_inception_decide_acs "$f"

    run grep -F "[x] [Inception decision recorded] go/no-go/defer with chosen option (A/B/C)" "$f"
    [ "$status" -eq 0 ]
}

@test "tick_inception_decide_acs: still ticks the 3 ceremonial ACs (regression)" {
    local f="$TMP/task.md"
    write_task "$f"

    tick_inception_decide_acs "$f"

    run grep -F "[x] Problem statement validated" "$f"
    [ "$status" -eq 0 ]
    run grep -F "[x] Assumptions tested" "$f"
    [ "$status" -eq 0 ]
    run grep -F "[x] Recommendation written with rationale" "$f"
    [ "$status" -eq 0 ]
}

@test "tick_inception_decide_acs: leaves [Inception decision recorded] alone when Recommendation absent" {
    local f="$TMP/task.md"
    cat > "$f" <<'EOF'
---
id: T-9998
status: started-work
workflow_type: inception
---

## Acceptance Criteria

### Agent
- [ ] [Inception decision recorded] go/no-go/defer with chosen option (A/B/C)
EOF

    tick_inception_decide_acs "$f"

    # No ## Recommendation → tick should not fire
    run grep -F "[ ] [Inception decision recorded]" "$f"
    [ "$status" -eq 0 ]
}

@test "tick_inception_decide_acs: case-insensitive on the bracket text" {
    local f="$TMP/task.md"
    write_task "$f" "- [ ] [INCEPTION DECISION RECORDED] arbitrary trailing text"

    tick_inception_decide_acs "$f"

    run grep -F "[x] [INCEPTION DECISION RECORDED]" "$f"
    [ "$status" -eq 0 ]
}

@test "tick_inception_decide_acs: does not tick custom unrelated Agent ACs" {
    local f="$TMP/task.md"
    write_task "$f" "- [ ] Some custom verification step that is not ceremonial"

    tick_inception_decide_acs "$f"

    run grep -F "[ ] Some custom verification step" "$f"
    [ "$status" -eq 0 ]
}
