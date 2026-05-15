#!/usr/bin/env bash
# lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3).
#
# The cascade is: local → origin (OneDev) → github (mirror via OneDev
# .onedev-buildspec.yml PushRepository job). When OneDev's mirror cron lags
# or fails silently, github stays behind origin. T-1592 added detection in
# `fw doctor`. This module closes the loop: when the move is fast-forward
# safe, push the lagging mirror up to origin's HEAD. Diverged state is
# logged but never auto-recovered — that requires human decision.
#
# Public functions (called from bin/fw dispatcher):
#   mirror_main <subcommand> [args...]
#
# Subcommands:
#   sync [--dry-run] [--quiet]   Push lagging mirrors up to origin's HEAD
#   status                       Print parity vs origin per remote
#   help                         Usage

mirror_log_event() {
    local file="$1" remote="$2" outcome="$3" mirror="${4:-}" origin="${5:-}"
    mkdir -p "$(dirname "$file")"
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$remote" "$outcome" "$mirror" "$origin" >> "$file"
}

mirror_default_branch() {
    # Resolve the default branch on origin. Falls back to "master".
    local _ref
    _ref=$(git -C "${PROJECT_ROOT:-.}" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    [ -n "$_ref" ] && { echo "$_ref"; return; }
    # Fall back to the local current branch if it tracks origin
    _ref=$(git -C "${PROJECT_ROOT:-.}" branch --show-current 2>/dev/null)
    [ -n "$_ref" ] && { echo "$_ref"; return; }
    echo "master"
}

mirror_sync_one() {
    # Sync a single remote. Returns 0 if synced or in-sync, non-zero on failure.
    # Args: remote_name origin_head dry_run quiet log_file branch
    local remote="$1" origin_head="$2" dry_run="$3" quiet="$4" log_file="$5" branch="$6"

    local mirror_head
    mirror_head=$(git -C "${PROJECT_ROOT:-.}" ls-remote "$remote" "refs/heads/$branch" 2>/dev/null | awk '{print $1}')
    if [ -z "$mirror_head" ]; then
        mirror_log_event "$log_file" "$remote" "unreachable" "" "$origin_head"
        [ "$quiet" -eq 0 ] && echo "  $remote: unreachable, skipped" >&2
        return 1
    fi

    if [ "$mirror_head" = "$origin_head" ]; then
        mirror_log_event "$log_file" "$remote" "in-sync" "$mirror_head" "$origin_head"
        [ "$quiet" -eq 0 ] && echo "  $remote: in sync ($mirror_head)"
        return 0
    fi

    if git -C "${PROJECT_ROOT:-.}" merge-base --is-ancestor "$mirror_head" "$origin_head" 2>/dev/null; then
        if [ "$dry_run" -eq 1 ]; then
            mirror_log_event "$log_file" "$remote" "would-sync" "$mirror_head" "$origin_head"
            [ "$quiet" -eq 0 ] && echo "  $remote: would push ${mirror_head:0:9} → ${origin_head:0:9} (dry-run)"
            return 0
        fi
        # T-1829: capture push stderr so a recurring stall is diagnosable from
        # the log alone, not by re-running the failing push interactively.
        # Origin: T-1828 RCA — the OneDev→GitHub mirror failed every 15min for
        # 7+ hours with only "push-failed" in the log; took a consumer pickup
        # to surface the actual blocking error (T-1603 hook).
        local _push_err
        _push_err=$(mktemp 2>/dev/null || echo "/tmp/mirror-push-err.$$")
        if git -C "${PROJECT_ROOT:-.}" push "$remote" "$branch" >/dev/null 2>"$_push_err"; then
            mirror_log_event "$log_file" "$remote" "synced" "$mirror_head" "$origin_head"
            [ "$quiet" -eq 0 ] && echo "  $remote: synced ${mirror_head:0:9} → ${origin_head:0:9}"
            rm -f "$_push_err"
            return 0
        fi
        mirror_log_event "$log_file" "$remote" "push-failed" "$mirror_head" "$origin_head"
        if [ -s "$_push_err" ]; then
            {
                printf '##PUSH-FAILED-STDERR remote=%s ts=%s\n' \
                    "$remote" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                head -20 "$_push_err"
                printf '##END\n'
            } >> "$log_file"
        fi
        rm -f "$_push_err"
        [ "$quiet" -eq 0 ] && echo "  $remote: push failed (stderr in $log_file)" >&2
        return 1
    fi

    mirror_log_event "$log_file" "$remote" "diverged" "$mirror_head" "$origin_head"
    [ "$quiet" -eq 0 ] && echo "  $remote: DIVERGED — manual recovery required (mirror $mirror_head not ancestor of origin $origin_head)" >&2
    return 1
}

mirror_sync() {
    local dry_run=0 quiet=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=1 ;;
            --quiet|-q) quiet=1 ;;
            -h|--help)
                cat <<'USAGE'
