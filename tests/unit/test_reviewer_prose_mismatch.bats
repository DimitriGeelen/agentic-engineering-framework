#!/usr/bin/env bats
# T-1947 (L-409): integration coverage for `reviewer-prose-mismatch` —
# the inverse of `human-ac-mechanical-signal`.
#
# Mechanical signal: `[REVIEW]` AC whose Expected is grep-able → should be `[REVIEWER]`
# Prose mismatch:    `[REVIEWER]` AC whose Expected is prose-quality → should be `[REVIEW]`
#
# Origin: T-1811 AC#1 (`[REVIEWER] Updated CLAUDE.md section reads clearly`)
# got no reviewer attention because the reviewer has no prose-quality detector.
# Scanner reported CONCERN on Agent AC#3 — surface looked identical to "all clear
# on prose". This bats file pins the structural catch.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/policy/anti-patterns.yaml" ] || skip "anti-patterns catalogue not found"

    TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"
    POSITIVE_TASK="$TEST_TASKS/T-9947-rev-prose-positive-fixture.md"
    NEGATIVE_GREP_TASK="$TEST_TASKS/T-9948-rev-prose-neg-grepable-fixture.md"
    NEGATIVE_REVIEW_TASK="$TEST_TASKS/T-9949-rev-prose-neg-review-prefix-fixture.md"
    NEGATIVE_AGENT_TASK="$TEST_TASKS/T-9950-rev-prose-neg-agent-subhead-fixture.md"

    # Positive: [REVIEWER] + prose vocab → MUST fire
    cat > "$POSITIVE_TASK" <<'MD'
---
id: T-9947
name: positive-fixture-prose-mismatch
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-20T00:00:00Z
last_update: 2026-05-20T00:00:00Z
date_finished: null
---

# T-9947: positive fixture for reviewer-prose-mismatch

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEWER] Updated docs section reads clearly and tone matches surrounding prose
  **Steps:**
  1. Run `bin/fw reviewer T-XXX`
  **Expected:** Reviewer returns PASS on the doc-update AC text
  **If not:** Address findings

## Verification

# no commands
MD

    # Negative #1: [REVIEWER] + grep-able Expected → MUST NOT fire (this is the correct routing)
    cat > "$NEGATIVE_GREP_TASK" <<'MD'
---
id: T-9948
name: negative-fixture-reviewer-grepable
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-20T00:00:00Z
last_update: 2026-05-20T00:00:00Z
date_finished: null
---

# T-9948: negative fixture — [REVIEWER] + grep-able Expected is correct routing

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEWER] Block message names both bypass mechanisms
  **Steps:**
  1. Run `bin/fw reviewer T-XXX`
  **Expected:** message contains `--switch-focus` and `FW_SWITCH_FOCUS=1` literals
  **If not:** Inspect hook block-message string

## Verification

# no commands
MD

    # Negative #2: [REVIEW] + prose vocab → MUST NOT fire on this detector
    # (the existing human-ac-mechanical-signal handles the inverse class)
    cat > "$NEGATIVE_REVIEW_TASK" <<'MD'
---
id: T-9949
name: negative-fixture-review-prefix-with-prose
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-20T00:00:00Z
last_update: 2026-05-20T00:00:00Z
date_finished: null
---

# T-9949: negative fixture — [REVIEW] + prose vocab is correct routing

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Dashboard reads cleanly and tone feels right
  **Steps:**
  1. Open in browser
  **Expected:** layout reads intuitively
  **If not:** Edit CSS

## Verification

# no commands
MD

    # Negative #3: [REVIEWER] + prose vocab UNDER ### Agent → MUST NOT fire
    # (detector only routes Human ACs)
    cat > "$NEGATIVE_AGENT_TASK" <<'MD'
---
id: T-9950
name: negative-fixture-agent-subhead
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-20T00:00:00Z
last_update: 2026-05-20T00:00:00Z
date_finished: null
---

# T-9950: negative fixture — Agent subhead exempt

## Acceptance Criteria

### Agent
- [ ] [REVIEWER] Output reads cleanly
  **Expected:** all good

### Human
- [x] Already done

## Verification

# no commands
MD
}

teardown() {
    rm -f "$POSITIVE_TASK" "$NEGATIVE_GREP_TASK" "$NEGATIVE_REVIEW_TASK" "$NEGATIVE_AGENT_TASK"
}

@test "T-1947: reviewer fires reviewer-prose-mismatch on [REVIEWER] + prose Expected" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9947 2>&1 || true)
    echo "$out" | grep -q "reviewer-prose-mismatch" \
        || { echo "expected finding not in output:"; echo "$out"; false; }
}

@test "T-1947: reviewer suppresses on [REVIEWER] + grep-able Expected (correct routing)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9948 2>&1 || true)
    test "$(echo "$out" | grep -c 'reviewer-prose-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-1947: reviewer-prose-mismatch silent on [REVIEW] + prose (other detector's job)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9949 2>&1 || true)
    test "$(echo "$out" | grep -c 'reviewer-prose-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-1947: reviewer-prose-mismatch silent on Agent-subhead [REVIEWER] AC" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9950 2>&1 || true)
    test "$(echo "$out" | grep -c 'reviewer-prose-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-1947: catalogue carries reviewer-prose-mismatch pattern entry" {
    test "$(grep -c 'id: reviewer-prose-mismatch' "$FRAMEWORK_ROOT/policy/anti-patterns.yaml")" -ge 1
}

@test "T-1947: detect function is exported from static_scan module" {
    cd "$FRAMEWORK_ROOT"
    python3 -c "from lib.reviewer.static_scan import detect_reviewer_prose_mismatch; print('ok')" | grep -q ok
}
