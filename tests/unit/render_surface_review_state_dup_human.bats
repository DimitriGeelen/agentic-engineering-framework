#!/usr/bin/env bats
# T-1901: render-surface gate's review-state detector reads ALL `### Human`
# blocks, not just the first. Backward-compatible with single-header tasks.
#
# Pre-fix bug: a task with `### Human` template-comment header + a second
# `### Human` containing the actual [REVIEW] AC returned "empty" because
# re.search captured only the first block's content. Hit on T-1898.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$FRAMEWORK_ROOT"
}

# Extract the python heredoc from update-task.sh and run it standalone.
# Avoids needing the full update flow.
_run_review_state() {
    local task_file="$1"
    python3 - "$task_file" <<'PYREV'
import sys, re
try:
    text = open(sys.argv[1]).read()
except OSError:
    print("error"); sys.exit(0)
matches = list(re.finditer(r'^### Human\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL))
if not matches:
    print("no_section"); sys.exit(0)
human = "\n".join(m.group(1) for m in matches)
human = re.sub(r'<!--.*?-->', '', human, flags=re.DOTALL)
review_lines = [l for l in human.splitlines() if re.match(r'\s*-\s*\[[ x]\]\s*\[REVIEW\]', l)]
if review_lines:
    print("has_review"); sys.exit(0)
ac_lines = [l for l in human.splitlines() if re.match(r'\s*-\s*\[[ x]\]', l)]
print("only_other" if ac_lines else "empty")
PYREV
}

@test "T-1901: single ### Human with [REVIEW] → has_review (backward-compat)" {
    local f="$BATS_TMPDIR/T-1901-single.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [x] dummy

### Human
- [ ] [REVIEW] looks good

## Verification
true
EOF
    run _run_review_state "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "has_review" ]
}

@test "T-1901: duplicate ### Human (comment-only first + [REVIEW] second) → has_review" {
    # The T-1898 shape exactly. Pre-fix this returned "empty".
    local f="$BATS_TMPDIR/T-1901-dup-with-review.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [x] dummy

### Human
<!-- template comment block, no checkboxes -->

### Human
- [ ] [REVIEW] hidden in the second block

## Verification
true
EOF
    run _run_review_state "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "has_review" ]
}

@test "T-1901: duplicate ### Human (both comment-only) → empty (correctly refuses)" {
    local f="$BATS_TMPDIR/T-1901-dup-empty.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [x] dummy

### Human
<!-- template comment block -->

### Human
<!-- another comment, still no checkbox -->

## Verification
true
EOF
    run _run_review_state "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "empty" ]
}

@test "T-1901: no ### Human section → no_section" {
    local f="$BATS_TMPDIR/T-1901-no-human.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [x] dummy

## Verification
true
EOF
    run _run_review_state "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "no_section" ]
}

@test "T-1901: single ### Human with only non-REVIEW checkboxes → only_other" {
    local f="$BATS_TMPDIR/T-1901-only-other.md"
    cat > "$f" <<'EOF'
## Acceptance Criteria

### Agent
- [x] dummy

### Human
- [ ] [RUBBER-STAMP] just press the button

## Verification
true
EOF
    run _run_review_state "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "only_other" ]
}
