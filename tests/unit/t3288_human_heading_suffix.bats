#!/usr/bin/env bats
# T-3288 (OBS-373) — the P-013 render gate must see Human ACs under SUFFIXED
# headings. `### Human (Slice 1)` is a Human block; the pre-fix exact-match
# regex `^### Human\s*$` saw only the empty template stub next to it and
# refused T-1719's close with "no [REVIEW] Human AC" while a valid one existed.
# Third member of the heading-suffix parser class (T-3224 `**Steps:**`
# startswith; L-472 stale-PC scan; audit.sh's own T-100189 fix at one line
# coexisting with a strict regex at another).
#
# The classifier lives in lib/human_review_state.py (single source of truth —
# update-task.sh calls it); these fixtures pin its contract.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    CLASSIFY="$FRAMEWORK_ROOT/lib/human_review_state.py"
}

_state() {
    # $1 = fixture content; prints the classifier's verdict
    local f="$BATS_TEST_TMPDIR/fixture.md"
    printf '%s\n' "$1" > "$f"
    python3 "$CLASSIFY" "$f"
}

@test "t3288: suffixed heading with [REVIEW] AC yields has_review (the T-1719 shape)" {
    run _state '## Acceptance Criteria

### Human (Slice 1)
- [ ] [REVIEW] Watch the mechanic fire.
  **Steps:** open page
  **Expected:** fine
  **If not:** flag

### Human
<!-- template comment only -->'
    [ "$status" -eq 0 ]
    [ "$output" = "has_review" ]
}

@test "t3288: bare heading with [REVIEW] AC still yields has_review (no-widening)" {
    run _state '## Acceptance Criteria

### Human
- [ ] [REVIEW] Looks right.'
    [ "$status" -eq 0 ]
    [ "$output" = "has_review" ]
}

@test "t3288: suffixed heading with only non-REVIEW ACs yields only_other" {
    run _state '## Acceptance Criteria

### Human (approvals)
- [ ] [RUBBER-STAMP] Tick after deploy.'
    [ "$status" -eq 0 ]
    [ "$output" = "only_other" ]
}

@test "t3288: no Human section yields no_section" {
    run _state '## Acceptance Criteria

### Agent
- [x] Done.'
    [ "$status" -eq 0 ]
    [ "$output" = "no_section" ]
}

@test "t3288: template-comment-only Human block yields empty" {
    run _state '## Acceptance Criteria

### Human
<!-- Criteria requiring human verification.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
-->'
    [ "$status" -eq 0 ]
    [ "$output" = "empty" ]
}

@test "t3288: lookalike headings do not match — HumanX is not a Human block" {
    run _state '### HumanX
- [ ] [REVIEW] must not count

### Humanoid
- [ ] [REVIEW] must not count either'
    [ "$status" -eq 0 ]
    [ "$output" = "no_section" ]
}

@test "t3288: update-task.sh delegates to the lib — no second copy of the regex" {
    # The strict regex must not survive anywhere in the gate, and the gate must
    # reference the extracted classifier. Two greps, both load-bearing.
    run grep -c 'human_review_state.py' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
    run grep -c 'Human\\s\*' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    [[ "$output" == "0" ]]
}
