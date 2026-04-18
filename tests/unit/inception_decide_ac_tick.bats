#!/usr/bin/env bats
# Unit tests for tick_inception_decide_acs (T-1324)
#
# After fw inception decide writes the Decision block, the templated
# [REVIEW] / [RUBBER-STAMP] Human AC must be ticked so the work-completed
# gate doesn't leave the task in partial-complete forever (G-008; P-039).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariant ----

@test "tick_inception_decide_acs: function is defined and sourceable" {
    run type tick_inception_decide_acs
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "do_inception_decide calls tick_inception_decide_acs" {
    grep -q 'tick_inception_decide_acs "$task_file"' "$FRAMEWORK_ROOT/lib/inception.sh"
}

# ---- Behavior contract ----

@test "ticks templated [REVIEW] AC under ### Human" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [ ] Problem statement validated

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:** etc.

## Decision
EOF
    tick_inception_decide_acs "$f"
    grep -q '^- \[x\] \[REVIEW\] Review exploration findings and approve go/no-go decision' "$f"
}

@test "ticks [RUBBER-STAMP] Record decision variant" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
### Human
- [ ] [RUBBER-STAMP] Record go/no-go decision in Watchtower

## Decision
EOF
    tick_inception_decide_acs "$f"
    grep -q '^- \[x\] \[RUBBER-STAMP\] Record go/no-go decision in Watchtower' "$f"
}

# ---- Idempotency ----

@test "idempotent: already-ticked AC stays ticked, no error" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision

## Decision
EOF
    run tick_inception_decide_acs "$f"
    [ "$status" -eq 0 ]
    grep -q '^- \[x\] \[REVIEW\] Review exploration findings and approve go/no-go decision' "$f"
    # Must not have introduced a duplicate or [ ] copy
    [ "$(grep -c '\[REVIEW\] Review exploration' "$f")" -eq 1 ]
}

@test "second invocation is a no-op" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Decision
EOF
    tick_inception_decide_acs "$f"
    local first
    first=$(md5sum "$f" | awk '{print $1}')
    tick_inception_decide_acs "$f"
    local second
    second=$(md5sum "$f" | awk '{print $1}')
    [ "$first" = "$second" ]
}

# ---- No over-match ----

@test "does NOT tick a custom Human AC that mentions 'decision' but doesn't match the predicate" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
### Human
- [ ] [REVIEW] Verify the deployment decision is documented elsewhere
- [ ] Custom AC about a decision somewhere

## Decision
EOF
    tick_inception_decide_acs "$f"
    # First AC mentions "decision" but lacks "go/no-go" — must NOT be ticked
    grep -q '^- \[ \] \[REVIEW\] Verify the deployment decision is documented elsewhere' "$f"
    grep -q '^- \[ \] Custom AC about a decision somewhere' "$f"
}

@test "does NOT tick Agent ACs even if text matches the predicate" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
### Agent
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

### Human
- [ ] Some other AC

## Decision
EOF
    tick_inception_decide_acs "$f"
    # Agent AC must remain unchecked (lives outside ### Human)
    grep -q '^- \[ \] \[REVIEW\] Review exploration findings and approve go/no-go decision' "$f"
}

# ---- Safety on missing/garbage input ----

@test "missing file: function returns 0 without error" {
    run tick_inception_decide_acs "/nonexistent/path/to/task.md"
    [ "$status" -eq 0 ]
}

@test "no ### Human section: function leaves file unchanged" {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Decision
EOF
    local before
    before=$(md5sum "$f" | awk '{print $1}')
    tick_inception_decide_acs "$f"
    local after
    after=$(md5sum "$f" | awk '{print $1}')
    [ "$before" = "$after" ]
}
