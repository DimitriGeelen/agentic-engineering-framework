#!/bin/bash
# lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector.
#
# Origin. A worker's rewrite of agents/audit/audit.sh dropped the executable
# bit (git index 100755, on-disk 664). `bin/fw audit` then died with exit 126
# "Permission denied" — the ENTIRE audit rail silently disabled by a mode
# change no gate watched. Nothing in doctor, audit, or the pre-push hooks
# compared on-disk mode against the git index. This is the T-3105 class one
# level up: the audit that reports on everything else had no check that it can
# itself run.
#
# The predicate is deliberately cheap — one `git ls-files -s` plus a stat-class
# test per candidate. No test-suite invocation, no network, no corpus walk —
# it is safe on hook/cron/pre-push paths and runs under `fw doctor --quick`.
#
# Shared by `fw doctor` (WARN) and agents/audit/audit.sh (FAIL) per G-079:
# one predicate, two verdict surfaces — never re-derive the ls-files/awk line
# in a caller.
#
# Repo resolution (hermetic-test hook): explicit $1 > $FW_EXEC_BIT_REPO > $PWD.

# exec_bit_candidates [repo]
#   Prints tracked paths (relative to repo root, one per line) whose git INDEX
#   mode is 100755, restricted to *.sh at any depth plus bin/fw. Returns 1 and
#   prints nothing when repo is not a git work tree — callers must treat that
#   as "could not enumerate", not as a clean set of size 0 (T-3105).
exec_bit_candidates() {
    local repo="${1:-${FW_EXEC_BIT_REPO:-$PWD}}"
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
    # ls-files -s format: "<mode> <sha> <stage>\t<path>" — split on the tab so
    # paths containing spaces survive.
    git -C "$repo" ls-files -s -- '*.sh' 'bin/fw' 2>/dev/null \
        | awk -F'\t' '$1 ~ /^100755 / { print $2 }'
}

# exec_bit_drifted_files [repo]
#   Filters candidates to those present on disk but NOT executable — the drift
#   this detector exists for. Prints one path per line. Returns 0 when drift
#   was found (list non-empty), 1 when clean or unenumerable, so callers use
#   the watchtower_stale_sources shape: `if list=$(exec_bit_drifted_files); then WARN`.
#   A candidate missing from disk entirely is NOT reported — that is delete
#   dirt, visible to git status, and `chmod +x` would be the wrong remedy.
exec_bit_drifted_files() {
    local repo="${1:-${FW_EXEC_BIT_REPO:-$PWD}}"
    local f found=1
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ -f "$repo/$f" ] && [ ! -x "$repo/$f" ]; then
            printf '%s\n' "$f"
            found=0
        fi
    done < <(exec_bit_candidates "$repo")
    return "$found"
}
