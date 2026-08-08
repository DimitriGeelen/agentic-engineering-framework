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
# T-2865: SECOND, SEPARATE SIGNAL — .context/working/.revisits-undated.txt
#
# The absent==empty contract above is correct for the *dated* population and was
# silently catastrophic for the undated one. A task whose `## Decision` block
# records DEFER but which carries no usable `revisit_at` fails the ISO-date
# filter below and is skipped before any reporting logic runs. So the scanner
# had no state meaning "I found deferrals I cannot schedule" — the ripe file's
# absence meant both "nothing ripe" and "the entire deferred backlog is
# invisible", indistinguishably. Measured at adoption: 14 of 14 active DEFER
# decisions were undated, and `lib/inception.sh` never writes the field at all,
# so this is a missing seam rather than operator forgetfulness.
#
# Deliberately NOT extra lines in .revisits-due.txt. That file means "ripe
# today" and its consumer prints it under exactly that heading; a dateless
# deferral is not ripe, it has no date at all. Widening an existing signal to
# carry a second meaning is the mechanism that produced this ambiguity, and
# repeating it inside the fix would re-create it one layer down.
#
# Credit: found and fixed first by consumer project 832 in their vendored copy
# (their T-373), offered upstream on the DM rail, adopted here after measuring
# our own corpus. Their incidence was 1 of 1 — they declined to call that a
# percentage, which is why we measured rather than assumed.
#
# Both files follow the same absent==empty contract.
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
# T-2865: separate signal for deferrals that carry no usable date.
UNDATED_FILE="$PROJECT_ROOT/.context/working/.revisits-undated.txt"

# T-2865: does this task's `## Decision` block record a DEFER decision?
#
# Predicate is the line `**Decision**: DEFER` written by lib/inception.sh
# (`$decision_upper`) and by the Watchtower decide route. Two independent
# reasons this cannot match the shipped template text — which reads
# "fw inception decide T-XXX go|no-go|defer" inside an HTML comment:
# the comment body is stripped, AND the template line does not begin with
# `**Decision**:`. Belt and braces, because a false positive here would put
# every task in the project under the undated heading.
#
# `## Decisions` (plural, the alternatives log) must NOT match: the trailing
# "s" fails `[[:space:]]*$`.
_t2865_records_defer() {
    awk '
        /^## Decision[[:space:]]*$/ { d=1; c=0; next }
        /^##/                       { d=0; next }
        d {
            if (!c && $0 ~ /^[[:space:]]*<!--/) { c=1 }
            if (c) { if ($0 ~ /-->/) { c=0 } ; next }
            if (tolower($0) ~ /^\*\*decision\*\*:[[:space:]]*defer/) { found=1 }
        }
        END { exit(found ? 0 : 1) }
    ' "$1"
}

if [ ! -d "$TASKS_DIR" ]; then
    echo "revisit-due-scan: tasks dir not found at $TASKS_DIR" >&2
    exit 0
fi

TODAY=$(date -u +%Y-%m-%d)

tmp=$(mktemp)
tmp_undated=$(mktemp)
trap 'rm -f "$tmp" "$tmp_undated"' EXIT

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

    id=$(awk '/^---$/{n++;if(n==2)exit;next} n==1 && /^id:/{sub(/^id:[[:space:]]*/,"");print;exit}' "$f")
    name=$(awk '/^---$/{n++;if(n==2)exit;next} n==1 && /^name:/{sub(/^name:[[:space:]]*"?/,"");sub(/"?[[:space:]]*$/,"");print;exit}' "$f")

    [ -z "$id" ] && continue

    if [ -n "$revisit_at" ] && [[ "$revisit_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        # Dated: report only when ripe. Lexicographic compare on ISO dates is correct.
        if [[ "$revisit_at" > "$TODAY" ]]; then
            continue
        fi
        echo "$id fires $revisit_at: $name" >> "$tmp"
    else
        # T-2865: no usable date. This is the leg that used to `continue` here,
        # making the whole undated deferral population unobservable. Only tasks
        # that actually recorded a DEFER decision belong in the signal — a rule
        # that reported every dateless task would report all 324 and bury the
        # 14 it exists to raise.
        if _t2865_records_defer "$f"; then
            echo "$id: $name" >> "$tmp_undated"
        fi
    fi
done

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -s "$tmp" ]; then
    mv "$tmp" "$OUTPUT_FILE"
else
    rm -f "$OUTPUT_FILE"
fi

# T-2865: same absent==empty contract for the undated signal.
if [ -s "$tmp_undated" ]; then
    sort -o "$tmp_undated" "$tmp_undated"
    mv "$tmp_undated" "$UNDATED_FILE"
else
    rm -f "$UNDATED_FILE"
fi

exit 0
