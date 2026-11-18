#!/bin/bash
# fw task create-batch — create many tasks in one call (T-5221, slice 2 of inception T-5212).
#
# Design: docs/reports/T-5212-batch-task-creation.md (1409's prototype, 2.6 s per unit).
#
#   fw task create-batch --spec F.jsonl --purpose <text> [--dry-run]
#
# F.jsonl holds one JSON object per line (blank lines and lines starting with # are skipped):
#   {"name": "...", "description": "...", "type": "build", "owner": "agent",
#    "horizon": "next", "tags": ["a", "b"] | "a,b", "related": [...] | "T-1,T-2",
#    "arc_id": "<arc slug or arc-NNN>"}
# name, description, type and owner are required; horizon defaults to now.
#
# Order, and why:
#   1. Every entry is checked by the rules create-task uses (lib/task-create-rules.sh), plus
#      the batch's own refusals: no inception (it needs a recommendation and a decision of
#      its own), no start/focus, no origin. One invalid entry refuses the whole batch, before
#      any id is reserved.
#   2. One reservation: fw_id_allocate N (lib/idalloc.sh) — one lock, one union-scan check.
#   3. All files through the one writer (lib/render_task.py), each linked into place
#      exclusively, so a kill leaves only complete files. Bytes equal create-task's for the
#      same entry (an entry with arc_id gains one `arc_id:` line).
#   4. The ledger's created rows, in one append, at the end. A batch killed before this step
#      leaves the reservation incomplete in the ledger, and `fw task id reconcile` says so.
#
# What runs once per batch rather than once per task: process start-up and library loading,
# the allocation lock and the union-scan check, the template reads, the python start for
# rendering, and the ledger append. Nothing in create-task's per-task tail applies to a
# batch: origin, the inception recommendation block and --start focus are all refused.
#
# Exit: 0 created (or dry run), 1 refused / write failed, 2 usage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/enums.sh"
source "$FRAMEWORK_ROOT/lib/task-create-rules.sh"
source "$FRAMEWORK_ROOT/lib/idalloc.sh"

usage() {
    cat <<'EOF'
Usage: fw task create-batch --spec F.jsonl --purpose <text> [--dry-run] [--new-arc SLUG]

Create every task in F.jsonl with one id reservation and one writer (T-5221).

  --spec F.jsonl    one JSON object per line: name, description, type, owner (required),
                    horizon (default now), tags, related, arc_id
  --purpose TEXT    recorded on the reservation in the id ledger (e.g. "arc:oslo-scan")
  --dry-run         validate and list what would be created; reserve and write nothing
  --new-arc SLUG    entries may name arc SLUG although it does not exist yet (fw arc
                    instantiate validates the tasks before it creates the arc)

Refused in a batch: inception tasks, start/focus, origin, recommendation. Use
fw task create / fw inception start for those. At most FW_ID_BLOCK_MAX (100) entries.
EOF
}

SPEC="" PURPOSE="" DRY_RUN=false NEW_ARC=""
while [ $# -gt 0 ]; do
    case "$1" in
        --spec) SPEC="${2:-}"; shift 2 ;;
        --spec=*) SPEC="${1#*=}"; shift ;;
        --purpose) PURPOSE="${2:-}"; shift 2 ;;
        --purpose=*) PURPOSE="${1#*=}"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --new-arc) NEW_ARC="${2:-}"; shift 2 ;;
        --start|--origin|--origin=*|--recommendation|--rationale|--i-am-human)
            echo "create-batch: $1 is refused in a batch (no start/focus, origin or inception options; T-5212)" >&2
            exit 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "create-batch: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done
[ -n "$SPEC" ] || { echo "create-batch: --spec is required" >&2; usage >&2; exit 2; }
[ -n "$PURPOSE" ] || { echo "create-batch: --purpose is required (it is recorded on the reservation)" >&2; exit 2; }
[ -f "$SPEC" ] || { echo "create-batch: spec not found: $SPEC" >&2; exit 2; }

