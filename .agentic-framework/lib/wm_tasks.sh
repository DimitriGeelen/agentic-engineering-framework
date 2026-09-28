#!/bin/bash
# lib/wm_tasks.sh — the workflow-management (WM) task class (T-3537)
#
# ── WHY THIS EXISTS ───────────────────────────────────────────────────────────
#
# The task gate refuses every Write/Edit and every Bash command it cannot prove
# is a read, whenever focus is null. Focus goes null at exactly the moment a task
# closes. So the work that FOLLOWS a close, and the work that PRECEDES selecting
# the next task, has no task it can run under and is structurally unreachable —
# OBS-250, twelve-plus recorded instances, three in one day, one of which forced
# a worker to file a whole task (T-3530) purely to run `git commit`.
#
# Operator framing, 2026-09-28, which is the design and not just the motivation:
#
#   "Why is this rule in there? … we want to prevent rogue sabotage or unintended
#    mishap … and the only way we currently can ensure that all framework
#    governance is applied is by having an active task. So maybe we should have a
#    routine for this, which is a standing task."
#
# The gate exists for governance COVERAGE, not bookkeeping. Selection is work.
# Close-out is work. They need tasks, not exemptions. This is strictly better
# than the grace-window-on-focus alternative that was considered first: a grace
# window buys ergonomics by SUSPENDING the invariant for a period, while a
# standing task leaves "nothing gets done without a task" fully intact.
#
# ── THE RISK THIS FILE IS SHAPED AROUND ───────────────────────────────────────
#
# A standing task is a standing exemption. If WM-001 is permanently available as
# focus, an agent that does not want to scope real work can sit in it and edit
# source — which is precisely the rogue-action risk the gate exists to prevent,
# walking in through the front door.
#
# So the fence is ENFORCED, not advisory, and it is the same for all three:
#
#     UNDER WM FOCUS, NO SOURCE FILE MAY BE WRITTEN.
#
# The exempt paths (.context/, .tasks/, .claude/, .git/) still work, because
# those are what housekeeping legitimately writes. Everything else is refused.
# The moment work under a WM task needs to touch source, it has stopped being
# workflow management and needs a real task — which is exactly the line we want.
#
# Per-id Bash verb sets are deliberately NOT part of v1. They would be
# ergonomics; the safety property is carried entirely by the source-write fence,
# and differentiating verbs adds surface without adding protection. The three ids
# exist for ATTRIBUTION (R3) — so the record says which kind of housekeeping ran
# — not for differing privilege.
#
# ── WHY A SEPARATE DIRECTORY ──────────────────────────────────────────────────
#
# `.tasks/workflow/`, not `.tasks/active/` with a marker. Episodic generation,
# staleness audits, review-queue counts, arc completion ratios and
# `lib/tasks.sh:find_task_file` all glob `active/` and `completed/` and all
# assume a task eventually closes. A WM task never closes. Directory separation
# means those mechanisms skip it BY CONSTRUCTION; a marker would mean every one
# of them needs a special case, and the one that gets missed is a silent bug.

# Double-source guard, written as an `if` and NOT as `[ … ] && return 0`.
#
# The `&& return` form is the idiom used elsewhere in this repo (lib/tasks.sh),
# and it is unsafe for a file that may be sourced from INSIDE a function: a
# `return` executed in a sourced file returns from the enclosing function, so
# the second `. wm_tasks.sh` inside `do_focus()` would return from do_focus
# itself — silently, mid-way, with exit 0.
#
# Measured, not theorised (T-3537): with the `&& return` form,
# `fw context focus <completed-id>` printed nothing and exited 0, swallowing
# T-2874's "completed, not active" refusal entirely and re-opening the
# writable-but-unusable focus state that task exists to prevent. Three tests in
# focus_active_scope.bats went red and named it.
#
# The `if` form confines the skip to this file under every caller.
if [ -z "${_FW_WM_TASKS_LOADED:-}" ]; then
_FW_WM_TASKS_LOADED=1

#: The closed set. Adding a fourth is an operator decision, not a convenience —
#: an open namespace becomes the dumping ground within a month, and then the
#: fence is all that stands between WM and a general-purpose bypass.
FW_WM_IDS="WM-001 WM-002 WM-003"

# True when the id names a workflow-management task.
# Deliberately strict: WM-<3 digits>. `WM-1`, `WM-0001` and `wm-001` are not WM
# ids, so a typo fails closed (no task) rather than open (a fenced standing task).
fw_is_wm_task() {
    case "${1:-}" in
        WM-[0-9][0-9][0-9]) return 0 ;;
        *) return 1 ;;
    esac
}

# True when the id is one of the sanctioned three. `fw_is_wm_task` answers
# "does this LOOK like a WM id"; this answers "is it one we actually ship".
# The gate uses the shape check for routing and this one for admission, so an
# invented WM-742 cannot mint itself a standing exemption.
fw_is_known_wm_task() {
    local id="${1:-}" known
    for known in $FW_WM_IDS; do
        [ "$id" = "$known" ] && return 0
    done
    return 1
}

# Path to a WM task file, or empty. Never falls back to active/ or completed/:
# a WM id that is not in .tasks/workflow/ is not a task, and answering with a
# same-named file from elsewhere would be the mistaken-identity class.
fw_find_wm_task() {
    local id="${1:-}" root="${2:-${PROJECT_ROOT:-.}}"
    fw_is_wm_task "$id" || return 0
    local f
    f=$(find "$root/.tasks/workflow" -name "${id}-*.md" -type f 2>/dev/null | head -1)
    [ -n "$f" ] && echo "$f"
}

# The fence, as a single word. One fence today, by design (see header). The
# function exists so a future per-id fence has one place to land rather than
# growing a second predicate beside this one.
fw_wm_fence() {
    fw_is_wm_task "${1:-}" || return 1
    echo "no-source-writes"
}

# True when writing FILE_PATH is permitted under WM focus.
# Mirrors the gate's own exempt-path set (check-active-task.sh) rather than
# inventing a second list — if those diverge, one of them is wrong and nothing
# would say which.
fw_wm_write_allowed() {
    local file_path="${1:-}" root="${2:-${PROJECT_ROOT:-}}"
    [ -z "$file_path" ] && return 0   # not a Write/Edit; the caller gates Bash separately
    case "$file_path" in
        "$root"/.context/*|"$root"/.tasks/*|"$root"/.claude/*|"$root"/.git/*) return 0 ;;
        */.claude/projects/*/memory/*|*/.gemini/antigravity-cli/brain/*) return 0 ;;
    esac
    return 1
}

fi  # end double-source guard (see header)
