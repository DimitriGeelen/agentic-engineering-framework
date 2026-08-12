#!/usr/bin/env bats
# T-2944 — G-020's own block message was the shortest path past G-020.
#
# check-active-task.sh counted AC checkboxes without stripping HTML comments,
# unlike the G-067 inception gate 56 lines above it in the same file. The shipped
# default.md carries two illustrative `- [ ] [REVIEW]` / `- [ ] [REVIEWER]`
# examples INSIDE the Human-guidance comment block, so:
#
#   REAL_AC_COUNT over the shipped template = 4  (2 placeholders + 2 commented)
#
# Deleting the two placeholders — literally what the block message instructs —
# left HAS_PLACEHOLDER=0 and REAL_AC_COUNT=2, clearing both gate conditions for a
# task with ZERO acceptance criteria.
#
# Reported by 832 as their T-453; confirmed here by T-2943 against the real hook.
#
# These tests drive the REAL hook in a sandbox PROJECT_ROOT rather than
# re-implementing its predicate — the pre-fix bug was invisible to anyone who
# reproduced the grep, because the grep was doing exactly what it said.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    SANDBOX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working" "$SANDBOX/src"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/app.py","content":"x"}}\n' \
        "$SANDBOX" > "$SANDBOX/in.json"
}

# Write a build task whose AC section is exactly $1.
_task() {
    local id="$1" acs="$2"
    cat > "$SANDBOX/.tasks/active/${id}-t.md" <<EOF
---
id: $id
name: "t"
status: started-work
workflow_type: build
owner: agent
---

# $id

## Acceptance Criteria

### Agent
$acs

## Verification
EOF
    printf 'current_task: %s\n' "$id" > "$SANDBOX/.context/working/focus.yaml"
}

_run_hook() {
    PROJECT_ROOT="$SANDBOX" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" CLAUDECODE=1 \
        bash "$HOOK" < "$SANDBOX/in.json"
}

# The comment block below is the shipped template's shape, reduced to its essence.
COMMENTED='<!-- guidance
  - [ ] [REVIEW] Dashboard renders correctly
  - [ ] [REVIEWER] Block message names both bypass mechanisms
-->'

@test "t2944: a task whose ONLY checkboxes are inside a comment block is refused" {
    # THE REGRESSION. Pre-fix this exited 0 and the write was allowed.
    _task T-9001 "$COMMENTED"
    run _run_hook
    [ "$status" -eq 2 ] || {
        echo "zero-AC task was allowed to write source (status=$status)" >&2
        return 1
    }
}

@test "t2944: placeholders still block — the original G-020 behaviour is intact" {
    _task T-9002 "- [ ] [First criterion]
- [ ] [Second criterion]"
    run _run_hook
    [ "$status" -eq 2 ]
}

@test "t2944: placeholders inside a comment block do NOT block a task with real ACs" {
    # The other direction: stripping must not make commented placeholders
    # invisible-but-still-counted. A task with a genuine AC passes even when the
    # template's commented example text is left in place.
    _task T-9003 "- [ ] A genuine acceptance criterion
$COMMENTED"
    run _run_hook
    [ "$status" -eq 0 ] || {
        echo "a task with a real AC was blocked (status=$status) — gate now over-refuses" >&2
        return 1
    }
}

@test "t2944: a genuine AC alone still passes" {
    # Positive control. Without this, all three tests above are satisfied by a
    # gate that refuses unconditionally — which would be a worse bug, not a fix.
    _task T-9004 "- [ ] A genuine acceptance criterion"
    run _run_hook
    [ "$status" -eq 0 ]
}

@test "t2944: an empty AC section still blocks" {
    _task T-9005 ""
    run _run_hook
    [ "$status" -eq 2 ]
}

@test "t2944: the fix is present and mirrors the G-067 gate's strip" {
    # Pins the CAUSE, not just the behaviour: if someone later removes the strip,
    # the behavioural legs above go red — but this names why.
    grep -q "T-2944: strip HTML comments before counting" "$HOOK"
    # Both gates in this file must strip; the bug was that only one did.
    local strips
    strips=$(grep -c "s/<!--(\[^-\]|-\[^-\]|--\[^>\])\*-->//g" "$HOOK" || true)
    [ "${strips:-0}" -ge 2 ] || {
        echo "expected >=2 comment-strip sites (G-067 + G-020), found $strips" >&2
        return 1
    }
}

@test "t2944: the pre-fix predicate would have passed the zero-AC task" {
    # Shows the test can distinguish fixed from broken, rather than passing for
    # reasons unrelated to the fix. Runs BOTH predicates over the same input.
    local ac="$COMMENTED"
    local before after
    before=$(echo "$ac" | grep -cE '^\s*-\s*\[[ x]\]' || true)
    after=$(echo "$ac" | sed -E 's/<!--([^-]|-[^-]|--[^>])*-->//g' | sed '/<!--/,/-->/d' \
            | grep -cE '^\s*-\s*\[[ x]\]' || true)
    [ "$before" -gt 0 ]   # old predicate saw ACs that do not exist
    [ "$after" -eq 0 ]    # new predicate sees none, so the gate blocks
}
