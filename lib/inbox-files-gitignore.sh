#!/bin/bash
# T-5271 — keep operator-dropped files out of a project's git.
#
# The fleet cockpit's /drop page (055-agentic-fleet-cockpit, their T-703, msg
# 1ed082c3) delivers files the operator drops, possibly sensitive, into
# <project>/.context/inbox/files/. No project ignored that path — not even the
# framework repo — so `git add -A`, a handover's `git add -A .context`, or an
# explicit add could put a dropped file into history and onto every remote.
#
# Where the rule lives: the nested .context/.gitignore, anchored as
# `/inbox/files/`. That is the file lib/dispatch-gitignore.sh (T-4684) already
# writes, so one file holds the .context/-level runtime rules; the rule applies
# before .context/inbox/ exists (a nested .context/inbox/.gitignore would need
# the directory first); and anchoring keeps a same-named directory elsewhere,
# and the rest of .context/inbox/ (inbox.yaml, processed/), visible to git.
#
# One list, three readers: init (fresh write), upgrade (append-missing), and
# doctor/audit (fw_inbox_files_problems). Same shape as lib/vec-index-gitignore.sh
# (T-3861), lib/dispatch-gitignore.sh (T-4684), lib/working-gitignore.sh (T-4231).

FW_INBOX_FILES_IGNORE_MARKER="# T-5271: operator-dropped files (fleet cockpit /drop) — never committed."
FW_INBOX_FILES_REL=".context/inbox/files"

fw_inbox_files_ignore_rules() {
    printf '%s\n' \
        '/inbox/files/'
}

# fw_inbox_files_ensure_ignored <project_root> [--dry-run]
# Appends any missing rule to <root>/.context/.gitignore (created if absent).
# Prints the number of rules added (0 = already complete). Idempotent; never
# removes or rewrites an existing line.
fw_inbox_files_ensure_ignored() {
    local root="$1" dry="${2:-}"
    local gi="$root/.context/.gitignore"
    local rule missing=()
    while IFS= read -r rule; do
        if [ ! -f "$gi" ] || ! grep -qxF "$rule" "$gi"; then
            missing+=("$rule")
        fi
    done < <(fw_inbox_files_ignore_rules)
    if [ "${#missing[@]}" -gt 0 ] && [ "$dry" != "--dry-run" ]; then
        mkdir -p "$root/.context"
        {
            # keep the appended block on its own lines even if the file lacks a final newline
            if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo; fi
            [ -f "$gi" ] && grep -qxF "$FW_INBOX_FILES_IGNORE_MARKER" "$gi" || echo "$FW_INBOX_FILES_IGNORE_MARKER"
            printf '%s\n' "${missing[@]}"
        } >> "$gi"
    fi
    echo "${#missing[@]}"
}

# fw_inbox_files_tracked <project_root>
# Prints files under .context/inbox/files/ that git already tracks — an ignore
# rule does not untrack a file a project already committed. Never untracks.
fw_inbox_files_tracked() {
    local root="$1"
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$root" ls-files -- "$FW_INBOX_FILES_REL" 2>/dev/null
}

# fw_inbox_files_problems <project_root>
# Prints one line per problem and returns 1 when there is any:
#   not-ignored                 git would commit a new file dropped there
#   tracked <path>              a dropped file is already in the index
# Returns 0 with no output when clean, and outside a git work tree. The probe
# uses --no-index so the answer is about the rules, not about what is tracked.
fw_inbox_files_problems() {
    local root="$1" rc=0 p
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if ! git -C "$root" check-ignore -q --no-index "$FW_INBOX_FILES_REL/.fw-ignore-probe" 2>/dev/null; then
        echo "not-ignored"
        rc=1
    fi
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo "tracked $p"
        rc=1
    done < <(fw_inbox_files_tracked "$root")
    return "$rc"
}
