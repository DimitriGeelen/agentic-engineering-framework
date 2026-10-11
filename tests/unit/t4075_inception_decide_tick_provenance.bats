#!/usr/bin/env bats
# T-4075: the provenance row an inception decide/sweep writes must back the tick it
# records, and no row is ever written for task '?'. Fixtures live in a temp git repo.

load ../test_helper

setup() {
    R="$(mktemp -d)"
    export PROJECT_ROOT="$R"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    unset CLAUDECODE AI_AGENT
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
    git -C "$R" init -q
    git -C "$R" config user.email op@example.com
    git -C "$R" config user.name op
    mkdir -p "$R/lib" "$R/.tasks/active" "$R/.context/reviews"
    cp "$FRAMEWORK_ROOT/lib/human_ac_ticks.py" "$FRAMEWORK_ROOT/lib/comment_strip.py" "$R/lib/"
    git -C "$R" add -A && git -C "$R" commit -q -m "detector"
    T="$R/.tasks/active/T-9001-fixture.md"
    cat > "$T" <<'EOF'
---
id: T-9001
workflow_type: inception
---
## Acceptance Criteria

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX`
  **Expected:** Decision recorded
  **If not:** Ask agent

## Recommendation
GO
EOF
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9001: file"
}

teardown() { rm -rf "$R"; }

audit() { PROJECT_ROOT="$R" python3 "$R/lib/human_ac_ticks.py" audit; }

@test "decide tick + its row, committed together, audits clean" {
    tick_inception_decide_acs "$T"
    grep -q '^- \[x\] \[REVIEW\]' "$T"
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9001: decision GO"
    run audit
    [ "$status" -eq 0 ]
}

@test "sweep path (same function on a task file) audits clean" {
    f="$R/.tasks/active/T-9002-sweep.md"
    sed 's/T-9001/T-9002/' "$T" > "$f"
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9002: file"
    tick_inception_decide_acs "$f"
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9002: sweep"
    run audit
    [ "$status" -eq 0 ]
}

@test "control: an agent tick with no ledger row still FAILs" {
    sed -i 's/^- \[ \] \[REVIEW\]/- [x] [REVIEW]/' "$T"
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9001: tick

Co-Authored-By: Claude <noreply@anthropic.com>"
    run audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"T-9001"* ]]
}

@test "a decide tick reverted by a stale commit and re-ticked needs a second row (T-4039 shape)" {
    tick_inception_decide_acs "$T"
    git -C "$R" add -A && git -C "$R" commit -q -m "T-9001: decision GO"
    sed -i 's/^- \[x\] \[REVIEW\]/- [ ] [REVIEW]/' "$T"
    git -C "$R" commit -q -am "T-9001: stale write clobbers decision"
    sed -i 's/^- \[ \] \[REVIEW\]/- [x] [REVIEW]/' "$T"
    git -C "$R" commit -q -am "T-9001: re-tick by text"
    run audit
    [ "$status" -eq 2 ]
}

@test "a task file with no T-id never writes a '?' row" {
    f="$R/untitled.md"
    cp "$T" "$f"
    run tick_inception_decide_acs "$f"
    if [ -f "$R/.context/reviews/human-ac-ticks.jsonl" ]; then
        if grep -q '"task": "?"' "$R/.context/reviews/human-ac-ticks.jsonl"; then false; fi
    fi
    [[ "$output" == *"not recorded"* ]]
}
