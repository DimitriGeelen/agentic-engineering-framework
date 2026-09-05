#!/usr/bin/env bash
# lib/cron-orphans.sh — detect deployed cron entries whose declared PROJECT_ROOT
# is gone (T-3281).
#
# The framework already tracks three cron drift classes along the chain
# registry → generated → deployed (CLAUDE.md §Verification Gate, T-1942/T-1771).
# All three compare a project's own registry against its own deployed file, so
# all three are blind to the same thing: a deployed entry with NO registry
# behind it at all, belonging to a project that no longer exists.
#
# Those entries are not inert. `bin/fw` treats a vanished PROJECT_ROOT as stale
# (`_project_root_is_stale`), re-resolves, and — with cron supplying no usable
# cwd — falls back to FRAMEWORK_ROOT. The job then audits the *framework repo*
# rather than refusing, competing for `.context/locks/audit.lock` with the
# project's real jobs. Six such entries, left by temp-dir test-fixture installs,
# held that lock near-continuously and made every pre-push audit gate fail with
# "Another audit is already running — exiting (no verdict produced)".
#
# Detection only. Removal is a host-level change and stays with the operator.

# Guard against double-source (bin/fw sources several libs per doctor run).
[ -n "${_FW_CRON_ORPHANS_LOADED:-}" ] && return 0
_FW_CRON_ORPHANS_LOADED=1

# cron_orphan_scan <cron_dir> [fw_path]
#
# Prints one TAB-separated `<cron_file>\t<dead_root>` line per orphan; prints
# nothing and returns 0 when there are none, so callers can treat empty output
# as "clean" without special-casing.
#
#   cron_dir  directory of deployed entries (override for tests; real host is
#             /etc/cron.d, which is why the caller passes FW_CRON_INSTALL_DIR).
#   fw_path   when non-empty, only entries that invoke exactly this `bin/fw`
#             are considered — those are the ones that fall through onto its
#             FRAMEWORK_ROOT. Empty means report every orphan in the directory.
#
# Two things are deliberately NOT orphans:
#   - a file declaring no PROJECT_ROOT at all. Older installs used that format,
#     and 14 such entries are live on the origin host. They resolve by cwd, so
#     absence of the variable says nothing about whether the project exists —
#     flagging them would be a guess presented as a finding.
#   - an unreadable file. Reporting one as an orphan would state that its root
#     is gone, which we did not establish.
cron_orphan_scan() {
    local cron_dir="${1:-/etc/cron.d}"
    local fw_path="${2:-}"

    [ -d "$cron_dir" ] || return 0

    local f roots r
    for f in "$cron_dir"/agentic-*; do
        [ -f "$f" ] || continue
        [ -r "$f" ] || continue

        if [ -n "$fw_path" ]; then
            grep -qF "$fw_path" "$f" 2>/dev/null || continue
        fi

        roots=$(grep -ohE 'PROJECT_ROOT="[^"]*"' "$f" 2>/dev/null \
                | sed 's/^PROJECT_ROOT="//; s/"$//' \
                | sort -u)
        [ -n "$roots" ] || continue

        while IFS= read -r r; do
            [ -n "$r" ] || continue
            [ -d "$r" ] && continue
            printf '%s\t%s\n' "$f" "$r"
        done <<< "$roots"
    done

    return 0
}
