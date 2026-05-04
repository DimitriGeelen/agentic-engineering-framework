#!/usr/bin/env bats
# T-1718 Slice 1: Evolution-log gate
#
# Tests the detection helper (lib/evolution_log.sh) directly. Avoids
# the heavy update-task.sh harness (FD inheritance + flock issues
# under bats `run`, same lesson as T-1716 audit_c006 tests).
#
# Gate-integration tested via direct invocation of check_evolution_log
# with mocked NEW_STATUS / TASK_FILE / SKIP_EVOLUTION.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/evolution_log.sh"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Synthesize a build task. Args: task_id, slug, body_extra
_make_build_task() {
    local tid="$1" slug="$2" body_extra="$3"
    cat > "$TEST_TEMP_DIR/.tasks/active/${tid}-${slug}.md" << EOF
---
id: ${tid}
name: "synthesized ${tid}"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:test-arc, structural-gate]
---

# ${tid}: synthesized

## Context

Synthesized for evolution_log_gate bats.

## Acceptance Criteria

### Agent
- [x] Test AC

## Verification

# none

${body_extra}

## Decisions

EOF
}

_evolution_section_template_only() {
    cat <<'EOF'
## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]
-->
EOF
}

_evolution_section_substantive() {
    cat <<'EOF'
## Evolution

### 2026-05-04 — Slice 1 kickoff
- **What changed:** Discovered that backward-compat opt-in (gate fires only when section exists) avoids breaking 38 in-flight tasks while still enforcing discipline on new tasks.
- **Plan impact:** No change; slice scope holds.
- **Triggered:** None.
EOF
}

# ---- has_evolution_section ----

@test "has_evolution_section: true when ## Evolution heading present" {
    _make_build_task T-9001 has-section "$(_evolution_section_template_only)"
    run has_evolution_section "$TEST_TEMP_DIR/.tasks/active/T-9001-has-section.md"
    [ "$status" -eq 0 ]
}

@test "has_evolution_section: false when ## Evolution heading absent" {
    _make_build_task T-9002 no-section ""
    run has_evolution_section "$TEST_TEMP_DIR/.tasks/active/T-9002-no-section.md"
    [ "$status" -ne 0 ]
}

@test "has_evolution_section: false on missing file" {
    run has_evolution_section "$TEST_TEMP_DIR/.tasks/active/nonexistent.md"
    [ "$status" -ne 0 ]
}

# ---- has_real_evolution_log ----

@test "has_real_evolution_log: true for substantive entry" {
    _make_build_task T-9010 substantive "$(_evolution_section_substantive)"
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9010-substantive.md"
    [ "$status" -eq 0 ]
}

@test "has_real_evolution_log: false for template-only body" {
    _make_build_task T-9011 template "$(_evolution_section_template_only)"
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9011-template.md"
    [ "$status" -eq 1 ]
}

@test "has_real_evolution_log: false for missing section" {
    _make_build_task T-9012 missing ""
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9012-missing.md"
    [ "$status" -eq 1 ]
}

@test "has_real_evolution_log: false for empty body (heading only)" {
    _make_build_task T-9013 empty "$(printf '## Evolution\n\n')"
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9013-empty.md"
    [ "$status" -eq 1 ]
}

@test "has_real_evolution_log: false for short non-heading content" {
    _make_build_task T-9014 short "$(printf '## Evolution\n\n- short\n')"
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9014-short.md"
    [ "$status" -eq 1 ]
}

@test "has_real_evolution_log: ignores Evolution-shaped text in unrelated section" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9015-stranded.md" << 'EOF'
---
id: T-9015
workflow_type: build
tags: [arc:test]
---
## Context

What changed: this is a long sentence about evolution but it's not under the right heading at all so it should not count.

## Evolution

<!-- template only -->

## Decisions
EOF
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/T-9015-stranded.md"
    [ "$status" -eq 1 ]
}

@test "has_real_evolution_log: missing file returns false" {
    run has_real_evolution_log "$TEST_TEMP_DIR/.tasks/active/nope.md"
    [ "$status" -ne 0 ]
}

# ---- find_arc_tasks_without_evolution_log ----

@test "find_arc_tasks_without_evolution_log: empty dir returns nothing" {
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "find_arc_tasks_without_evolution_log: lists arc-tagged build tasks with template-only" {
    _make_build_task T-9101 templ "$(_evolution_section_template_only)"
    _make_build_task T-9102 real "$(_evolution_section_substantive)"
    _make_build_task T-9103 templ2 "$(_evolution_section_template_only)"
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9101"* ]]
    [[ "$output" == *"T-9103"* ]]
    ! [[ "$output" == *"T-9102"* ]]
}

@test "find_arc_tasks_without_evolution_log: skips non-arc build tasks" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9200-noarc.md" << 'EOF'
---
id: T-9200
workflow_type: build
tags: [structural-gate]
---
## Evolution

<!-- template -->

## Decisions
EOF
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"T-9200"* ]]
}

@test "find_arc_tasks_without_evolution_log: skips non-build tasks" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9201-inception.md" << 'EOF'
---
id: T-9201
workflow_type: inception
tags: [arc:test]
---
## Evolution

<!-- template -->

## Decisions
EOF
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"T-9201"* ]]
}

@test "find_arc_tasks_without_evolution_log: skips tasks without Evolution section (backward-compat)" {
    _make_build_task T-9202 noev ""
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"T-9202"* ]]
}

@test "find_arc_tasks_without_evolution_log: nonexistent dir is no-op" {
    run find_arc_tasks_without_evolution_log "/nonexistent/path/xyz"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "find_arc_tasks_without_evolution_log: handles -maxdepth 1 (no recurse)" {
    mkdir -p "$TEST_TEMP_DIR/.tasks/active/nested"
    cat > "$TEST_TEMP_DIR/.tasks/active/nested/T-9300-nested.md" << 'EOF'
---
id: T-9300
workflow_type: build
tags: [arc:test]
---
## Evolution

<!-- template -->

## Decisions
EOF
    run find_arc_tasks_without_evolution_log "$TEST_TEMP_DIR/.tasks/active"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"T-9300"* ]]
}
