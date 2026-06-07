#!/usr/bin/env bash
# T-1850 (T-NEW-3): one-shot, idempotent migration `tags:[arc:X] → arc_id: X`.
#
# Scans .tasks/{active,completed}/*.md and rewrites frontmatter:
#   - Removes every `arc:<slug>` entry from the `tags:` list.
#   - Adds an `arc_id: <slug>` (or `arc_id: arc-NNN` for T-1848 form) field
#     IMMEDIATELY after the `related_tasks:` line.
#   - If a task has 0 arc tags → no change.
#   - If a task has exactly 1 arc tag AND the arc exists → migrate.
#   - If a task has exactly 1 arc tag but the arc YAML is missing (stale ref)
#     → clear the tag, do NOT set arc_id (would fail T-1849 hook); log WARN.
#   - If a task has >1 arc tags → halt unless --resolve T-XXXX=ARC_ID supplied
#     for that task. Refuse silent guess (matches T-1846 §4 Q2 answer).
#
# Writes a committable report to .context/audits/arc-id-migration-<date>.yaml.
# Idempotent: a second run finds no arc:* tags and exits with "no changes".
#
# Usage:
#   lib/migrations/arc-id-migration.sh --dry-run
#   lib/migrations/arc-id-migration.sh --apply [--resolve T-1717=embeddings-strategy] [--resolve T-1719=embeddings-strategy]
#
# Exit:
#   0 — success (incl. no-op idempotent run)
#   1 — runtime error
#   2 — usage error
#   3 — unresolved multi-arc cases (refused silent guess)
#
# Origin: T-1850 (T-NEW-3) of arc-grooming arc. Depends on T-1849 (arc_id
# field + Tier-1 validation hook). Closes T-1846 inception Q2 (committable
# migration report) + Q3 (T-1717/T-1719 → embeddings-strategy per-task call).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"

TASKS_DIR="$PROJECT_ROOT/.tasks"
ARCS_DIR="$PROJECT_ROOT/.context/arcs"
AUDITS_DIR="$PROJECT_ROOT/.context/audits"

MODE=""
declare -A RESOLVE_MAP

usage() {
    cat <<EOF
Usage: arc-id-migration.sh [--dry-run|--apply] [--resolve T-XXXX=ARC_ID]...

Modes:
  --dry-run   Scan + report only; no file changes.
  --apply     Rewrite task frontmatter + write report (committable).

Flags:
  --resolve T-XXXX=ARC_ID   Pre-resolve a multi-arc task to a specific arc.
                            Repeat for each multi-arc case.

Exit:
  0=ok  1=runtime  2=usage  3=unresolved-multi-arc
EOF
    exit "${1:-2}"
}

# --- arg parsing ---
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry-run"; shift ;;
        --apply)   MODE="apply"; shift ;;
        --resolve)
            shift
            [ -n "${1:-}" ] || { echo "Error: --resolve needs T-XXXX=ARC_ID" >&2; usage 2; }
            tid="${1%%=*}"
            arc="${1#*=}"
            [ "$tid" = "$1" ] || [ -z "$arc" ] && { echo "Error: --resolve form must be T-XXXX=ARC_ID, got: $1" >&2; usage 2; }
            RESOLVE_MAP["$tid"]="$arc"
            shift
            ;;
        -h|--help) usage 0 ;;
        *) echo "Error: unknown arg: $1" >&2; usage 2 ;;
    esac
done

[ -n "$MODE" ] || { echo "Error: must specify --dry-run or --apply" >&2; usage 2; }

# --- helpers ---
arc_exists() {
    local arc="$1"
    [ -f "$ARCS_DIR/${arc}.yaml" ] && return 0
    if [[ "$arc" =~ ^arc-[0-9]+$ ]]; then
        for f in "$ARCS_DIR"/*.yaml; do
            local stored
            stored=$(awk '/^id:[[:space:]]*/ {print $2; exit}' "$f")
            [ "$stored" = "$arc" ] && return 0
        done
    fi
    return 1
}

# Extract arc-tag list from a task's tags: line
# (single line form: `tags: [arc:foo, build, arc:bar]`)
extract_arc_tags() {
    local f="$1"
    awk '/^tags:/{print; exit}' "$f" | grep -oE 'arc:[a-zA-Z0-9_-]+' | sed 's/^arc://'
}

# --- scan phase ---
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_SHORT="$(date -u +%Y-%m-%d)"
REPORT_PATH="$AUDITS_DIR/arc-id-migration-${DATE_SHORT}.yaml"

declare -a TO_MIGRATE=()      # "PATH|TID|ARC_ID"
declare -a STALE_ARC=()       # "PATH|TID|ARC_ID(missing)"
declare -a MULTI_ARC=()       # "PATH|TID|comma,separated,arcs"
declare -a SKIP=()            # PATH (no arc:* tags)