ARCS_DIR="${PROJECT_ROOT}/.context/arcs"
_arc_known() {
    local a="$1"
    # A slug or arc-NNN only: no path component (T-5221 review 10; check-arc-id's rule).
    [[ "$a" =~ ^[a-z][a-z0-9-]{1,63}$ ]] || return 1
    [ -n "$NEW_ARC" ] && [ "$a" = "$NEW_ARC" ] && return 0
    [ -f "$ARCS_DIR/$a.yaml" ] && return 0
    [[ "$a" =~ ^arc-[0-9]+$ ]] && grep -lqx "id: $a" "$ARCS_DIR"/*.yaml 2>/dev/null && return 0
    return 1
}

# 1. Parse (python, one start) and validate every entry (shared rules) before reserving.
_TMP="$(mktemp -d "${TMPDIR:-/tmp}/fw-create-batch.XXXXXX")"
trap 'rm -rf "$_TMP"' EXIT
# --tasks-dir: every entry is also rendered under a placeholder id and its frontmatter
# parsed, so an entry that cannot be represented refuses here, before the reservation.
python3 "$FRAMEWORK_ROOT/lib/render_task.py" parse-spec "$SPEC" \
    --tasks-dir "$TASKS_DIR" --framework-root "$FRAMEWORK_ROOT" > "$_TMP/fields" || exit 2
declare -a F=()
while IFS= read -r -d '' _f; do F+=("$_f"); done < "$_TMP/fields"
N=$(( ${#F[@]} / 8 ))

_bad=0
for ((k = 0; k < N; k++)); do
    b=$((k * 8))
    name="${F[b]}" desc="${F[b+1]}" wtype="${F[b+2]}" owner="${F[b+3]}" horizon="${F[b+4]}" arc="${F[b+7]}"
    _err=$(
        exec 2>&1
        _missing=""
        [ -n "$name" ] || _missing="$_missing name"
        [ -n "$desc" ] || _missing="$_missing description"
        [ -n "$wtype" ] || _missing="$_missing type"
        [ -n "$owner" ] || _missing="$_missing owner"
        [ -z "$_missing" ] || { echo "missing required field(s):$_missing"; exit 1; }
        task_rule_name "$name" || exit 1
        task_rule_fields "$name" "$wtype" "$horizon" "$owner" || exit 1
        if [ "$wtype" = "inception" ]; then
            echo "inception tasks are refused in a batch — file them with fw inception start (they need a recommendation)"
            exit 1
        fi
        # T-2543/T-2577: gated writers' origin rule, same as create-task.
        case "${FW_TASK_ORIGIN:-}" in
            bpmn-promote|designer-ghost)
                [ "$owner" = "human" ] || { echo "BLOCKED: ${FW_TASK_ORIGIN}-origin create must be owner:human (got '$owner')."; exit 1; } ;;
        esac
        if [ -n "$arc" ] && ! _arc_known "$arc"; then
            echo "arc_id '$arc' does not resolve to an arc under .context/arcs/ (T-1849)"
            exit 1
        fi
        exit 0
    ) || {
        _bad=$((_bad + 1))
        printf 'create-batch: entry %d (%s):\n%s\n' "$((k + 1))" "${name:-<no name>}" "$(printf '%s' "$_err" | sed 's/^/  /')" >&2
    }
done
if [ "$_bad" -gt 0 ]; then
    echo "create-batch: refused — $_bad of $N entries invalid; no id reserved, nothing written" >&2
    exit 1
fi
_max="${FW_ID_BLOCK_MAX:-$FW_ID_BLOCK_MAX_HARD}"
[[ "$_max" =~ ^[0-9]+$ ]] && [ "$_max" -le "$FW_ID_BLOCK_MAX_HARD" ] || _max=$FW_ID_BLOCK_MAX_HARD
if [ "$N" -gt "$_max" ]; then
    echo "create-batch: refused — $N entries exceeds the block maximum of $_max (FW_ID_BLOCK_MAX); split the spec" >&2
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo "create-batch: dry run — $N task(s) valid, would reserve $N id(s) for '$PURPOSE':"
    for ((k = 0; k < N; k++)); do
        b=$((k * 8))
        printf '  %-10s %-9s %-6s %s%s\n' "${F[b+2]}" "${F[b+3]}" "${F[b+4]}" "${F[b]}" "${F[b+7]:+  [arc ${F[b+7]}]}"
    done
    exit 0
fi

# 2. One reservation.
IDS=$(fw_id_allocate "$N" "$PURPOSE") || { echo "create-batch: id reservation failed; nothing written" >&2; exit 1; }
ID_LIST=$(printf '%s' "$IDS" | tr '\n' ',')

# 3. One writer. Paths stream out as each file lands, so a failure part-way still knows
#    which ids have files.
_wrc=0
python3 "$FRAMEWORK_ROOT/lib/render_task.py" write-batch \
    --tasks-dir "$TASKS_DIR" --framework-root "$FRAMEWORK_ROOT" \
    --spec "$SPEC" --ids "$ID_LIST" > "$_TMP/written" || _wrc=$?
_written=()
while IFS= read -r _p; do [ -n "$_p" ] && _written+=("$_p"); done < "$_TMP/written"

# 4. Created rows for the files that exist, in one append.
_created=()
for _p in "${_written[@]+"${_written[@]}"}"; do
    _b="${_p##*/}"
    [[ "$_b" =~ ^(T-[0-9]+) ]] && _created+=("${BASH_REMATCH[1]}")
done
[ "${#_created[@]}" -eq 0 ] || fw_id_ledger_created "${_created[@]}"

if [ "$_wrc" != "0" ]; then
    echo "create-batch: write failed after ${#_written[@]} of $N file(s); the rest of the reservation is unused — fw task id reconcile reports it" >&2
    exit 1
fi

_first="$(printf '%s\n' "$IDS" | head -1)" _lastid="$(printf '%s\n' "$IDS" | tail -1)"
echo "create-batch: created $N task(s) ${_first}..${_lastid} for '$PURPOSE'"
for _p in "${_written[@]}"; do
    echo "  $(basename "$_p" .md)"
done
