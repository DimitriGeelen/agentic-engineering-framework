#!/usr/bin/env bash
# lib/idalloc.sh — the one task-id allocator (T-5217, slice 1 of inception T-5212).
#
# Design: 1409's proposal (their T-6848), recorded in docs/reports/T-5212-batch-task-creation.md.
#
# WHY ONE ALLOCATOR. Before this file, agents/task-create/create-task.sh (generate_id) and
# lib/objectives-seed.sh (T-5213) each computed "max + 1" on their own, and generate_id
# union-scanned every worktree's .tasks/ on every create (2-4 s per id with 24 worktrees).
# 1409 measured that an old allocator running beside a block allocator reissues an id from an
# aborted reservation once more than FW_ID_QUARANTINE_GAP ids are reserved and unused. So every
# task id in a repository is handed out here, and `fw doctor` warns when another path remains.
#
# THE PIECES (all under <main worktree>/.tasks/):
#   .id-highwater     the counter: the highest id ever handed out. Read and raised only under
#                     the task-id-allocation lock, written tmp+rename, never lowered except
#                     when it points past the quarantine cliff (see "counter in quarantine").
#                     Same file and same meaning as the T-4189 mark, so an older allocator in
#                     another view still reads it.
#   .id-ledger.jsonl  append-only, tracked in git. Rows, one JSON object per line:
#                       {"event":"adopt","last":N,...}          ids <= N predate the ledger
#                       {"event":"reserve","first":A,"last":B,"n":K,"purpose":..,"ts":..,"pid":..,"view":..}
#                       {"event":"created","id":N,"ts":..}
#                       {"event":"heal","from":X,"to":Y,"reason":..,"ts":..}
#                     The reserve row is written BEFORE the counter, so a crash between the two
#                     leaves a ledger the next allocation (and `fw task id reconcile --heal`)
#                     raises the counter from — an id is skipped, never reused.
#
# THE CHECK (FW_ID_CHECK, default 1): once per reservation, the union scan of T-4189/T-100202
# runs as a check: every view's task files, every view's mark and every ledger reservation are
# intervals; walking up from the bottom, the first step larger than FW_ID_QUARANTINE_GAP is the
# quarantine cliff. Ledger ids count as used, so a large partly-unused block never pushes later
# ids into quarantine. The result may only raise the counter. FW_ID_CHECK=0 skips the scan and
# costs one counter read plus the ledger tail; a missing counter always runs the check.
#
# Shell, not Python: the hot path is a lock, a counter read and a couple of appends; a python3
# start per id would cost more than the work. Reconciliation, which parses the whole ledger and
# reports, is lib/idalloc_reconcile.py.
#
# Public:
#   fw_id_allocate N [purpose]   prints N ids (T-NNN), one per line, contiguous. N <= FW_ID_BLOCK_MAX.
#   fw_id_ledger_created ID..    appends a created row per id (call after the task files are written).
#   fw_id_main_view              prints <main worktree>/.tasks (the counter's directory).
#   fw_id_other_allocators DIR.. prints files under DIR.. that mint task ids outside this file.

[ -n "${_FW_IDALLOC_LOADED:-}" ] && return 0
_FW_IDALLOC_LOADED=1

_FW_IDALLOC_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_ID_BLOCK_MAX_HARD=100

# <main worktree>/.tasks for the repo that owns $TASKS_DIR; $TASKS_DIR itself outside git or
# when the main worktree has no .tasks/ (the same anchor create-task uses for its lock).
fw_id_main_view() {
    local base wt
    base="$(cd "$(dirname "$TASKS_DIR")" 2>/dev/null && pwd)"
    if [ -n "$base" ]; then
        wt="$(git -C "$base" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -1)"
        if [ -n "$wt" ] && [ -d "$wt/.tasks" ]; then
            printf '%s\n' "$wt/.tasks"
            return 0
        fi
    fi
    printf '%s\n' "$TASKS_DIR"
}

_fw_idalloc_views() {
    if ! declare -F fw_task_view_dirs >/dev/null 2>&1; then
        # shellcheck source=lib/paths.sh
        local _keep_tasks_dir="$TASKS_DIR"
        source "$_FW_IDALLOC_LIB/paths.sh" 2>/dev/null
        TASKS_DIR="$_keep_tasks_dir"
    fi
    fw_task_view_dirs
}

_fw_idalloc_json_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//[$'\t\n\r']/ }"
    printf '"%s"' "$s"
}

# Highest id the ledger has reserved (0 when none). Reads only the tail: reservations are
# appended in counter order under the lock, so the newest reserve row holds the maximum.
_fw_idalloc_ledger_tail_max() {
    local ledger="$1"
    [ -f "$ledger" ] || { echo 0; return 0; }
    tail -n 50 "$ledger" 2>/dev/null | awk '
        /"event":"(reserve|adopt)"/ && match($0, /"last":[0-9]+/) {
            v = substr($0, RSTART + 7, RLENGTH - 7) + 0; if (v > m) m = v }
        END { print m + 0 }'
}

