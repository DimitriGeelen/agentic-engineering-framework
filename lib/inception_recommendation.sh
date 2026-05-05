#!/bin/bash
# lib/inception_recommendation.sh
#
# Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA,
# T-1716 implementation). Used by:
#   - agents/audit/audit.sh    — C-006 detective check
#   - lib/inception.sh         — Stream C sweep (do_inception_sweep --recommendation-fix)
#
# Public functions:
#   has_real_recommendation <task_file>
#       Returns 0 if file's `## Recommendation` body contains a real
#       `**Recommendation:** GO|NO-GO|DEFER` line; 1 otherwise.
#
#   find_inceptions_without_recommendation <active_dir>
#       Prints, one per line, the task IDs (T-XXX) of inception tasks in
#       <active_dir> whose Recommendation block is template-only or empty.
#       Non-inception tasks are skipped.

# Guard against double-sourcing
[[ -n "${_FW_INCEPTION_RECOMMENDATION_LOADED:-}" ]] && return 0
_FW_INCEPTION_RECOMMENDATION_LOADED=1

has_real_recommendation() {
    local task_file="$1"
    [ -f "$task_file" ] || return 1
    # Strip HTML comments from the Recommendation section, then check for a
    # real recommendation line. Accepts bare ('**Recommendation:** GO'),
    # bulleted ('- **Recommendation:** GO'), or indented variants. The
    # comment-strip avoids false positives from the template's literal
    # '**Recommendation:** GO / NO-GO / DEFER' format-hint text.
    python3 - "$task_file" <<'PYHASRE'
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
m = re.search(r'^## Recommendation\s*\n(.*?)(?=^##\s|\Z)', content, re.DOTALL | re.MULTILINE)
if not m:
    sys.exit(1)
body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL)
# T-1746: tolerate inner emphasis on the verdict (`**GO**`, `*GO*`, plain).
# Without `\*{0,2}` this rejected T-1744's `**Recommendation:** **GO**` which
# was the trigger for the RC1 silent-failure (see T-1745 RCA).
if re.search(r'(?m)^[\-\*\s]*\*\*Recommendation:\*\*\s+\*{0,2}(GO|NO-GO|DEFER)\b', body):
    sys.exit(0)
sys.exit(1)
PYHASRE
}

find_inceptions_without_recommendation() {
    local active_dir="$1"
    [ -d "$active_dir" ] || return 0
    local task_file task_id
    while IFS= read -r task_file; do
        [ -z "$task_file" ] && continue
        # Confirm inception
        grep -q "^workflow_type:[[:space:]]*inception" "$task_file" 2>/dev/null || continue
        # Skip if real Recommendation present
        has_real_recommendation "$task_file" && continue
        # Emit task ID
        task_id=$(basename "$task_file" | grep -oE "^T-[0-9]+")
        [ -n "$task_id" ] && echo "$task_id"
    done < <(find "$active_dir" -maxdepth 1 -name "T-*.md" -type f 2>/dev/null)
}
