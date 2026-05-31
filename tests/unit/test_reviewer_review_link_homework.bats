#!/usr/bin/env bats
# T-2140 (T-2138 V2): integration coverage for `review-link-homework` detector.
#
# Catches `### Human` AC Steps that ask the reviewer to construct the
# Watchtower URL themselves (homework pattern from T-2138 RCA) instead of
# emitting a full clickable URL.
#
# Origin: T-2109 surfaced the pattern in operator pushback; T-2138 RCA
# documented 7 historical sites + same-session self-demonstration;
# T-2139 ships the transition-time blocking gate; this is the
# catch-before-handoff backstop (Candidate B in T-2138's matrix).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/policy/anti-patterns.yaml" ] || skip "anti-patterns catalogue not found"

    TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"
    POSITIVE_TASK="$TEST_TASKS/T-9960-review-link-homework-positive.md"
    NEGATIVE_FULL_URL_TASK="$TEST_TASKS/T-9961-review-link-homework-neg-full-url.md"
    NEGATIVE_OPT_OUT_TASK="$TEST_TASKS/T-9962-review-link-homework-neg-opt-out.md"

    # Positive: Human AC Steps with `(Watchtower URL from`
    cat > "$POSITIVE_TASK" <<MD
---
id: T-9960
name: review-link-homework-positive
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

# T-9960

## Acceptance Criteria

### Agent
- [x] Built the page

### Human
- [ ] [REVIEW] Open each page and confirm clean render
  **Steps:**
  1. Open each of these (Watchtower URL from \`bin/fw watchtower url\`):
     - \`/bvp\`
     - \`/approvals\`
  **Expected:** Each renders cleanly

## Verification

# no commands
MD

    # Negative: Same shape but full clickable URLs
    cat > "$NEGATIVE_FULL_URL_TASK" <<MD
---
id: T-9961
name: review-link-homework-neg-full-url
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

# T-9961

## Acceptance Criteria

### Agent
- [x] Built the page

### Human
- [ ] [REVIEW] Open each page and confirm clean render
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. Open http://192.168.10.107:3000/approvals
  **Expected:** Each renders cleanly

## Verification

# no commands
MD

    # Negative: Has the literal pattern but opt-out marker present
    cat > "$NEGATIVE_OPT_OUT_TASK" <<MD
---
id: T-9962
name: review-link-homework-neg-opt-out
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

# T-9962

## Acceptance Criteria

### Agent
- [x] Documented the pattern

### Human
- [ ] [REVIEW] Verify the catalogue quotes the literal phrase accurately
  <!-- review-link-homework-ok: this task documents the homework pattern -->
  **Steps:**
  1. Confirm "URL from \`bin/fw watchtower url\`" appears verbatim in the catalogue entry
  **Expected:** Quote is exact

## Verification

# no commands
MD
}

teardown() {
    rm -f "$POSITIVE_TASK" "$NEGATIVE_FULL_URL_TASK" "$NEGATIVE_OPT_OUT_TASK"
}

@test "T-2140: reviewer fires review-link-homework on Human AC with (Watchtower URL from" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9960 2>&1 || true)
    echo "$out" | grep -q "review-link-homework" \
        || { echo "expected finding not in output:"; echo "$out"; false; }
}

@test "T-2140: reviewer silent on full URLs in Human AC Steps" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9961 2>&1 || true)
    test "$(echo "$out" | grep -c 'review-link-homework')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2140: reviewer silent when opt-out marker present" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9962 2>&1 || true)
    test "$(echo "$out" | grep -c 'review-link-homework')" -eq 0 \
        || { echo "unexpected finding (opt-out should suppress):"; echo "$out"; false; }
}

@test "T-2140: catalogue carries review-link-homework pattern entry" {
    test "$(grep -c 'id: review-link-homework' "$FRAMEWORK_ROOT/policy/anti-patterns.yaml")" -ge 1
}

@test "T-2140: detect function is exported from static_scan module" {
    cd "$FRAMEWORK_ROOT"
    out=$(python3 -c "from lib.reviewer.static_scan import detect_review_link_homework; print('ok')")
    test "$out" = "ok"
}
