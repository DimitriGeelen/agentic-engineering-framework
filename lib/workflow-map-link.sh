#!/bin/bash
# lib/workflow-map-link.sh — T-5391: link a tagged task to its workflow map.
#
# fw_link_workflow_map TASK_FILE
#   A task tagged `outside-contributor` gets a `workflow_map:` field (the PR map)
#   in frontmatter and one **Workflow:** line under ## Context (the tag -> map table
#   is lib/workflow_map_link.py TAG_MAPS, the one place the map id is named).
#   Idempotent; an untagged task is not touched and no URL is resolved for it.
#   The base URL comes from lib/watchtower.sh (_watchtower_base_or_placeholder:
#   the live URL, or the port this project's Watchtower comes back on) — never a
#   hard-coded port (WATCHTOWER_URL overrides, as for every caller). Never fails
#   its caller: a failure is a warning on stderr.
fw_link_workflow_map() {
    local file="$1" fr="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    [ -f "$file" ] || return 0
    python3 "$fr/lib/workflow_map_link.py" needs "$file" 2>/dev/null || return 0
    local base
    declare -F _watchtower_base_or_placeholder >/dev/null 2>&1 \
        || source "$fr/lib/watchtower.sh" 2>/dev/null || true
    base=$(_watchtower_base_or_placeholder 2>/dev/null) || true
    if [ -z "$base" ]; then
        echo "WARN: workflow map link not written to $file (no Watchtower base URL)" >&2
        return 0
    fi
    python3 "$fr/lib/workflow_map_link.py" apply "$file" "$base" \
        || echo "WARN: workflow map link could not be written to $file" >&2
    return 0
}
