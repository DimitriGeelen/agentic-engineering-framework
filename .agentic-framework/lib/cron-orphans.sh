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

    # Canonicalise the caller's fw path before matching. The match itself is a
    # literal substring test against the cron file, so `/opt/x/tests/../bin/fw`
    # and `/opt/x/bin/fw` name the same binary but would not match each other.
    # `fw cron install` writes the canonical form, so canonicalising the input
    # side is what makes an odd-but-equivalent caller path work. A cron entry
    # that spells the path differently from FRAMEWORK_ROOT is still missed —
    # accepted, and the reason the scan takes fw_path as an argument at all
    # rather than assuming it.
    if [ -n "$fw_path" ]; then
        local _fw_dir _fw_base
        _fw_dir=$(dirname "$fw_path")
        _fw_base=$(basename "$fw_path")
        if [ -d "$_fw_dir" ]; then
            _fw_dir=$(cd "$_fw_dir" 2>/dev/null && pwd -P) || _fw_dir=$(dirname "$fw_path")
            fw_path="$_fw_dir/$_fw_base"
        fi
    fi

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

# cron_orphan_report <cron_dir> <fw_path> <project_root> <framework_root>
#
# Renders the doctor WARN block for whatever cron_orphan_scan finds.
# Returns 0 when orphans were reported (caller increments its warning count),
# 1 when there were none and nothing was printed.
#
# Lives here rather than inline in `bin/fw` for two reasons: L-332/L-408 keep
# multi-line rendering out of bin/fw, and a doctor run on this host costs minutes
# (OBS-368 — `bats --count` over 606 files), so a renderer that can only be
# exercised through `fw doctor` is a renderer that effectively goes untested.
cron_orphan_report() {
    local cron_dir="${1:-/etc/cron.d}"
    local fw_path="${2:-}"
    local project_root="${3:-.}"
    local framework_root="${4:-.}"

    local orphans
    orphans=$(cron_orphan_scan "$cron_dir" "$fw_path") || return 1
    [ -n "$orphans" ] || return 1

    local count files="" of or
    count=$(printf '%s\n' "$orphans" | wc -l | tr -d ' ')

    printf '  WARN  Orphaned cron entries: %s deployed job file(s) declare a PROJECT_ROOT that no longer exists\n' "$count"
    while IFS=$'\t' read -r of or; do
        [ -n "$of" ] || continue
        printf '        %s → %s (gone)\n' "$of" "$or"
        files="$files $of"
    done <<< "$orphans"
    printf '        These re-resolve onto %s and compete for its .context/locks/audit.lock.\n' "$framework_root"
    printf '        Remove: cd %s && sudo rm -f%s\n' "$project_root" "$files"

    return 0
}