# The check: print the main-cluster maximum over files, marks and ledger reservations.
_fw_idalloc_scan() {
    local gap="$1" ledger="$2" d mark
    local -a dirs=()
    while IFS= read -r d; do
        [ -d "$d/active" ] && dirs+=("$d/active")
        [ -d "$d/completed" ] && dirs+=("$d/completed")
        mark=$(head -n1 "$d/.id-highwater" 2>/dev/null) || mark=""
        [[ "$mark" =~ ^[0-9]+$ ]] && printf 'm %s\n' "$((10#$mark))" >&3
    done 3>"${_FW_IDALLOC_TMP}.marks" < <(_fw_idalloc_views)
    {
        cat "${_FW_IDALLOC_TMP}.marks"
        [ "${#dirs[@]}" -gt 0 ] && find "${dirs[@]}" -maxdepth 1 -name 'T-*.md' -printf 'f %f\n' 2>/dev/null
        [ -f "$ledger" ] && cat "$ledger"
    } | awk '
        $1 == "m" { print $2, $2; next }
        $1 == "f" { if (match($2, /^T-[0-9]+/)) { v = substr($2, 3, RLENGTH - 2) + 0; print v, v }; next }
        /"event":"reserve"/ && match($0, /"first":[0-9]+/) {
            a = substr($0, RSTART + 8, RLENGTH - 8) + 0
            if (match($0, /"last":[0-9]+/)) print a, substr($0, RSTART + 7, RLENGTH - 7) + 0
            next }
        /"event":"adopt"/ && match($0, /"last":[0-9]+/) {
            v = substr($0, RSTART + 7, RLENGTH - 7) + 0; print v, v }' \
      | sort -n -k1,1 -k2,2 \
      | awk -v gap="$gap" '
        NR == 1 { m = $2; next }
        $1 - m > gap { exit }
        $2 > m { m = $2 }
        END { print m + 0 }'
    rm -f "${_FW_IDALLOC_TMP}.marks"
}

_fw_idalloc_write_counter() {
    local file="$1" value="$2" tmp
    tmp="$file.tmp.$BASHPID"
    printf '%s\n' "$value" > "$tmp" && mv -f "$tmp" "$file"
}

_fw_idalloc_append() {
    printf '%s\n' "$2" >> "$1"
}