shopt -s nullglob
for f in "$TASKS_DIR"/active/T-*.md "$TASKS_DIR"/completed/T-*.md; do
    [ -f "$f" ] || continue
    tid=$(basename "$f" | grep -oE '^T-[0-9]+')
    [ -n "$tid" ] || continue

    mapfile -t arcs < <(extract_arc_tags "$f")
    count=${#arcs[@]}

    if [ "$count" -eq 0 ]; then
        SKIP+=("$f")
        continue
    fi

    if [ "$count" -eq 1 ]; then
        arc="${arcs[0]}"
        if arc_exists "$arc"; then
            TO_MIGRATE+=("$f|$tid|$arc")
        else
            STALE_ARC+=("$f|$tid|$arc")
        fi
        continue
    fi

    # Multi-arc: resolve via flag or halt
    resolved="${RESOLVE_MAP[$tid]:-}"
    if [ -n "$resolved" ]; then
        if arc_exists "$resolved"; then
            TO_MIGRATE+=("$f|$tid|$resolved")
        else
            echo "Error: --resolve $tid=$resolved but arc '$resolved' does not exist." >&2
            exit 1
        fi
    else
        MULTI_ARC+=("$f|$tid|$(IFS=,; echo "${arcs[*]}")")
    fi
done

# --- multi-arc halt check ---
if [ ${#MULTI_ARC[@]} -gt 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  HALT — Unresolved multi-arc tasks (${#MULTI_ARC[@]})"
    echo "════════════════════════════════════════════════════════════"
    for row in "${MULTI_ARC[@]}"; do
        IFS='|' read -r _ tid arcs <<< "$row"
        echo "  $tid  →  arcs: $arcs"
    done
    echo ""
    echo "Refusing silent guess (T-1846 Q2 — committable, human-reviewable)."
    echo "Re-run with --resolve T-XXXX=ARC_ID for each case above, e.g.:"
    echo ""
    for row in "${MULTI_ARC[@]}"; do
        IFS='|' read -r _ tid _ <<< "$row"
        echo "  --resolve ${tid}=embeddings-strategy"
    done
    echo "════════════════════════════════════════════════════════════"
    exit 3
fi

# --- apply phase ---
APPLIED=0
APPLY_LOG=()

apply_one() {
    local f="$1" tid="$2" arc_id="$3"
    if [ "$MODE" = "dry-run" ]; then
        APPLIED=$((APPLIED + 1))
        APPLY_LOG+=("$tid|$arc_id|$f")
        return 0
    fi

    # Idempotency guard: if file already has arc_id: <arc_id> AND no arc:* in tags,
    # treat as already-migrated and skip.
    if awk '/^---/{n++} n==1' "$f" | grep -qE "^arc_id:[[:space:]]*${arc_id}\b"; then
        if ! awk '/^tags:/{print; exit}' "$f" | grep -qE "arc:${arc_id}\b"; then
            return 0  # Already migrated.
        fi
    fi

    python3 - "$f" "$arc_id" "$tid" <<'PY'
import sys, re
fn, arc_id, tid = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(fn).read()

# 1. Strip arc:<slug>, arc:<slug>,  and , arc:<slug> from the tags: line.
def strip_arc_tags(tags_line):
    m = re.match(r'^(tags:\s*)\[(.*)\]\s*$', tags_line)
    if not m:
        return tags_line
    inner = m.group(2)
    items = [x.strip() for x in inner.split(',')]
    kept = [x for x in items if x and not x.lstrip('"').lstrip("'").startswith('arc:')]
    return f"{m.group(1)}[{', '.join(kept)}]"

lines = text.split('\n')
in_fm = False
fm_end = -1
tags_idx = -1
related_idx = -1
arc_id_idx = -1
for i, ln in enumerate(lines):
    if ln == '---':
        if not in_fm:
            in_fm = True
            continue
        else:
            fm_end = i
            break
    if in_fm:
        if ln.startswith('tags:'):
            tags_idx = i
        elif ln.startswith('related_tasks:'):
            related_idx = i
        elif ln.startswith('arc_id:'):
            arc_id_idx = i

if tags_idx >= 0:
    lines[tags_idx] = strip_arc_tags(lines[tags_idx])

# 2. Write/replace arc_id field.
arc_id_line = f"arc_id: {arc_id}"
if arc_id_idx >= 0:
    lines[arc_id_idx] = arc_id_line
else:
    # Insert after related_tasks, or fallback to after tags, or just before fm_end.
    insert_at = (related_idx + 1) if related_idx >= 0 else (
        (tags_idx + 1) if tags_idx >= 0 else fm_end
    )
    lines.insert(insert_at, arc_id_line)

open(fn, 'w').write('\n'.join(lines))
print(f"wrote {tid} → arc_id: {arc_id}")
PY
    APPLIED=$((APPLIED + 1))
    APPLY_LOG+=("$tid|$arc_id|$f")
}

STALE_APPLIED=0
STALE_LOG=()

apply_stale() {
    local f="$1" tid="$2" arc="$3"
    if [ "$MODE" = "dry-run" ]; then
        STALE_APPLIED=$((STALE_APPLIED + 1))
        STALE_LOG+=("$tid|$arc|$f")
        return 0
    fi
    # Strip the stale arc: tag, but DO NOT add arc_id (would fail T-1849 hook).
    python3 - "$f" "$arc" "$tid" <<'PY'
import sys, re
fn, arc, tid = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(fn).read()
lines = text.split('\n')
in_fm = False
for i, ln in enumerate(lines):
    if ln == '---':
        if not in_fm:
            in_fm = True
            continue
        else:
            break
    if in_fm and ln.startswith('tags:'):
        m = re.match(r'^(tags:\s*)\[(.*)\]\s*$', ln)
        if m:
            inner = m.group(2)
            items = [x.strip() for x in inner.split(',')]
            kept = [x for x in items if x and not x.lstrip('"').lstrip("'").startswith('arc:')]
            lines[i] = f"{m.group(1)}[{', '.join(kept)}]"
            break
open(fn, 'w').write('\n'.join(lines))
print(f"cleared stale arc:{arc} from {tid} (no arc_id set — arc YAML missing)")
PY
    STALE_APPLIED=$((STALE_APPLIED + 1))
    STALE_LOG+=("$tid|$arc|$f")
}

for row in "${TO_MIGRATE[@]}"; do
    IFS='|' read -r f tid arc <<< "$row"
    apply_one "$f" "$tid" "$arc"
done
for row in "${STALE_ARC[@]}"; do
    IFS='|' read -r f tid arc <<< "$row"
    apply_stale "$f" "$tid" "$arc"
done

# --- report ---
mkdir -p "$AUDITS_DIR"
{
    echo "# T-1850 (T-NEW-3) — tags:[arc:*] → arc_id migration report"
    echo "# Generated: $TS"
    echo "# Mode: $MODE"
    echo ""
    echo "summary:"
    echo "  scanned: $((${#TO_MIGRATE[@]} + ${#STALE_ARC[@]} + ${#MULTI_ARC[@]} + ${#SKIP[@]}))"
    echo "  migrated: ${#TO_MIGRATE[@]}"
    echo "  stale_arc_cleared: ${#STALE_ARC[@]}"
    echo "  multi_arc_resolved: ${#RESOLVE_MAP[@]}"
    echo "  multi_arc_unresolved: ${#MULTI_ARC[@]}"
    echo "  no_arc_tag: ${#SKIP[@]}"
    echo ""
    echo "migrated:"
    for row in "${APPLY_LOG[@]}"; do
        IFS='|' read -r tid arc f <<< "$row"
        echo "  - task: $tid"
        echo "    arc_id: $arc"
        echo "    file: ${f#$PROJECT_ROOT/}"
    done
    echo ""
    echo "stale_arc_cleared:"
    for row in "${STALE_LOG[@]}"; do
        IFS='|' read -r tid arc f <<< "$row"
        echo "  - task: $tid"
        echo "    arc_tag_removed: $arc"
        echo "    note: arc YAML missing; tag cleared, arc_id left empty"
        echo "    file: ${f#$PROJECT_ROOT/}"
    done
    if [ ${#RESOLVE_MAP[@]} -gt 0 ]; then
        echo ""
        echo "resolutions_applied:"
        for tid in "${!RESOLVE_MAP[@]}"; do
            echo "  - task: $tid"
            echo "    resolved_to: ${RESOLVE_MAP[$tid]}"
        done
    fi
} > "$REPORT_PATH"

echo ""
echo "═══ Migration report ═══"
echo "  Mode:                  $MODE"
echo "  Scanned:               $((${#TO_MIGRATE[@]} + ${#STALE_ARC[@]} + ${#MULTI_ARC[@]} + ${#SKIP[@]}))"
echo "  Migrated:              ${#TO_MIGRATE[@]}"
echo "  Stale-arc cleared:     ${#STALE_ARC[@]}"
echo "  Multi-arc resolved:    ${#RESOLVE_MAP[@]}"
echo "  No arc tag (skipped):  ${#SKIP[@]}"
echo "  Report:                $REPORT_PATH"
echo "═════════════════════════"

exit 0
