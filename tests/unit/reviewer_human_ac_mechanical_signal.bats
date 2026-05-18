#!/usr/bin/env bats
# T-1896 (T-1878 B): integration coverage for the new reviewer pattern
# `human-ac-mechanical-signal` — runs `bin/fw reviewer` end-to-end against
# synthetic task files, asserts the pattern fires (or doesn't) per design.
#
# The Python unit tests in tests/unit/test_reviewer_human_ac_mechanical_signal.py
# cover the detector in isolation; this bats file pins the higher-level wiring
# (catalogue loading + scan_task orchestration + verdict rendering).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/policy/anti-patterns.yaml" ] || skip "anti-patterns catalogue not found"

    TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"
    POSITIVE_TASK="$TEST_TASKS/T-9897-rev-mech-positive-fixture.md"
    NEGATIVE_TASK="$TEST_TASKS/T-9898-rev-mech-negative-fixture.md"
    CONFORMANCE_TASK="$TEST_TASKS/T-9899-rev-mech-conformance-fixture.md"

    cat > "$POSITIVE_TASK" <<'MD'
---
id: T-9897
name: positive-fixture-mechanical-review
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-18T00:00:00Z
last_update: 2026-05-18T00:00:00Z
date_finished: null
---

# T-9897: positive fixture for human-ac-mechanical-signal

## Context

Synthetic positive case — [REVIEW] AC whose Expected is grep-able.

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Confirm endpoint responds
  **Steps:**
  1. curl it
  **Expected:** `curl -sf http://localhost:5050/health` returns HTTP 200
  **If not:** Restart service

## Verification

# no commands
MD

    cat > "$CONFORMANCE_TASK" <<'MD'
---
id: T-9899
name: conformance-fixture-mechanical-review
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-18T00:00:00Z
last_update: 2026-05-18T00:00:00Z
date_finished: null
---

# T-9899: conformance fixture for human-ac-mechanical-signal (T-1897 widening)

## Context

Synthetic positive case — [REVIEW] AC whose Expected uses conformance-dialect (names X / shows Y / contains override flag / audit row appended) — should fire the widened detector.

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Confirm block message is complete
  **Steps:**
  1. Trigger the gate
  **Expected:** Block message names the missing deliverable, shows current focus task, and contains the --switch-focus override flag; audit log row appended to .context/audits/foo.jsonl
  **If not:** Re-word

## Verification

# no commands
MD

    cat > "$NEGATIVE_TASK" <<'MD'
---
id: T-9898
name: negative-fixture-taste-review
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-18T00:00:00Z
last_update: 2026-05-18T00:00:00Z
date_finished: null
---

# T-9898: negative fixture for human-ac-mechanical-signal

## Context

Synthetic negative case — taste signals in Expected suppress finding.

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Deprecation banner reads as obvious supersedes note
  **Steps:**
  1. Open in Markdown viewer
  **Expected:** The voice + framing tells a fresh reader "supersedes" without them needing to chase references.
  **If not:** Edit banner prose.

## Verification

# no commands
MD
}

teardown() {
    rm -f "$POSITIVE_TASK" "$NEGATIVE_TASK" "$CONFORMANCE_TASK"
}

@test "reviewer fires human-ac-mechanical-signal on grep-able [REVIEW] Expected" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9897 2>&1 || true)
    echo "$out" | grep -q "human-ac-mechanical-signal" \
        || { echo "expected finding not in output:"; echo "$out"; false; }
}

@test "reviewer suppresses human-ac-mechanical-signal on taste-signal [REVIEW] Expected" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9898 2>&1 || true)
    # Negative case: must NOT appear in findings
    test "$(echo "$out" | grep -c 'human-ac-mechanical-signal')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "catalogue carries human-ac-mechanical-signal pattern entry" {
    test "$(grep -c 'id: human-ac-mechanical-signal' "$FRAMEWORK_ROOT/policy/anti-patterns.yaml")" -ge 1
}

@test "detect function is exported from static_scan module" {
    cd "$FRAMEWORK_ROOT"
    python3 -c "from lib.reviewer.static_scan import detect_human_ac_mechanical_signal; print('ok')" | grep -q ok
}

@test "T-1897 widening: reviewer fires on conformance-dialect [REVIEW] Expected" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9899 2>&1 || true)
    echo "$out" | grep -q "human-ac-mechanical-signal" \
        || { echo "expected widened-dialect finding not in output:"; echo "$out"; false; }
}
