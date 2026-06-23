#!/usr/bin/env bash
# lib/worktree.sh — fw worktree topology observability.
#
# T-2466 (T-2464 GO Candidate C, slice 2). Read-only. `fw worktree status [--json]`
# reports the git-worktree topology of the framework checkout:
#   - which branch the MAIN checkout is on, and whether it is master. The framework's
#     hooks are wired by MAIN's absolute path, so a fix only goes LIVE on this host when
#     MAIN's checked-out branch contains it — merging to master alone does NOT change the
#     on-disk hook here while main sits on a session branch.
#   - which worktree (if any) holds `master` checked out: while a worktree locks master,
#     `git checkout master` in main fails — you must `git push origin <branch>:master`.
#   - per-worktree merged-into-master? and live-on-this-host? state.
#
# merge-back is intentionally NOT here — it routes to `fw integrate` (arc-011,
# lib/integrate.py: check|classify; the mutating `fw integrate run` is arc-011's slice).
# `create` is a separate follow-up. This avoids duplicating the existing integrate surface.

# Resolve the "master" ref this repo integrates onto (local first, then origin).
_wt_master_ref() {
    local r
    for r in refs/heads/master refs/heads/main refs/remotes/origin/master refs/remotes/origin/main; do
        if git rev-parse --verify --quiet "$r" >/dev/null 2>&1; then
            printf '%s\n' "$r"
            return 0
        fi
    done
    return 1
}

# is <a> an ancestor of <b>?  (true when b's history contains a)
_wt_is_ancestor() {
    git merge-base --is-ancestor "$1" "$2" >/dev/null 2>&1
}

# Parse `git worktree list --porcelain` into the parallel arrays
#   _WT_PATH[] _WT_HEAD[] _WT_BRANCH[]
# The first record is always the MAIN worktree. Caller must declare the arrays.
_wt_parse() {
    _WT_PATH=(); _WT_HEAD=(); _WT_BRANCH=()
    local line path="" head="" branch=""
    # trailing `printf '\n'` flushes the final record (porcelain ends with a blank line,
    # but guard against builds that omit it)
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) path="${line#worktree }" ;;
            "HEAD "*)     head="${line#HEAD }" ;;
            "branch "*)   branch="${line#branch refs/heads/}" ;;
            "detached")   branch="(detached)" ;;
            "")
                if [ -n "$path" ]; then
                    _WT_PATH+=("$path")
                    _WT_HEAD+=("$head")
                    _WT_BRANCH+=("${branch:-(detached)}")
                fi
                path=""; head=""; branch=""
                ;;
        esac
    done < <(git worktree list --porcelain; printf '\n')
}

# do_worktree_status [--json]
do_worktree_status() {
    local json=0
    [ "${1:-}" = "--json" ] && json=1

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: not in a git repository" >&2
        return 4
    fi

    local master_ref; master_ref="$(_wt_master_ref || true)"

    local -a _WT_PATH _WT_HEAD _WT_BRANCH
    _wt_parse

    local main_path="${_WT_PATH[0]}" main_branch="${_WT_BRANCH[0]}" main_head="${_WT_HEAD[0]}"

    # master-lock holder: the worktree whose branch is master/main
    local master_holder="" i
    for i in "${!_WT_PATH[@]}"; do
        case "${_WT_BRANCH[$i]}" in
            master|main) master_holder="${_WT_PATH[$i]}" ;;
        esac
    done

    # Per-worktree merged?/live?  (short head too)
    local -a _WT_MERGED _WT_LIVE _WT_SHORT
    for i in "${!_WT_PATH[@]}"; do
        _WT_SHORT+=("$(git rev-parse --short "${_WT_HEAD[$i]}" 2>/dev/null || echo "${_WT_HEAD[$i]:0:9}")")
        if [ -n "$master_ref" ] && _wt_is_ancestor "${_WT_HEAD[$i]}" "$master_ref"; then
            _WT_MERGED+=("yes")
        elif [ -z "$master_ref" ]; then
            _WT_MERGED+=("?")
        else
            _WT_MERGED+=("no")
        fi
        if [ -n "$main_head" ] && _wt_is_ancestor "${_WT_HEAD[$i]}" "$main_head"; then
            _WT_LIVE+=("yes")
        else
            _WT_LIVE+=("no")
        fi
    done

    if [ "$json" = "1" ]; then
        _wt_emit_json "$main_path" "$main_branch" "$master_holder" "$master_ref"
        return 0
    fi

    # ---- human format ----
    local n="${#_WT_PATH[@]}"
    echo "Worktree topology ($n worktree$([ "$n" -ne 1 ] && echo s))"
    echo ""
    echo "  MAIN  $main_path"
    if [ "$main_branch" = "master" ] || [ "$main_branch" = "main" ]; then
        echo "        branch: $main_branch  ✓ on master — merges to master go live here"
    else
        echo "        branch: $main_branch  ⚠ NOT on master — merging to master will NOT go live on"
        echo "        this host until MAIN's branch contains the fix (hooks run MAIN's bin/fw)"
    fi
    echo ""
    if [ -n "$master_holder" ] && [ "$master_holder" != "$main_path" ]; then
        echo "  master is checked out in a LINKED worktree (locked):"
        echo "        $master_holder"
        echo "        → \`git checkout master\` in main will fail; use: git push origin <branch>:master"
        echo ""
    fi
    if [ "$n" -gt 1 ]; then
        echo "  Linked worktrees:"
        for i in "${!_WT_PATH[@]}"; do
            [ "$i" = "0" ] && continue
            printf "    %-42s %-10s merged:%-4s live:%s\n" \
                "${_WT_BRANCH[$i]}" "${_WT_SHORT[$i]}" "${_WT_MERGED[$i]}" "${_WT_LIVE[$i]}"
            echo "      ${_WT_PATH[$i]}"
        done
    fi
}

