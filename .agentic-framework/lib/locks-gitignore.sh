#!/bin/bash
# T-5373 — keep flock anchors under .context/locks/ out of a consumer's git.
#
# lib/keylock.sh, lib/keylock.py and their callers (verdict ledger, dispatch
# ledgers, inception decide) take flock(2) on .context/locks/<key>.lock. The
# files persist by design — an flock anchor must not be unlinked while another
# process may hold it — so they are never cleaned up. The framework repo ignores
# .context/locks/ in its ROOT .gitignore (.gitignore:37), which no consumer
# inherits; `fw init` and `fw upgrade` only wrote ignores for .context/working/,
# .context/dispatch/ and .context/inbox/files/. Origin: skills-manager saw an
# untracked .context/locks/T-486.lock after `fw inception decide`.
#
# One list, two writers: init (fresh write) and upgrade (append-missing). The
# rule lives in the nested .context/.gitignore (relative to .context/, applies
# before the directory exists). Same shape as lib/dispatch-gitignore.sh (T-4684).

FW_LOCKS_IGNORE_MARKER="# T-5373: flock anchors (.context/locks/*.lock) — persist by design, never committed."

fw_locks_ignore_rules() {
    printf '%s\n' \
        '/locks/'
}

# fw_locks_ensure_ignored <project_root> [--dry-run]
# Appends any missing rule to <root>/.context/.gitignore (created if absent).
# Prints the number of rules added (0 = already complete). Idempotent; never
# removes or rewrites an existing line, never touches the top-level .gitignore.
fw_locks_ensure_ignored() {
    local root="$1" dry="${2:-}"
    local gi="$root/.context/.gitignore"
    local rule missing=()
    while IFS= read -r rule; do
        if [ ! -f "$gi" ] || ! grep -qxF "$rule" "$gi"; then
            missing+=("$rule")
        fi
    done < <(fw_locks_ignore_rules)
    if [ "${#missing[@]}" -gt 0 ] && [ "$dry" != "--dry-run" ]; then
        mkdir -p "$root/.context"
        {
            # keep the appended block on its own lines even if the file lacks a final newline
            if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo; fi
            [ -f "$gi" ] && grep -qxF "$FW_LOCKS_IGNORE_MARKER" "$gi" || echo "$FW_LOCKS_IGNORE_MARKER"
            printf '%s\n' "${missing[@]}"
        } >> "$gi"
    fi
    echo "${#missing[@]}"
}

# fw_locks_tracked <project_root>
# Prints files under .context/locks/ that git already tracks — an ignore rule
# does not untrack a file a project already committed. Never untracks anything.
fw_locks_tracked() {
    local root="$1"
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$root" ls-files -- .context/locks 2>/dev/null
}