fw_id_allocate() {
    local n="${1:-}" purpose="${2:-unspecified}"
    local max="${FW_ID_BLOCK_MAX:-$FW_ID_BLOCK_MAX_HARD}"
    local gap="${FW_ID_QUARANTINE_GAP:-1000}"
    [[ "$max" =~ ^[0-9]+$ ]] && [ "$max" -le "$FW_ID_BLOCK_MAX_HARD" ] && [ "$max" -lt "$gap" ] \
        || max=$FW_ID_BLOCK_MAX_HARD
    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ]; then
        echo "fw_id_allocate: N must be a positive integer (got '${n}')" >&2
        return 2
    fi
    if [ "$n" -gt "$max" ]; then
        echo "fw_id_allocate: refused — $n ids exceeds the block maximum of $max (FW_ID_BLOCK_MAX)" >&2
        return 2
    fi

    local view counter ledger
    view="$(fw_id_main_view)"
    counter="$view/.id-highwater"
    ledger="$view/.id-ledger.jsonl"

    # Lock: reuse the caller's hold (create-task keeps it across the file write), else take it
    # at the main worktree like create-task does.
    local own_lock=false
    # T-5218: test for an existing hold only once _KEYLOCK_FDS is an associative array. Before
    # keylock.sh is sourced, bash reads the subscript as arithmetic (task - id - allocation) and
    # `set -u` aborts on the unset `task` — every cold caller (objectives-seed) crashed here.
    local _held=""
    if declare -p _KEYLOCK_FDS 2>/dev/null | grep -q '^declare -A'; then
        _held="${_KEYLOCK_FDS[task-id-allocation]:-}"
    fi
    if [ -z "$_held" ]; then
        if ! declare -F keylock_acquire >/dev/null 2>&1; then
            # shellcheck source=lib/keylock.sh
            source "$_FW_IDALLOC_LIB/keylock.sh" || return 1
        fi
        local wt_root
        wt_root="$(dirname "$view")"
        if [ -d "$wt_root/.context/locks" ]; then
            KEYLOCK_DIR="$wt_root/.context/locks"
        else
            KEYLOCK_DIR="$wt_root/.context/locks"
        fi
        keylock_acquire "task-id-allocation" || return 1
        own_lock=true
    fi

    _FW_IDALLOC_TMP="$(mktemp -u "${TMPDIR:-/tmp}/fw-idalloc.XXXXXX")"
    local rc=0 stored="" cur last ts row heal_reason=""
    {
        stored=$(head -n1 "$counter" 2>/dev/null) || stored=""
        [[ "$stored" =~ ^[0-9]+$ ]] && stored=$((10#$stored)) || stored=""

        if [ -z "$stored" ] || [ "${FW_ID_CHECK:-1}" != "0" ]; then
            cur=$(_fw_idalloc_scan "$gap" "$ledger") || cur=""
            [[ "$cur" =~ ^[0-9]+$ ]] || { echo "fw_id_allocate: check failed" >&2; rc=1; }
            if [ "$rc" -eq 0 ]; then
                if [ -z "$stored" ]; then
                    [ -f "$ledger" ] && heal_reason="counter-missing"
                elif [ "$cur" -lt "$stored" ]; then
                    heal_reason="counter-in-quarantine"
                elif [ "$cur" -gt "$stored" ]; then
                    heal_reason="check-raised"
                fi
            fi
        else
            cur=$stored
            last=$(_fw_idalloc_ledger_tail_max "$ledger")
            if [ "$last" -gt "$cur" ]; then cur=$last; heal_reason="ledger-above-counter"; fi
        fi

        if [ "$rc" -eq 0 ]; then
            ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            if [ ! -f "$ledger" ]; then
                _fw_idalloc_append "$ledger" "{\"event\":\"adopt\",\"last\":$cur,\"ts\":\"$ts\"}" || rc=1
            elif [ -n "$heal_reason" ]; then
                _fw_idalloc_append "$ledger" "{\"event\":\"heal\",\"from\":${stored:-null},\"to\":$cur,\"reason\":\"$heal_reason\",\"by\":\"allocate\",\"ts\":\"$ts\"}" || rc=1
            fi
        fi
        if [ "$rc" -eq 0 ]; then
            last=$((cur + n))
            row="{\"event\":\"reserve\",\"first\":$((cur + 1)),\"last\":$last,\"n\":$n,\"purpose\":$(_fw_idalloc_json_str "$purpose"),\"ts\":\"$ts\",\"pid\":$BASHPID,\"view\":$(_fw_idalloc_json_str "$TASKS_DIR")}"
            # Ledger before counter: a crash between them skips ids, never reuses them.
            _fw_idalloc_append "$ledger" "$row" && _fw_idalloc_write_counter "$counter" "$last" || rc=1
        fi
    }
    if [ "$own_lock" = true ]; then keylock_release "task-id-allocation"; fi
    [ "$rc" -eq 0 ] || { echo "fw_id_allocate: could not reserve ids (ledger or counter not writable: $view)" >&2; return 1; }

    local i
    for ((i = cur + 1; i <= last; i++)); do printf 'T-%03d\n' "$i"; done
}

# Record that task ID now has a file. Best effort: a missing created row is reported by
# reconcile as an incomplete reservation, it never breaks a create.
fw_id_ledger_created() {
    # T-5221: several ids in one append (create-batch marks its reservation created at the end).
    local view ts rows="" a id
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    for a in "$@"; do
        id="${a#T-}"
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        rows+="{\"event\":\"created\",\"id\":$((10#$id)),\"ts\":\"$ts\"}"$'\n'
    done
    [ -n "$rows" ] || return 0
    view="$(fw_id_main_view)"
    printf '%s' "$rows" >> "$view/.id-ledger.jsonl" 2>/dev/null || true
}

# Files under the given roots that mint a task id themselves: they format "T-%03d"-style ids
# from a computed maximum. lib/idalloc.sh is the one allowed path. Used by `fw doctor`.
fw_id_other_allocators() {
    local root
    for root in "$@"; do
        [ -d "$root" ] || continue
        grep -rlE --include='*.sh' --include='*.py' --include='fw' \
            "printf[[:space:]]+[\"']T-%0?[0-9]*d|f[\"']T-\{[^}]*\+[[:space:]]*1|[\"']T-%0?[0-9]*d[\"'][[:space:]]*%" \
            "$root/lib" "$root/agents" "$root/bin" 2>/dev/null \
            | grep -v '/lib/idalloc\.sh$' || true
    done | sort -u
}

# One line for `fw doctor` (T-5217): "OK ..." when lib/idalloc.sh is the only task-id allocator
# in the framework copy and in every other worktree's copy, else "WARN ..." naming the others.
# Args: framework root, project root.
fw_id_doctor_line() {
    local fw_root="$1" project_root="$2" wt
    local -a roots=("$fw_root")
    while IFS= read -r wt; do
        [ -n "$wt" ] && [ "$wt" != "$project_root" ] || continue
        if [ -d "$wt/.agentic-framework/lib" ]; then
            roots+=("$wt/.agentic-framework")
        elif [ -f "$wt/agents/task-create/create-task.sh" ]; then
            roots+=("$wt")
        fi
    done < <(git -C "$project_root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    local others
    others=$(fw_id_other_allocators "${roots[@]}")
    if [ -n "$others" ]; then
        echo "WARN another task-id allocator besides lib/idalloc.sh: $(echo "$others" | tr '\n' ' ')— route it through fw_id_allocate (one allocator per repository, T-5217)"
    else
        echo "OK one task-id allocator (lib/idalloc.sh; ${#roots[@]} framework cop$([ "${#roots[@]}" -eq 1 ] && echo y || echo ies) checked)"
    fi
}
