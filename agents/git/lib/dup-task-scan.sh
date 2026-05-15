#!/bin/bash
# T-1863: Duplicate task-ID scanner (G-052 prevention).
#
# Scans the staged tree (or the working tree, depending on mode) for any
# T-NNNN identifier that appears in BOTH .tasks/active/ AND .tasks/completed/.
# This is the same check `fw audit` runs (T-1279), but at the commit boundary
# so orphans cannot survive into a commit.
#
# Mode:
#   scan-staged    — uses `git ls-files --cached` (default; for pre-commit)
#   scan-worktree  — uses the on-disk filenames (for ad-hoc checks)
#
# Exit:
#   0  no duplicates
#   1  duplicates found (message on stderr)
#
# Origin: T-1863 — orphan T-1859 active+completed pair, detected only 3 days
# post-leak by pre-push audit. Pre-commit gate catches it at the source.

set -e

MODE="${1:-scan-staged}"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

case "$MODE" in
    scan-staged)
        # `git ls-files --cached` lists the index; in a pre-commit hook this is
        # exactly what the next commit will contain.
        files=$(cd "$PROJECT_ROOT" && git ls-files --cached -- '.tasks/active/T-*.md' '.tasks/completed/T-*.md' 2>/dev/null)
        ;;
    scan-worktree)
        files=$( { ls -1 "$PROJECT_ROOT/.tasks/active/" 2>/dev/null | grep -E '^T-[0-9]+.*\.md$' | sed 's|^|.tasks/active/|'
                   ls -1 "$PROJECT_ROOT/.tasks/completed/" 2>/dev/null | grep -E '^T-[0-9]+.*\.md$' | sed 's|^|.tasks/completed/|'
                 } )
        ;;
    *)
        echo "dup-task-scan: unknown mode '$MODE' (use scan-staged|scan-worktree)" >&2
        exit 2
        ;;
esac

# Extract T-NNNN per side, find intersection.
active_ids=$(echo "$files" | grep -E '^\.tasks/active/T-[0-9]+' | grep -oE 'T-[0-9]+' | sort -u)
completed_ids=$(echo "$files" | grep -E '^\.tasks/completed/T-[0-9]+' | grep -oE 'T-[0-9]+' | sort -u)

dups=$(comm -12 <(echo "$active_ids") <(echo "$completed_ids") 2>/dev/null | grep -E '^T-[0-9]+' || true)

if [ -z "$dups" ]; then
    exit 0
fi

echo "Duplicate task IDs detected (G-052):" >&2
while IFS= read -r tid; do
    [ -z "$tid" ] && continue
    echo "  $tid:" >&2
    echo "$files" | grep -E "^\.tasks/(active|completed)/${tid}-" | sed 's/^/    - /' >&2
done <<< "$dups"

exit 1
