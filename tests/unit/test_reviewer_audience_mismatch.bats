#!/usr/bin/env bats
# T-2147 (T-2143 leg B): integration coverage for `audience-mismatch` detector.
#
# Catches `[REVIEW]` Human ACs whose subject is *agent* experience (stderr the
# agent reads, gate prose the agent trips, CLI output the agent sees) — the
# operator is the wrong audience for those questions. Routing-discipline ladder:
#   T-1878 — between Human prefixes by check-shape (grep-able → [REVIEWER])
#   T-1947 — between [REVIEW] / [REVIEWER] by Expected vocabulary
#   T-2143 — out of Human prefixes entirely by audience (this detector's domain)
#   T-2147 — this reviewer-time backstop
#
# Origin: T-2139 V1 keystone gate-message AC. 4 author rounds before the
# audience mismatch was named.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/policy/anti-patterns.yaml" ] || skip "anti-patterns catalogue not found"

    TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"
    POSITIVE_TASK="$TEST_TASKS/T-9952-aud-positive-fixture.md"
    NEGATIVE_REANCHOR_TASK="$TEST_TASKS/T-9953-aud-neg-reanchor-fixture.md"
    NEGATIVE_AGENT_TASK="$TEST_TASKS/T-9954-aud-neg-agent-subhead-fixture.md"
    NEGATIVE_REVIEWER_TASK="$TEST_TASKS/T-9955-aud-neg-reviewer-prefix-fixture.md"
    NEGATIVE_OPT_OUT_TASK="$TEST_TASKS/T-9956-aud-neg-opt-out-fixture.md"

    # Positive: [REVIEW] + agent-as-subject + no human re-anchor → MUST fire
    cat > "$POSITIVE_TASK" <<'MD'
---
id: T-9952
name: positive-fixture-audience-mismatch
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9952: positive fixture for audience-mismatch

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Block-message stderr reads cleanly to the tripping agent
  **Steps:**
  1. Trigger the gate from a session
  2. Read the stderr block
  **Expected:** stderr makes the agent unblock itself; the agent will see the bypass instructions and try them
  **If not:** Reword

## Verification

# no commands
MD

    # Negative #1: [REVIEW] + agent body BUT Expected re-anchors on operator → MUST NOT fire
    cat > "$NEGATIVE_REANCHOR_TASK" <<'MD'
---
id: T-9953
name: negative-fixture-reanchor
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9953: negative fixture — Expected re-anchors on operator

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Stderr that the agent reads is clear
  **Steps:**
  1. Trip the gate
  2. Read the agent's session stderr
  **Expected:** you (the operator) confirm the message reads clean and judge whether the bypass is obvious
  **If not:** Reframe

## Verification

# no commands
MD

    # Negative #2: [REVIEW] + agent body UNDER Agent subhead → MUST NOT fire
    cat > "$NEGATIVE_AGENT_TASK" <<'MD'
---
id: T-9954
name: negative-fixture-agent-subhead
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9954: negative fixture — Agent-subhead

## Acceptance Criteria

### Agent
- [ ] [REVIEW] Agent reads the stderr correctly
  **Expected:** stderr matches the integration test
- [x] Other AC done

### Human
- [x] Already done

## Verification

# no commands
MD

    # Negative #3: [REVIEWER] (prose-mismatch's territory) → MUST NOT fire
    cat > "$NEGATIVE_REVIEWER_TASK" <<'MD'
---
id: T-9955
name: negative-fixture-reviewer-prefix
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9955: negative fixture — [REVIEWER] prefix is the other detector's job

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEWER] Agent reads stderr cleanly
  **Steps:** Run reviewer
  **Expected:** Reviewer PASS

## Verification

# no commands
MD

    # Negative #4: opt-out marker present → MUST NOT fire
    cat > "$NEGATIVE_OPT_OUT_TASK" <<'MD'
---
id: T-9956
name: negative-fixture-opt-out
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9956: negative fixture — opt-out marker

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Stderr that the agent reads is clean (rewritten to ask the operator)
  **Steps:** Trigger gate
  **Expected:** the prose makes sense

## Verification

# no commands
MD
}

teardown() {
    rm -f "$POSITIVE_TASK" "$NEGATIVE_REANCHOR_TASK" "$NEGATIVE_AGENT_TASK" "$NEGATIVE_REVIEWER_TASK" "$NEGATIVE_OPT_OUT_TASK"
}

@test "T-2147: reviewer fires audience-mismatch on [REVIEW] + agent-as-subject" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9952 2>&1 || true)
    echo "$out" | grep -q "audience-mismatch" \
        || { echo "expected finding not in output:"; echo "$out"; false; }
}

@test "T-2147: reviewer suppresses on operator-anchored Expected (re-anchor)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9953 2>&1 || true)
    test "$(echo "$out" | grep -c 'audience-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2147: reviewer silent on Agent-subhead [REVIEW] AC (correct routing)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9954 2>&1 || true)
    test "$(echo "$out" | grep -c 'audience-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2147: reviewer silent on [REVIEWER] AC (prose-mismatch's territory)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9955 2>&1 || true)
    test "$(echo "$out" | grep -c 'audience-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2147: reviewer suppresses with author opt-out marker" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9956 2>&1 || true)
    test "$(echo "$out" | grep -c 'audience-mismatch')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2147: catalogue carries audience-mismatch pattern entry" {
    test "$(grep -c 'id: audience-mismatch' "$FRAMEWORK_ROOT/policy/anti-patterns.yaml")" -ge 1
}

@test "T-2147: detect function is exported from static_scan module" {
    cd "$FRAMEWORK_ROOT"
    out=$(python3 -c "from lib.reviewer.static_scan import detect_audience_mismatch; print('ok')")
    test "$out" = "ok"
}
