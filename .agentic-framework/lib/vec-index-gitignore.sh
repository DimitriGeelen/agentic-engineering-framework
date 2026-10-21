#!/bin/bash
# T-3861 — keep the vector index out of a consumer's git history.
#
# `fw index reindex` builds .context/working/fw-vec-index.db (1.5-3.5 GiB) plus
# scratch beside it: `<db>.reindex.<pid>.tmp[-journal]`, `<db>.<pid>.building`,
# `<db>.manifest.json`, `<db>.reindex.lock`, sqlite `-wal/-shm/-journal`. The
# framework repo ignores all of these in its ROOT .gitignore (.gitignore:108-130),
# which no consumer inherits. `fw init` only writes .context/working/.gitignore,
# and it named none of them; `fw upgrade` never touched that file. Origin:
# ring20-dashboard T-2462 finding 9 — a 1.2 GB unreferenced blob in .git after a
# handover's `git add -A .context`.
#
# One list, three readers: init (fresh write), upgrade (append-missing), audit
# (git check-ignore on the live file). The rules live in the nested
# .context/working/.gitignore, so they are relative to that directory.

FW_VEC_INDEX_IGNORE_MARKER="# T-3861: the vector index and its build/reindex scratch (GiB-sized)."

fw_vec_index_ignore_rules() {
    printf '%s\n' \
        'fw-vec-index.db' \
        'fw-vec-index.db-*' \
        'fw-vec-index.db.*'
}

# fw_vec_index_ensure_ignored <project_root> [--dry-run]
# Appends any missing rule to <root>/.context/working/.gitignore (created if
# absent). Prints the number of rules added (0 = already complete). Idempotent.
fw_vec_index_ensure_ignored() {
    local root="$1" dry="${2:-}"
    local gi="$root/.context/working/.gitignore"
    local rule missing=()
    while IFS= read -r rule; do
        if [ ! -f "$gi" ] || ! grep -qxF "$rule" "$gi"; then
            missing+=("$rule")
        fi
    done < <(fw_vec_index_ignore_rules)
    if [ "${#missing[@]}" -gt 0 ] && [ "$dry" != "--dry-run" ]; then
        mkdir -p "$root/.context/working"
        {
            # keep the appended block on its own lines even if the file lacks a final newline
            if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo; fi
            [ -f "$gi" ] && grep -qxF "$FW_VEC_INDEX_IGNORE_MARKER" "$gi" || echo "$FW_VEC_INDEX_IGNORE_MARKER"
            printf '%s\n' "${missing[@]}"
        } >> "$gi"
    fi
    echo "${#missing[@]}"
}

# fw_vec_index_unignored <project_root>
# Prints a one-line reason and returns 1 when the index file exists and git would
# commit it (tracked, or not ignored). Returns 0 otherwise, including outside git.
fw_vec_index_unignored() {
    local root="$1"
    local rel=".context/working/fw-vec-index.db"
    [ -e "$root/$rel" ] || return 0
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if git -C "$root" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        echo "$rel is TRACKED by git"
        return 1
    fi
    if ! git -C "$root" check-ignore -q "$rel" 2>/dev/null; then
        echo "$rel exists and is not gitignored"
        return 1
    fi
    return 0
}
