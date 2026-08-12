#!/usr/bin/env bats
# T-2954: check-human-ac-tick — comment-aware counting + direction asymmetry.
#
# Origin: 832 rail 579 §5(ii), handed here under gap-homing. Two defects in one
# guard:
#
#   (a) `get_checkbox_states` regexed the raw `### Human` section with no comment
#       handling, so the template's own example ACs — which ship INSIDE an HTML
#       comment block — were counted. Measured at fix time: 1103 of 2942 task
#       files carried 1-2 phantom boxes.
#
#       The harm is not the count. `detect_toggle` zips positionally, so editing
#       the comment block SHIFTS every real AC's index and the zip misaligns. Leg
#       1 is that case: deleting the template guidance, touching no real AC,
#       reported `toggles=[(0, ' ', 'x')]` — a Human-AC tick that never happened,
#       blocking the edit and (under override) writing a fabricated tick into the
#       Tier-2 bypass log.
#
#   (b) `detect_toggle` is `if a != b`, so `[x]` → `[ ]` blocked as hard as
#       `[ ]` → `[x]`. Covered by the updated leg in human_ac_tick_guard.bats;
#       leg 4 here pins that a real tick THROUGH a comment block still blocks, so
#       (a)'s fix cannot be mistaken for weakening the guard.
#
# FALSIFICATION: restoring the un-stripped `re.findall` in get_checkbox_states
# turns legs 1 and 3 red; reverting `blocking_toggles` to accept both directions
# turns the updated guard-suite leg red. Legs 2, 4, 5 stay green either way —
# they are the no-regression side.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    [ -f "$HOOK_SH" ] || skip "hook wrapper not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    TASK_FILE="$TEST_ROOT/.tasks/active/T-9998-test.md"
    cat > "$TASK_FILE" <<'MD'
---
id: T-9998
name: "test"
status: started-work
workflow_type: build
---
# T-9998: test

## Acceptance Criteria

### Agent
- [ ] Agent AC one

### Human
<!-- Criteria requiring human verification. Remove this section if none.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
       - [ ] [REVIEWER] Block message names both mechanisms
-->
- [x] [REVIEW] Operator confirmed the layout
- [ ] [REVIEW] Operator confirmed the copy

## Verification

bats x
MD
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

run_hook_edit() {
    local file="$1" old="$2" new="$3"
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':sys.argv[2],'new_string':sys.argv[3],'replace_all':False}}))
" "$file" "$old" "$new")
    run bash "$HOOK_SH" <<< "$input"
}

# ── Leg 1: the false positive that motivated the task ────────────────────────

@test "deleting the template comment block does NOT report a Human-AC toggle" {
    run_hook_edit "$TASK_FILE" \
        "       - [ ] [REVIEW] Dashboard renders correctly
       - [ ] [REVIEWER] Block message names both mechanisms
" \
        ""
    [ "$status" -eq 0 ]
    echo "$output" | grep -qv "HUMAN-AC TICK BLOCKED" || true
    ! echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
}

# ── Leg 2: no-regression — a real tick still blocks ─────────────────────────

@test "ticking a real Human AC still BLOCKS (comment-awareness did not weaken it)" {
    run_hook_edit "$TASK_FILE" \
        "- [ ] [REVIEW] Operator confirmed the copy" \
        "- [x] [REVIEW] Operator confirmed the copy"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
}

# ── Leg 3: the commented example lines are not counted at all ────────────────

@test "checkbox-shaped lines inside the HTML comment are not counted as Human ACs" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', '$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py')
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
human = g.extract_human_section(open('$TASK_FILE').read())
boxes = g.get_checkbox_states(human)
print(len(boxes))
"
    [ "$status" -eq 0 ]
    # Two real Human ACs; the two commented examples must not appear.
    [ "$output" = "2" ]
}

# ── Leg 4: NON-VACUITY — the OLD expression, run inline, mis-counts ──────────
# Without this the suite could pass while asserting nothing: if the fix silently
# stopped applying, legs 1 and 3 would need to be the ones that catch it, and a
# suite that never exercises the broken form cannot tell "fixed" from "fixture
# no longer reaches the code".

@test "the pre-fix expression counts 4 boxes on the same fixture (fixture is live)" {
    run python3 -c "
import re, sys
sys.path.insert(0, '$FRAMEWORK_ROOT/agents/context')
import importlib.util
spec = importlib.util.spec_from_file_location('g', '$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py')
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
human = g.extract_human_section(open('$TASK_FILE').read())
old = re.findall(r'^\s*-\s*\[([x ])\]', human, re.MULTILINE)   # pre-T-2954
print(len(old))
"
    [ "$status" -eq 0 ]
    # 2 real + 2 commented examples. If this ever prints 2, the fixture stopped
    # containing commented ACs and legs 1/3 have become vacuous.
    [ "$output" = "4" ]
}

# ── Leg 5: the shared module is actually the one in use ─────────────────────

@test "the guard imports the shared comment_strip module, not a local copy" {
    run grep -c "from comment_strip import strip_html_comment_lines" \
        "$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py"
    [ "$output" = "1" ]
    # ...and defines no inline strip of its own.
    ! grep -q "re.sub(r'<!--" "$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py"
}

# ── Leg 6: the shipped template is the real-world instance ──────────────────

@test "the shipped task template's commented example AC is not counted" {
    tmpl="$FRAMEWORK_ROOT/.tasks/templates/default.md"
    [ -f "$tmpl" ] || skip "template not found"
    run python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('g', '$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py')
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
human = g.extract_human_section(open('$tmpl').read())
print(len(g.get_checkbox_states(human)))
"
    [ "$status" -eq 0 ]
    # The template's Human section is entirely commented guidance — zero real ACs.
    [ "$output" = "0" ]
}
