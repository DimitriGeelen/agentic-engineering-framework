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

@test "update-task.sh strips one-line comments before range strip (T-1967)" {
    grep -q "T-1967" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q "'s/<!--\[\^>\]\*-->//g'" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
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
ac=$(echo "$ac" | sed -E "s/<!--[^>]*-->//g" | sed "/<!--/,/-->/d")
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
ac=$(echo "$ac" | sed -E "s/<!--[^>]*-->//g" | sed "/<!--/,/-->/d")
human_acs=$(echo "$ac" | awk "/^### Human/{f=1; next} /^### /{f=0} f")
echo "$human_acs" | grep -cE "^\s*-\s*\[ \]"'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

# ---- Sanity ----

@test "update-task.sh parses (bash -n) after T-1967" {
    bash -n "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}
