#!/bin/bash
# T-4684 — keep dispatch worker dirs out of a consumer's git.
#
# T-4675 moved TermLink worker dirs under the dispatching project:
# <project>/.context/dispatch/<worker>/ holds prompt.md, env.sh (can carry
# environment values), result.jsonl, stderr.log, meta.json. The framework repo
# ignores .context/dispatch/ in its ROOT .gitignore (.gitignore:35), which no
# consumer inherits, so a handover's `git add -A .context` could commit them.
# Origin: 832 be.5 report (sidecar 81cb0bca).
#
# One list, two writers: init (fresh write) and upgrade (append-missing). The
# rules live in a nested .context/.gitignore, so they are relative to .context/
# and apply before the directory exists. Same shape as lib/working-gitignore.sh
# (T-4231) and lib/vec-index-gitignore.sh (T-3861).

FW_DISPATCH_IGNORE_MARKER="# T-4684: dispatch worker dirs (prompt, env.sh, results, logs) — runtime state."

fw_dispatch_ignore_rules() {
    printf '%s\n' \
        '/dispatch/'
}

# fw_dispatch_ensure_ignored <project_root> [--dry-run]
# Appends any missing rule to <root>/.context/.gitignore (created if absent).
# Prints the number of rules added (0 = already complete). Idempotent; never
# removes or rewrites an existing line.
fw_dispatch_ensure_ignored() {
    local root="$1" dry="${2:-}"
    local gi="$root/.context/.gitignore"
    local rule missing=()
    while IFS= read -r rule; do
        if [ ! -f "$gi" ] || ! grep -qxF "$rule" "$gi"; then
            missing+=("$rule")
        fi
    done < <(fw_dispatch_ignore_rules)
    if [ "${#missing[@]}" -gt 0 ] && [ "$dry" != "--dry-run" ]; then
        mkdir -p "$root/.context"
        {
            # keep the appended block on its own lines even if the file lacks a final newline
            if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo; fi
            [ -f "$gi" ] && grep -qxF "$FW_DISPATCH_IGNORE_MARKER" "$gi" || echo "$FW_DISPATCH_IGNORE_MARKER"
            printf '%s\n' "${missing[@]}"
        } >> "$gi"
    fi
    echo "${#missing[@]}"
}

# fw_dispatch_tracked <project_root>
# Prints files under .context/dispatch/ that git already tracks — an ignore rule
# does not untrack a file a project already committed. Never untracks anything.
fw_dispatch_tracked() {
    local root="$1"
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$root" ls-files -- .context/dispatch 2>/dev/null
}
