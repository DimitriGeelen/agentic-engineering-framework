#!/usr/bin/env bats
# T-1879 (T-NEW-14): silent-corpus #2 sweep — agent-side surfaces must read
# both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy
# `arc:<slug>` tag.
#
# Sites under test:
#   - lib/evolution_log.sh task_has_arc_membership()
#   - lib/evolution_log.sh find_arc_tasks_without_evolution_log()
#   - agents/task-create/update-task.sh check_evolution_log() — via integration
#   - agents/handover/handover.sh current-arc task count — via integration
#
# Sibling to T-1874/T-1875/T-1876/T-1877 (web + CLI + audit).

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active"
    mkdir -p "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/arcs"
    mkdir -p "$PROJECT_ROOT/.context/working"

    # shellcheck disable=SC1090
    source "${FRAMEWORK_ROOT}/lib/evolution_log.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

_seed_task() {
    # _seed_task <id> <workflow_type> <tags-yaml-array> <arc_id-or-empty> [has_evolution_section]
    local id="$1" wf="$2" tags="$3" arc_id="$4" has_evo="${5:-yes}"
    local arc_id_line=""
    [ -n "$arc_id" ] && arc_id_line="arc_id: ${arc_id}"
    local evo_section=""
    [ "$has_evo" = "yes" ] && evo_section=$'\n## Evolution\n\n<!-- placeholder -->\n'
    cat > "$PROJECT_ROOT/.tasks/active/${id}-test.md" <<MD
---
id: ${id}
name: "test"
status: started-work
workflow_type: ${wf}
tags: ${tags}
${arc_id_line}
---

## Acceptance Criteria
- [ ] something
${evo_section}
MD
}

# ─── task_has_arc_membership ────────────────────────────────────────────────

@test "task_has_arc_membership: matches legacy arc:<slug> tag" {
    _seed_task "T-9001" "build" "[arc:legacy-arc, build]" ""
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9001-test.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: matches arc_id frontmatter (T-1850 migrated)" {
    _seed_task "T-9002" "build" "[build, T-NEW]" "post-migration-arc"
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9002-test.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: matches when both arc_id AND legacy tag present" {
    _seed_task "T-9003" "build" "[arc:dual-arc, build]" "dual-arc"
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9003-test.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: returns non-zero when no arc membership at all" {
    _seed_task "T-9004" "build" "[build, refactor]" ""
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9004-test.md"
    [ "$status" -ne 0 ]
}

@test "task_has_arc_membership: ignores 'arc:' string in task body" {
    # Pre-T-1879 grep -q 'arc:' whole-file matched task narrative.
    # New helper scopes to frontmatter.
    cat > "$PROJECT_ROOT/.tasks/active/T-9005-test.md" <<MD
---
id: T-9005
name: "test"
status: started-work
workflow_type: build
tags: [build]
---

## Context

Discussion of arc:something in narrative — should NOT count as arc membership.
MD
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9005-test.md"
    [ "$status" -ne 0 ]
}

@test "task_has_arc_membership: missing file → non-zero" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-MISSING.md"
    [ "$status" -ne 0 ]
}

# ─── find_arc_tasks_without_evolution_log ───────────────────────────────────

@test "find_arc_tasks_without_evolution_log: finds arc_id-only task with empty Evolution" {
    # Migration result: arc_id set, no arc:<slug> tag, ## Evolution exists but empty (template only).
    _seed_task "T-9100" "build" "[build, T-NEW]" "test-arc" "yes"
    run find_arc_tasks_without_evolution_log "$PROJECT_ROOT/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9100"* ]]
}

@test "find_arc_tasks_without_evolution_log: finds legacy-tag-only task with empty Evolution" {
    _seed_task "T-9101" "build" "[arc:legacy-arc, build]" "" "yes"
    run find_arc_tasks_without_evolution_log "$PROJECT_ROOT/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9101"* ]]
}

@test "find_arc_tasks_without_evolution_log: skips non-arc task" {
    _seed_task "T-9102" "build" "[build]" "" "yes"
    run find_arc_tasks_without_evolution_log "$PROJECT_ROOT/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9102"* ]]
}

@test "find_arc_tasks_without_evolution_log: skips non-build tasks" {
    _seed_task "T-9103" "specification" "[build]" "test-arc" "yes"
    run find_arc_tasks_without_evolution_log "$PROJECT_ROOT/.tasks/active"
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9103"* ]]
}

# ─── handover.sh current-arc task count fragment ────────────────────────────
# Replays the exact count logic from agents/handover/handover.sh against a
# synthetic fixture. Pins union-of-arc_id-and-tag behavior.

@test "handover-style count: arc_id + legacy tag unioned and deduped" {
    mkdir -p "$PROJECT_ROOT/.tasks/completed"
    cat > "$PROJECT_ROOT/.tasks/active/T-9200.md" <<MD
---
arc_id: handover-test-arc
tags: [build]
---
MD
    cat > "$PROJECT_ROOT/.tasks/active/T-9201.md" <<MD
---
tags: [arc:handover-test-arc, build]
---
MD
    cat > "$PROJECT_ROOT/.tasks/completed/T-9202.md" <<MD
---
arc_id: handover-test-arc
tags: [arc:handover-test-arc, build]
---
MD
    cat > "$PROJECT_ROOT/.tasks/active/T-9203.md" <<MD
---
tags: [build]
---
MD

    cur_arc="handover-test-arc"

    _arc_count_tmp=$(mktemp)
    grep -lE "^tags:.*arc:${cur_arc}" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^tags:.*arc:${cur_arc}" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${cur_arc}[\"']?[[:space:]]*\$" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${cur_arc}[\"']?[[:space:]]*\$" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    task_count=$(sort -u "$_arc_count_tmp" 2>/dev/null | grep -c .)
    rm -f "$_arc_count_tmp"

    [ "$task_count" = "3" ]
}

@test "handover-style count: zero when no matching tasks" {
    mkdir -p "$PROJECT_ROOT/.tasks/completed"
    cat > "$PROJECT_ROOT/.tasks/active/T-9300.md" <<MD
---
tags: [build]
---
MD

    cur_arc="nonexistent-arc"

    _arc_count_tmp=$(mktemp)
    grep -lE "^tags:.*arc:${cur_arc}" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^tags:.*arc:${cur_arc}" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${cur_arc}[\"']?[[:space:]]*\$" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${cur_arc}[\"']?[[:space:]]*\$" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null >> "$_arc_count_tmp" || true
    set +e
    task_count=$(sort -u "$_arc_count_tmp" 2>/dev/null | grep -c . 2>/dev/null)
    set -e
    [ -z "$task_count" ] && task_count=0
    rm -f "$_arc_count_tmp"

    [ "$task_count" = "0" ]
}