Usage: fw mirror sync [--dry-run] [--quiet]

Push each non-origin remote's master branch up to origin's HEAD when the
move is fast-forward safe. Logs every check to .context/working/.mirror-sync.log.

Outcomes (logged + reported):
  in-sync       remote already at origin's HEAD
  synced        fast-forward push successful
  would-sync    --dry-run; push would have succeeded
  diverged      remote has commits origin lacks; refuse, require human
  unreachable   could not contact remote
  push-failed   ls-remote ok but push rejected
USAGE
                return 0
                ;;
            *) echo "Unknown flag: $1" >&2; return 2 ;;
        esac
        shift
    done

    local log_file="${PROJECT_ROOT:-.}/.context/working/.mirror-sync.log"

    local origin_head
    origin_head=$(git -C "${PROJECT_ROOT:-.}" ls-remote origin HEAD 2>/dev/null | awk '{print $1}')
    if [ -z "$origin_head" ]; then
        mirror_log_event "$log_file" "origin" "unreachable" "" ""
        [ "$quiet" -eq 0 ] && echo "ERROR: cannot reach origin" >&2
        return 1
    fi

    local remotes
    remotes=$(git -C "${PROJECT_ROOT:-.}" remote 2>/dev/null | grep -vx 'origin' || true)
    if [ -z "$remotes" ]; then
        [ "$quiet" -eq 0 ] && echo "No mirror remotes configured (only origin)"
        return 0
    fi

    local branch
    branch=$(mirror_default_branch)

    local rc=0
    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        if ! mirror_sync_one "$remote" "$origin_head" "$dry_run" "$quiet" "$log_file" "$branch"; then
            rc=1
        fi
    done <<< "$remotes"

    return "$rc"
}

mirror_status() {
    local origin_head
    origin_head=$(git -C "${PROJECT_ROOT:-.}" ls-remote origin HEAD 2>/dev/null | awk '{print $1}')
    if [ -z "$origin_head" ]; then
        echo "ERROR: cannot reach origin" >&2
        return 1
    fi
    echo "origin HEAD: $origin_head"

    local remotes
    remotes=$(git -C "${PROJECT_ROOT:-.}" remote 2>/dev/null | grep -vx 'origin' || true)
    if [ -z "$remotes" ]; then
        echo "(no mirror remotes configured)"
        return 0
    fi

    local branch
    branch=$(mirror_default_branch)

    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        local mirror_head
        mirror_head=$(git -C "${PROJECT_ROOT:-.}" ls-remote "$remote" "refs/heads/$branch" 2>/dev/null | awk '{print $1}')
        if [ -z "$mirror_head" ]; then
            echo "  $remote: unreachable"
        elif [ "$mirror_head" = "$origin_head" ]; then
            echo "  $remote: in sync"
        elif git -C "${PROJECT_ROOT:-.}" merge-base --is-ancestor "$mirror_head" "$origin_head" 2>/dev/null; then
            echo "  $remote: behind by $(git -C "${PROJECT_ROOT:-.}" rev-list --count "${mirror_head}..${origin_head}" 2>/dev/null) commits (fast-forward safe)"
        else
            echo "  $remote: DIVERGED"
        fi
    done <<< "$remotes"
}

mirror_main() {
    local subcmd="${1:-help}"
    [ $# -gt 0 ] && shift
    case "$subcmd" in
        sync) mirror_sync "$@" ;;
        status) mirror_status "$@" ;;
        help|-h|--help)
            cat <<'USAGE'
Usage: fw mirror <subcommand>

Mirror cascade auto-recovery (T-1591/T-1592/T-1594).

Subcommands:
  sync [--dry-run] [--quiet]   Push lagging mirrors up to origin's HEAD
  status                       Show parity vs origin per remote
  help                         This message

Diverged state (mirror has commits origin lacks) is never auto-recovered;
that path requires human decision.
USAGE
            ;;
        *)
            echo "Unknown mirror subcommand: $subcmd" >&2
            echo "Run 'fw mirror help' for usage" >&2
            return 2
            ;;
    esac
}
