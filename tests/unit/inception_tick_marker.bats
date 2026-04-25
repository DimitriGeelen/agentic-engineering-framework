#!/usr/bin/env bats
# T-1472 (OBS-019 Level D): tick_inception_decide_acs detects ceremonial
# ACs via `<!-- @auto-tick-on-decide -->` markers — text-wording independent.
#
# Replaces the AGENT_PATTERNS regex fragility that caused T-1455's GO 500
# (T-1466 RCA) — every new AC wording variant required extending the regex.

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

write_task_with_marker_custom_wording() {
    local file="$1"
    cat > "$file" <<'EOF'
---
id: T-9472
name: "marker fixture"
status: started-work
workflow_type: inception
owner: agent
---

# T-9472

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Custom wording the AGENT_PATTERNS regex would miss entirely
<!-- @auto-tick-on-decide -->
- [ ] Another oddly-worded ceremonial check that decide satisfies

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Confirm the bespoke approach is acceptable

## Recommendation

**Recommendation:** GO — synthetic test
EOF
}

write_task_no_marker_regex_match() {
    # Backwards compat: existing inception tasks WITHOUT markers but with
    # regex-matching wording must still tick (fallback path).
    local file="$1"
    cat > "$file" <<'EOF'
---
id: T-9473
name: "regex fallback fixture"
status: started-work
workflow_type: inception
owner: agent
---

# T-9473

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Recommendation

**Recommendation:** GO — fallback test
EOF
}

write_task_no_marker_custom_wording() {
    # Negative case: custom wording WITHOUT marker → must NOT tick
    # (proves the marker is what enables custom wording, not a coincidence)
    local file="$1"
    cat > "$file" <<'EOF'
---
id: T-9474
name: "no-marker custom-wording fixture"
status: started-work
workflow_type: inception
owner: agent
---

# T-9474

## Acceptance Criteria

### Agent
- [ ] Custom wording with no marker — must remain unchecked
- [ ] Problem statement validated

## Recommendation

**Recommendation:** GO — negative test
EOF
}

@test "tick_inception_decide_acs ticks markered ACs with custom wording (T-1472)" {
    local f="$TMP/markered.md"
    write_task_with_marker_custom_wording "$f"
    tick_inception_decide_acs "$f"

    grep -q '^- \[x\] Custom wording' "$f"
    grep -q '^- \[x\] Another oddly-worded' "$f"
    grep -q '^- \[x\] \[REVIEW\] Confirm the bespoke' "$f"
}

@test "tick_inception_decide_acs falls back to regex for un-markered ACs (T-1472 backcompat)" {
    local f="$TMP/regex.md"
    write_task_no_marker_regex_match "$f"
    tick_inception_decide_acs "$f"

    grep -q '^- \[x\] Problem statement validated' "$f"
    grep -q '^- \[x\] Assumptions tested' "$f"
    grep -q '^- \[x\] Recommendation written with rationale' "$f"
    grep -q '^- \[x\] \[REVIEW\] Review exploration findings' "$f"
}

@test "tick_inception_decide_acs leaves un-markered custom-wording ACs alone (T-1472 negative)" {
    local f="$TMP/negative.md"
    write_task_no_marker_custom_wording "$f"
    tick_inception_decide_acs "$f"

    # Custom wording without marker stays unchecked (only regex-match ticks)
    grep -q '^- \[ \] Custom wording with no marker' "$f"
    grep -q '^- \[x\] Problem statement validated' "$f"
}
