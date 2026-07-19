#!/usr/bin/env bats
# T-1967 (L-414 root cause) — `agents/task-create/update-task.sh:check_acceptance_criteria()`
# must strip one-line `<!-- ... -->` HTML comments BEFORE applying the sed range
# strip for multi-line comments.
#
# Bug shape: sed range `/<!--/,/-->/d` does NOT see `-->` on the SAME line as
# `<!--` — it waits for the NEXT line containing `-->`. When the template
# default places a one-line helper comment under `### Agent` (and a multi-line
# example comment under `### Human`), sed enters delete-mode at the Agent
# one-liner and stays there until the closing `-->` deep inside the Human
# multi-line block — swallowing all 7 ticked Agent ACs in between.
#
# Witness: T-1941 closure refused with "1/1 agent AC unchecked" when the file
# had 7 [x]'d Agent ACs and 1 [ ] Human AC. The 7 were invisible to the parser.
#
# Fix: two-step strip — `sed -E 's/<!--[^>]*-->//g'` first (handles one-line),
# then `sed '/<!--/,/-->/d'` for genuine multi-line.
#
# Sibling family: T-1620 fixed the same class of bug in lib/inception.sh and
# lib/verify-acs.sh (different consumers, Python regex impl).

load ../test_helper

# ---- Source-level invariant ----
# T-2554 (832 G-009 relay): [^>]* stopped at the first '>' INSIDE the comment,
# so one-line comments citing a <tag> escaped the strip and the range strip
# swallowed down to a later '-->' (including the ### Human header — Human ACs
# then miscounted as Agent ACs → hard-block instead of partial-complete).
# New pattern: minimal POSIX match to the first '-->'.

