#!/usr/bin/env bats
# T-2145 (T-2144 leg B): integration coverage for `defer-as-hedge` detector.
#
# Catches inception tasks filed with `Recommendation: DEFER` despite the
# research artifact carrying complete evidence (≥2 of: 5-Whys, Dialogue Log,
# candidate matrix) and the Rationale block being >300 chars. The structural
# fingerprint of T-2143's hedge.
#
# Origin: T-2144 RCA — T-2143 filed DEFER with full evidence; operator caught
# in one question.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/policy/anti-patterns.yaml" ] || skip "anti-patterns catalogue not found"

    TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"
    TEST_REPORTS="$FRAMEWORK_ROOT/docs/reports"
    POSITIVE_TASK="$TEST_TASKS/T-9957-defer-positive-fixture.md"
    POSITIVE_ARTIFACT="$TEST_REPORTS/T-9957-defer-positive-rca.md"
    NEGATIVE_GO_TASK="$TEST_TASKS/T-9958-defer-neg-go-fixture.md"
    NEGATIVE_GO_ARTIFACT="$TEST_REPORTS/T-9958-defer-neg-go-rca.md"
    NEGATIVE_ONE_INDICATOR_TASK="$TEST_TASKS/T-9959-defer-neg-one-fixture.md"
    NEGATIVE_ONE_INDICATOR_ARTIFACT="$TEST_REPORTS/T-9959-defer-neg-one-rca.md"

    # Positive: inception + DEFER + 2 indicators + long rationale
    cat > "$POSITIVE_ARTIFACT" <<'MD'
# T-9957 RCA

## 5-Whys

1. Why did X happen?
   Because Y.
2. Why Y?
   Because Z.

## Dialogue Log

Q: What should we do?
A: Pick A, B, or C.
MD

    cat > "$POSITIVE_TASK" <<MD
---
id: T-9957
name: defer-positive-fixture
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9957

## Acceptance Criteria

### Agent
- [x] Did the work

## Recommendation

**Recommendation:** DEFER — pending operator pick.

**Rationale:** This is a substantive rationale block that runs well over the three-hundred-character threshold the detector enforces. The candidates have been laid out with effort and coverage analysis; the 5-Whys identifies root cause; the dialogue log shows three rounds of clarification. Despite all this, I am hedging because confidence-calibration in this thread is poor. See docs/reports/T-9957-defer-positive-rca.md for the full evidence trail. Extra padding to be safely over the threshold. Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

## Verification

# no commands
MD

    # Negative: same shape but Recommendation = GO
    cat > "$NEGATIVE_GO_ARTIFACT" <<'MD'
# T-9958 RCA

## 5-Whys
1. Why?
## Dialogue Log
Q: A?
MD

    cat > "$NEGATIVE_GO_TASK" <<MD
---
id: T-9958
name: defer-negative-go-fixture
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9958

## Acceptance Criteria

### Agent
- [x] Did the work

## Recommendation

**Recommendation:** GO — Candidate B.

**Rationale:** Same long substantive rationale as the positive fixture; the only difference is the Recommendation value. The detector must not fire on GO recommendations even when evidence is complete. Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. See docs/reports/T-9958-defer-neg-go-rca.md.

## Verification

# no commands
MD

    # Negative: DEFER + only ONE indicator (legitimate sovereignty-pending DEFER)
    cat > "$NEGATIVE_ONE_INDICATOR_ARTIFACT" <<'MD'
# T-9959 RCA

## Dialogue Log

Q: Pick A or B?
A: ...

(No 5-Whys, no candidate matrix — incomplete evidence, DEFER is legitimate.)
MD

    cat > "$NEGATIVE_ONE_INDICATOR_TASK" <<MD
---
id: T-9959
name: defer-negative-one-indicator
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9959

## Acceptance Criteria

### Agent
- [x] Did the work

## Recommendation

**Recommendation:** DEFER — only one indicator present, evidence trail not yet complete.

**Rationale:** Same long substantive rationale, but the artifact has only the Dialogue Log indicator. Legitimate sovereignty-pending DEFER — the detector must not fire here. Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. See docs/reports/T-9959-defer-neg-one-rca.md.

## Verification

# no commands
MD
}

teardown() {
    rm -f "$POSITIVE_TASK" "$POSITIVE_ARTIFACT" "$NEGATIVE_GO_TASK" "$NEGATIVE_GO_ARTIFACT" "$NEGATIVE_ONE_INDICATOR_TASK" "$NEGATIVE_ONE_INDICATOR_ARTIFACT"
}

@test "T-2145: reviewer fires defer-as-hedge on inception+DEFER+full-evidence+long-rationale" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9957 2>&1 || true)
    echo "$out" | grep -q "defer-as-hedge" \
        || { echo "expected finding not in output:"; echo "$out"; false; }
}

@test "T-2145: reviewer silent on GO recommendation with full evidence" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9958 2>&1 || true)
    test "$(echo "$out" | grep -c 'defer-as-hedge')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2145: reviewer silent on DEFER with only one indicator (legitimate)" {
    cd "$FRAMEWORK_ROOT"
    out=$(bin/fw reviewer T-9959 2>&1 || true)
    test "$(echo "$out" | grep -c 'defer-as-hedge')" -eq 0 \
        || { echo "unexpected finding in output:"; echo "$out"; false; }
}

@test "T-2145: catalogue carries defer-as-hedge pattern entry" {
    test "$(grep -c 'id: defer-as-hedge' "$FRAMEWORK_ROOT/policy/anti-patterns.yaml")" -ge 1
}

@test "T-2145: detect function is exported from static_scan module" {
    cd "$FRAMEWORK_ROOT"
    out=$(python3 -c "from lib.reviewer.static_scan import detect_defer_as_hedge; print('ok')")
    test "$out" = "ok"
}
