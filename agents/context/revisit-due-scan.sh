#!/usr/bin/env bash
# revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053)
#
# Scans $PROJECT_ROOT/.tasks/active/*.md for frontmatter `revisit_at: <YYYY-MM-DD>`
# entries whose date is <= today (UTC). Writes ripe matches to
# .context/working/.revisits-due.txt — one line per task:
#
#     T-XXX fires YYYY-MM-DD: <name>
#
# When no tasks are ripe the output file is removed entirely so downstream
# readers (handover banner, Watchtower) can treat "file absent" and "file
# empty" as the same signal — nothing to surface.
#
# Idempotent: re-running on the same day produces the same output.
#
# Designed to run from cron (silent on success, log to stderr on error).

set -euo pipefail

# Resolve PROJECT_ROOT: prefer env var (set by cron line); fall back to walking
# up from this script's location looking for the project shape marker
# (.framework.yaml for consumers, FRAMEWORK.md for the framework repo itself).
# T-1868 (G-063): the prior fixed-depth `../../..` form was vendored-only and
# silently resolved to `/opt/.tasks/active` when run inside the framework repo.
if [ -z "${PROJECT_ROOT:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _walk="$SCRIPT_DIR"
    while [ "$_walk" != "/" ]; do
        if [ -f "$_walk/.framework.yaml" ] || [ -f "$_walk/FRAMEWORK.md" ]; then
            PROJECT_ROOT="$_walk"
            break
        fi
        _walk="$(dirname "$_walk")"
    done
    if [ -z "${PROJECT_ROOT:-}" ]; then
        echo "revisit-due-scan: cannot resolve PROJECT_ROOT (no .framework.yaml or FRAMEWORK.md marker found walking up from $SCRIPT_DIR)" >&2
        exit 1
    fi
fi

TASKS_DIR="$PROJECT_ROOT/.tasks/active"
OUTPUT_FILE="$PROJECT_ROOT/.context/working/.revisits-due.txt"

if [ ! -d "$TASKS_DIR" ]; then
    echo "revisit-due-scan: tasks dir not found at $TASKS_DIR" >&2
    exit 0
fi

TODAY=$(date -u +%Y-%m-%d)

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

for f in "$TASKS_DIR"/*.md; do
    [ -f "$f" ] || continue
    # Pull frontmatter fields. revisit_at must be a *real* ISO date
    # (YYYY-MM-DD digits only), not the commented hint `# revisit_at: YYYY-MM-DD`
    # nor the literal placeholder string `YYYY-MM-DD`.
    revisit_at=$(awk '
        /^---$/ { n++; if (n==2) exit; next }
        n==1 && /^revisit_at:[[:space:]]/ {
            sub(/^revisit_at:[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$f")

    [ -z "$revisit_at" ] && continue
    [[ "$revisit_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue

    # Lexicographic compare on ISO dates is correct
    if [[ "$revisit_at" > "$TODAY" ]]; then
        continue
    fi

    id=$(awk '/^---$/{n++;if(n==2)exit;next} n==1 && /^id:/{sub(/^id:[[:space:]]*/,"");print;exit}' "$f")
    name=$(awk '/^---$/{n++;if(n==2)exit;next} n==1 && /^name:/{sub(/^name:[[:space:]]*"?/,"");sub(/"?[[:space:]]*$/,"");print;exit}' "$f")

    [ -z "$id" ] && continue
    echo "$id fires $revisit_at: $name" >> "$tmp"
done

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -s "$tmp" ]; then
    mv "$tmp" "$OUTPUT_FILE"
else
    rm -f "$OUTPUT_FILE"
fi

exit 0