@test "update-task.sh strips one-line comments before range strip (T-1967/T-2554)" {
    grep -q "T-1967" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    # New '>'-tolerant regex present at both sites; old broken regex gone
    [ "$(grep -c "s/<!--(\[\^-\]|-\[\^-\]|--\[\^>\])\*-->//g" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh")" -eq 2 ]
    ! grep -q "s/<!--\[\^>\]\*-->//g" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

@test "check-active-task.sh OQ strip uses '>'-tolerant regex (T-2554 third site)" {
    grep -q "s/<!--(\[\^-\]|-\[\^-\]|--\[\^>\])\*-->//g" "$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    ! grep -q "s/<!--\[\^>\]\*-->//g" "$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

# ---- Behavioural — the exact sed pipeline used post-fix ----

@test "two-step sed strip preserves Agent ACs when one-line comment precedes (T-1967)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] First AC
- [x] Second AC
- [x] Third AC

### Human
<!-- multi-line
     comment block
     - [ ] [REVIEW] example
     more lines
-->
- [ ] [REVIEW] Real human AC

## Verification
EOF

    # The exact two-step pipeline used in update-task.sh:check_acceptance_criteria
    run bash -c '
ac=$(sed -n "/^## Acceptance Criteria/,/^## /p" task.md | sed "\$d")
ac=$(echo "$ac" | sed -E "s/<!--([^-]|-[^-]|--[^>])*-->//g" | sed "/<!--/,/-->/d")
agent_acs=$(echo "$ac" | awk "/^### Agent/{f=1; next} /^### /{f=0} f")
echo "$agent_acs" | grep -cE "^\s*-\s*\[x\]"'
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "single-step sed strip swallows Agent ACs (regression repro, T-1967)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
### Agent
<!-- one-line comment -->
- [x] AC1
- [x] AC2
### Human
<!-- multi
     line -->
- [ ] REVIEW
EOF

    # The OLD pipeline — confirms the bug class is real.
    run bash -c '
sed "/<!--/,/-->/d" task.md | grep -cE "^\s*-\s*\[x\]" || true'
    [ "$status" -eq 0 ]
    # Bug: should be 2, but is 0 (swallowed)
    [ "$output" = "0" ]
}

@test "two-step strip still counts real unchecked Human ACs (T-1967)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
## Acceptance Criteria

### Agent
<!-- helper -->
- [x] All agent done

### Human
<!-- example block
     - [ ] [REVIEW] ignore me
-->
- [ ] [REVIEW] Real one
- [ ] [REVIEW] Another real one

## Verification
EOF

    run bash -c '
ac=$(sed -n "/^## Acceptance Criteria/,/^## /p" task.md | sed "\$d")
ac=$(echo "$ac" | sed -E "s/<!--([^-]|-[^-]|--[^>])*-->//g" | sed "/<!--/,/-->/d")
human_acs=$(echo "$ac" | awk "/^### Human/{f=1; next} /^### /{f=0} f")
echo "$human_acs" | grep -cE "^\s*-\s*\[ \]"'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

# ---- T-2554: '>' inside a one-line comment (832 G-009 shape) ----

@test "one-line comment containing '>' is stripped; Agent/Human partition intact (T-2554)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
## Acceptance Criteria

### Agent
<!-- cites a <bpmn:intermediateCatchEvent> tag -->
- [x] Agent AC one
- [x] Agent AC two

### Human
<!-- example block
     - [ ] [REVIEW] ignore me
-->
- [ ] [REVIEW] Real human AC

## Verification
EOF

    # Fixed pipeline: the '>'-bearing one-liner must NOT trigger delete-mode.
    run bash -c '
ac=$(sed -n "/^## Acceptance Criteria/,/^## /p" task.md | sed "\$d")
ac=$(echo "$ac" | sed -E "s/<!--([^-]|-[^-]|--[^>])*-->//g" | sed "/<!--/,/-->/d")
agent_unchecked=$(echo "$ac" | awk "/^### Agent/{f=1; next} /^### /{f=0} f" | grep -cE "^\s*-\s*\[ \]" || true)
human_unchecked=$(echo "$ac" | awk "/^### Human/{f=1; next} /^### /{f=0} f" | grep -cE "^\s*-\s*\[ \]" || true)
echo "${agent_unchecked}:${human_unchecked}"'
    [ "$status" -eq 0 ]
    # Correct: 0 unchecked Agent, 1 unchecked Human (partial-complete path)
    [ "$output" = "0:1" ]
}

@test "old regex folds Human AC into Agent partition on '>'-comment (regression repro, T-2554)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
### Agent
<!-- cites a <bpmn:tag> here -->
- [x] Agent AC one

### Human
<!-- example
-->
- [ ] [REVIEW] Real human AC
EOF

    # OLD pipeline: one-line strip misses ('>' inside), range strip swallows
    # from the comment to the '-->' inside the Human block — deleting the
    # ### Human header. The surviving Human AC lands in the Agent partition.
    run bash -c '
ac=$(sed -E "s/<!--[^>]*-->//g" task.md | sed "/<!--/,/-->/d")
echo "$ac" | awk "/^### Agent/{f=1; next} /^### /{f=0} f" | grep -cE "^\s*-\s*\[ \]" || true'
    [ "$status" -eq 0 ]
    # Bug: should be 0, but the Human AC is miscounted as an unchecked AGENT AC
    [ "$output" = "1" ]
}

@test "genuinely unchecked Agent AC still blocks after T-2554 fix" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
## Acceptance Criteria

### Agent
<!-- cites a <tag> in a comment -->
- [x] Done one
- [ ] Not done yet

### Human
- [ ] [REVIEW] Real human AC

## Verification
EOF

    run bash -c '
ac=$(sed -n "/^## Acceptance Criteria/,/^## /p" task.md | sed "\$d")
ac=$(echo "$ac" | sed -E "s/<!--([^-]|-[^-]|--[^>])*-->//g" | sed "/<!--/,/-->/d")
echo "$ac" | awk "/^### Agent/{f=1; next} /^### /{f=0} f" | grep -cE "^\s*-\s*\[ \]"'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

# ---- Sanity ----

@test "update-task.sh parses (bash -n) after T-1967" {
    bash -n "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

@test "check-active-task.sh parses (bash -n) after T-2554" {
    bash -n "$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}
