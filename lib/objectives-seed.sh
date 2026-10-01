#!/usr/bin/env bash
# lib/objectives-seed.sh — the fw upgrade entry point for project objectives (T-3636).
#
# T-3535 IW-3 / rollout ruling 2026-09-30: every project authors
# .context/project/objectives.yaml ONCE, through its own entry point. Greenfield and
# existing-code onboarding seed that step at `fw init` (lib/seeds/tasks/*/). A consumer
# onboarded before the step existed gets it here: `fw upgrade` seeds a one-time
# "define objectives" task.
#
# Directive 4: this file never copies an objectives file anywhere. The framework's
# own .context/project/objectives.yaml is project state of THIS repo; a consumer gets
# a TASK to author its own, drafted from its own material.
#
# Idempotent by construction — the task is seeded only when BOTH hold:
#   1. the consumer has no .context/project/objectives.yaml, and
#   2. no task in .tasks/active/ or .tasks/completed/ carries the
#      `objectives-authoring` tag (the greenfield T-002, the existing-project T-007
#      and this upgrade task all carry it).
# So a second upgrade seeds nothing, and a project that closed the task without
# producing the file is not nagged with a second one (the audit is the place for that).
#
# Public functions:
#   fw_objectives_seed_status <project_dir>
#       prints: present | tasked <task-file> | needed
#   fw_objectives_seed_task <project_dir> <framework_root> <project_name>
#       writes the task, prints its path. Refuses (exit 1) unless status is `needed`.

FW_OBJECTIVES_TAG="objectives-authoring"

_fw_objectives_has_tag() {
    # Element-wise tag match in the frontmatter `tags:` line (T-2881 lesson: a
    # substring match would also hit e.g. `objectives-authoring-v2`).
    head -30 "$1" 2>/dev/null \
        | grep -qE "^tags:[[:space:]]*\[?([^]]*,)?[[:space:]]*${FW_OBJECTIVES_TAG}[[:space:]]*(,|\]|$)"
}

fw_objectives_seed_status() {
    local dir="$1" f
    if [ -f "$dir/.context/project/objectives.yaml" ]; then
        echo "present"
        return 0
    fi
    for f in "$dir"/.tasks/active/T-*.md "$dir"/.tasks/completed/T-*.md; do
        [ -f "$f" ] || continue
        if _fw_objectives_has_tag "$f"; then
            echo "tasked $f"
            return 0
        fi
    done
    echo "needed"
}

# Next free task id in <project_dir>. Same rule as create-task.sh generate_id:
# leading ^T-<n> of each filename, ascending, stop at the first gap larger than
# FW_ID_QUARANTINE_GAP (a quarantined high band does not set the next id).
_fw_objectives_next_id() {
    local dir="$1" gap_threshold="${FW_ID_QUARANTINE_GAP:-1000}"
    local f id n prev="" main_max=0 found=false
    local -a ids=()
    for f in "$dir"/.tasks/active/T-*.md "$dir"/.tasks/completed/T-*.md; do
        [ -f "$f" ] || continue
        id=$(basename "$f" | grep -oE '^T-[0-9]+' | grep -oE '[0-9]+')
        [ -n "$id" ] && ids+=("$((10#$id))")
    done
    if [ "${#ids[@]}" -gt 0 ]; then
        while IFS= read -r n; do
            if [ "$found" = false ]; then
                main_max=$n; found=true
            elif [ $((n - prev)) -gt "$gap_threshold" ]; then
                break
            else
                main_max=$n
            fi
            prev=$n
        done < <(printf '%s\n' "${ids[@]}" | sort -n -u)
    fi
    printf "T-%03d" $((main_max + 1))
}

fw_objectives_seed_task() {
    local dir="$1" framework_root="$2" project_name="$3"
    local tmpl="$framework_root/lib/seeds/tasks/upgrade/define-project-objectives.md"
    local status
    status=$(fw_objectives_seed_status "$dir")
    [ "$status" = "needed" ] || { echo "objectives seed not needed: $status" >&2; return 1; }
    [ -f "$tmpl" ] || { echo "objectives seed template missing: $tmpl" >&2; return 1; }

    local task_id now dest
    task_id=$(_fw_objectives_next_id "$dir")
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    mkdir -p "$dir/.tasks/active"
    dest="$dir/.tasks/active/${task_id}-define-project-objectives.md"
    # `|` is the sed delimiter; strip it from the project name so a directory
    # name cannot break the substitution.
    project_name="${project_name//|/-}"
    sed -e "s|__TASK_ID__|$task_id|g" \
        -e "s|__PROJECT_NAME__|$project_name|g" \
        -e "s|__DATE__|$now|g" \
        "$tmpl" > "$dest" || return 1
    echo "$dest"
}
