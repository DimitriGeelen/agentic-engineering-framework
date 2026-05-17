#!/bin/bash
# lib/evolution_log.sh
#
# Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern
# (T-1718 implementation). Mirrors lib/inception_recommendation.sh
# (T-1716) shape exactly: detection helper extracted so it can be
# tested without spinning up update-task.sh.
#
# Used by:
#   - agents/task-create/update-task.sh — check_evolution_log gate
#   - (future) agents/audit/audit.sh    — detective check for missing logs
#   - (future) lib/evolution_log.sh sweep mode
#
# Public functions:
#   has_real_evolution_log <task_file>
#       Returns 0 if the file's `## Evolution` section body contains
#       at least one substantive (≥30 chars, not a comment) line.
#       Comments stripped before matching to avoid template false-
#       positives.
#       Returns 1 if section is missing, empty, or template-only.
#
#   has_evolution_section <task_file>
#       Returns 0 if `## Evolution` heading exists in the file.
#       Used by the gate to skip-no-op on backward-compat tasks
#       (tasks created before the template change don't get gated).
#
#   find_arc_tasks_without_evolution_log <active_dir>
#       Prints, one per line, the task IDs (T-XXX) of arc-tagged
#       build tasks in <active_dir> whose Evolution section exists
#       but is template-only or empty. Non-arc / non-build tasks
#       skipped.

# Guard against double-sourcing
[[ -n "${_FW_EVOLUTION_LOG_LOADED:-}" ]] && return 0
_FW_EVOLUTION_LOG_LOADED=1

has_evolution_section() {
    local task_file="$1"
    [ -f "$task_file" ] || return 1
    grep -q '^## Evolution\b' "$task_file" 2>/dev/null
}

# T-1879 (T-NEW-14) / T-1880 (T-NEW-15): `task_has_arc_membership` is
# now exported from the shared `lib/arc_membership.sh` module. Source it
# here so existing callers (find_arc_tasks_without_evolution_log below,
# and the source-from-update-task.sh entrypoint) continue to work.
#
# Helper script may be sourced before paths are wired — guard the path
# resolution so we don't fail if FRAMEWORK_ROOT isn't yet set.
__el_lib_dir="${BASH_SOURCE[0]%/*}"
# shellcheck disable=SC1091
. "$__el_lib_dir/arc_membership.sh"
unset __el_lib_dir

has_real_evolution_log() {
    local task_file="$1"
    [ -f "$task_file" ] || return 1
    # Strip HTML comments from the Evolution section, then check for at
    # least one substantive line (≥30 chars after trim, not a heading
    # or empty). Substantive heuristic mirrors T-1550 RCA gate.
    python3 - "$task_file" <<'PYHASEV'
import re, sys
try:
    with open(sys.argv[1]) as f:
        content = f.read()
except OSError:
    sys.exit(1)
m = re.search(r'^## Evolution\s*\n(.*?)(?=^##\s|\Z)', content, re.DOTALL | re.MULTILINE)
if not m:
    sys.exit(1)
body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL)
# Substantive line = stripped length ≥30, not pure heading/empty/dash list bullet
substantive = []
for line in body.splitlines():
    s = line.strip()
    if not s:
        continue
    if s.startswith('#'):  # heading lines don't count alone
        continue
    if len(s) >= 30:
        substantive.append(s)
sys.exit(0 if substantive else 1)
PYHASEV
}

find_arc_tasks_without_evolution_log() {
    local active_dir="$1"
    [ -d "$active_dir" ] || return 0
    local task_file task_id
    while IFS= read -r task_file; do
        [ -z "$task_file" ] && continue
        # Only build tasks
        grep -q '^workflow_type:[[:space:]]*build' "$task_file" 2>/dev/null || continue
        # T-1879 (T-NEW-14): Only arc-member tasks — use frontmatter helper
        # that recognizes both arc_id (T-1849 canonical, T-1850 migrated)
        # AND legacy arc:<slug> tag.
        task_has_arc_membership "$task_file" || continue
        # Skip if no Evolution section (backward-compat)
        has_evolution_section "$task_file" || continue
        # Flag if section exists but empty/template
        has_real_evolution_log "$task_file" && continue
        # Emit task ID
        task_id=$(basename "$task_file" | grep -oE '^T-[0-9]+')
        [ -n "$task_id" ] && echo "$task_id"
    done < <(find "$active_dir" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null)
}