# Compact one-line summary for `fw doctor` when run inside a linked worktree.
# Prints nothing (returns 1) when not in a linked worktree.
do_worktree_doctor_line() {
    git rev-parse --git-dir >/dev/null 2>&1 || return 1
    local gd cgd
    gd="$(git rev-parse --git-dir 2>/dev/null)"
    cgd="$(git rev-parse --git-common-dir 2>/dev/null)"
    # main checkout: git-dir == git-common-dir. Linked worktree: they differ.
    [ "$gd" != "$cgd" ] || return 1

    local master_ref; master_ref="$(_wt_master_ref || true)"
    local head branch
    head="$(git rev-parse --short HEAD 2>/dev/null)"
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

    # main checkout branch (first porcelain record)
    local -a _WT_PATH _WT_HEAD _WT_BRANCH
    _wt_parse
    local main_branch="${_WT_BRANCH[0]}"

    local merged="no" live="no"
    [ -n "$master_ref" ] && _wt_is_ancestor HEAD "$master_ref" && merged="yes"
    _wt_is_ancestor HEAD "${_WT_HEAD[0]}" && live="yes"

    printf 'linked worktree: branch %s (%s) — merged:%s live:%s; main is on %s' \
        "$branch" "$head" "$merged" "$live" "$main_branch"
    [ "$live" = "no" ] && printf ' (this branch is NOT live on this host yet)'
    printf '\n'
    return 0
}

_wt_emit_json() {
    local main_path="$1" main_branch="$2" master_holder="$3" master_ref="$4"
    # Build TSV of linked-worktree rows and hand the whole thing to python for safe encoding.
    {
        printf 'MAIN\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$main_path" "$main_branch" "${_WT_SHORT[0]}" "${_WT_MERGED[0]}" "${_WT_LIVE[0]}" "$master_ref"
        local i
        for i in "${!_WT_PATH[@]}"; do
            [ "$i" = "0" ] && continue
            printf 'WT\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "${_WT_PATH[$i]}" "${_WT_BRANCH[$i]}" "${_WT_SHORT[$i]}" \
                "${_WT_MERGED[$i]}" "${_WT_LIVE[$i]}" "$([ "${_WT_PATH[$i]}" = "$master_holder" ] && echo true || echo false)"
        done
    } | python3 -c '
import sys, json
main = None
worktrees = []
master_holder = None
for line in sys.stdin:
    parts = line.rstrip("\n").split("\t")
    if not parts or parts[0] == "":
        continue
    kind = parts[0]
    if kind == "MAIN":
        _, path, branch, head, merged, live, master_ref = parts
        main = {"path": path, "branch": branch, "head": head,
                "merged": merged, "live": live,
                "on_master": branch in ("master", "main"),
                "master_ref": master_ref or None}
    elif kind == "WT":
        _, path, branch, head, merged, live, is_master = parts
        wt = {"path": path, "branch": branch, "head": head,
              "merged": merged, "live": live,
              "holds_master": is_master == "true"}
        worktrees.append(wt)
        if wt["holds_master"]:
            master_holder = path
out = {"main": main, "master_holder": master_holder, "linked_worktrees": worktrees}
print(json.dumps(out, indent=2))
'
}
