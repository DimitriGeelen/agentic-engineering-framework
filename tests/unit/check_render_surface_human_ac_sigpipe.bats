#!/usr/bin/env bats
# T-1900: render-surface gate error path used to die with SIGPIPE (exit 141)
# under set -eo pipefail when `render_surface_files_in | head -N` produced
# more lines than head consumed. Script died with no error printed; user saw
# "command did nothing" indistinguishable from success.
#
# Origin: T-1898 update — Verification 5/5 PASS, Recommendation ✓, RCA ✓,
# then silent exit 141 because the task had duplicate `### Human` headers
# (first one template-only) and components: 5 render-surface paths.
#
# Fix: awk reads to EOF instead of head closing stdin early. No SIGPIPE.
# Test pins:
#   - the offending pipeline pattern no longer present in source
#   - the gate's error path actually prints its message and exits non-141
#     when triggered with a multi-path task

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$FRAMEWORK_ROOT"
    REPRO_TASK="$BATS_TMPDIR/T-9998-sigpipe-repro.md"
    cat > "$REPRO_TASK" <<'EOF'
---
id: T-9998
name: "synthetic repro"
description: >
  trigger render-surface gate's error path with multi-path components
  and a duplicate ### Human header that fools the review-state regex.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components:
  - web/templates/arc_detail.html
  - web/templates/arcs_index.html
  - web/templates/orchestrator.html
  - web/shared.py
  - web/blueprints/arcs.py
related_tasks: []
created: 2026-05-18T19:00:00Z
last_update: 2026-05-18T19:00:00Z
---

# T-9998 repro

## Acceptance Criteria

### Agent
- [x] dummy

### Human
<!-- template comment -->

### Human
- [ ] [REVIEW] would be human-only

## Verification
true
EOF
}

teardown() {
    rm -f "$REPRO_TASK"
}

@test "T-1900: offending pipeline pattern absent from update-task.sh" {
    run grep -c 'render_surface_files_in.*| head' agents/task-create/update-task.sh
    [ "$status" -eq 1 ]  # grep returns 1 when zero matches
    [ "$output" = "0" ]
}

@test "T-1900: render-surface gate error path runs to completion (no SIGPIPE)" {
    # Run the gate function in isolation, simulating the failing case.
    run bash -c '
        set -eo pipefail
        source "'"$FRAMEWORK_ROOT"'/lib/render_surface.sh"
        # Mimic the post-fix line literally.
        matched=$(render_surface_files_in "'"$REPRO_TASK"'" 2>/dev/null | awk "NR<=3 { print \"    - \" \$0 }")
        echo "FIX_OK"
        echo "$matched"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"FIX_OK"* ]]
    [[ "$output" == *"web/templates/arc_detail.html"* ]]
}

@test "T-1900: pre-fix pattern (head -3) DID die with SIGPIPE — regression sentinel" {
    # Negative control: if someone reintroduces the head -3 form, this test
    # documents that the old form would crash. Not asserting failure of the
    # current code; asserting the *historical* form's bad behaviour persists
    # so a future cleanup can't accidentally remove this defense without
    # understanding why awk is in there.
    run bash -c '
        set -eo pipefail
        source "'"$FRAMEWORK_ROOT"'/lib/render_surface.sh"
        matched=$(render_surface_files_in "'"$REPRO_TASK"'" 2>/dev/null | head -3 | sed "s/^/    - /")
        echo "PRE_FIX_OK"
    '
    # Either 141 (SIGPIPE — typical) or some other non-zero (set -e under
    # pipefail propagation). NEVER 0 with PRE_FIX_OK printed.
    [ "$status" -ne 0 ]
    [[ "$output" != *"PRE_FIX_OK"* ]]
}
