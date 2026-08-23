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
# The trunk every landing verdict is measured against.
#
# REMOTE FIRST (T-3117). This used to prefer refs/heads/master, and in the
# session-on-master flow (T-100196) that ref is never updated: work lands by
# pushing `HEAD:master` from a topic branch, which advances origin/master and
# leaves the LOCAL master branch wherever it was. Measured here on 2026-08-23,
# local master was **1744 commits behind** origin/master — so every "has this
# landed?" answer in gc, `fw worktree status` and the branch-hygiene surfaces
# was computed against a trunk from six weeks earlier. Nothing could ever be
# reclaimed, which is why four stale worktrees survived R7's entire arc.
#
# "Landed" means on the SHARED trunk, so the remote-tracking ref is the
# correct subject, not a local bookmark that may be stale or ahead. A local
# master that is ahead of origin/master holds commits that are genuinely not
# landed yet; reporting them as landed would be the dangerous direction of
# this error, and preferring the remote gets that right too. The local refs
# stay as fallback for repos with no remote at all.
_wt_master_ref() {
    local r
    for r in refs/remotes/origin/master refs/remotes/origin/main refs/heads/master refs/heads/main; do
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

# do_worktree_create <name> [--from <ref>]
# (T-2469, T-2464 GO Candidate C follow-up). Spins up an isolated worktree in one
# safe step: creates the worktree under the MAIN checkout's .claude/worktrees/ on
# branch `worktree-<name>`, branched from master (or --from <ref>), then vendor-syncs
# the .agentic-framework/ tree. Folds termlink's scripts/worktree-bootstrap.sh prior
# art (their T-2255, P-047 Q3). Companion to `fw worktree status` (T-2466); merge-back
# is `fw integrate run` (T-2471).
#
# Design (see T-2469 Decisions):
#   - Branch convention: worktree-<name> (matches existing live worktrees).
#   - Default base = master/main (clean divergence -> clean merge-back); --from overrides.
#   - +x is intentionally NOT touched -- bin/fw dispatches hooks via `bash` (T-2467),
#     so hook wrappers are usable without the executable bit.
#   - New worktree lands under the MAIN checkout regardless of where the command is
#     invoked (resolved from the first porcelain record).
do_worktree_create() {
    local name="" from_ref=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --from) from_ref="${2:-}"; shift 2 || return 2 ;;
            --from=*) from_ref="${1#--from=}"; shift ;;
            -*) echo "worktree create: unknown option: $1" >&2; return 2 ;;
            *)
                if [ -z "$name" ]; then name="$1"; shift
                else echo "worktree create: unexpected argument: $1" >&2; return 2; fi
                ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "usage: fw worktree create <name> [--from <ref>]" >&2
        return 2
    fi
    # name becomes a directory + branch suffix -- keep it filesystem/ref safe.
    case "$name" in
        *[!A-Za-z0-9._-]*|""|.|..)
            echo "worktree create: name must be [A-Za-z0-9._-] (no slashes/spaces): '$name'" >&2
            return 2
            ;;
    esac

    git rev-parse --git-dir >/dev/null 2>&1 || {
        echo "worktree create: not inside a git repository" >&2; return 1; }

    local branch="worktree-$name"

    # Resolve MAIN worktree root (first porcelain record).
    local -a _WT_PATH _WT_HEAD _WT_BRANCH
    _wt_parse
    local main_root="${_WT_PATH[0]}"
    [ -n "$main_root" ] || { echo "worktree create: cannot resolve main worktree root" >&2; return 1; }
    local wt_parent="$main_root/.claude/worktrees"
    local wt_path="$wt_parent/$name"

    # Refuse if the branch or the target path already exists (clear, actionable).
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "worktree create: branch '$branch' already exists -- pick another name or remove it first." >&2
        return 1
    fi
    if [ -e "$wt_path" ]; then
        echo "worktree create: path already exists: $wt_path" >&2
        return 1
    fi

    # Base ref: explicit --from, else master/main.
    local base base_label
    if [ -n "$from_ref" ]; then
        git rev-parse --verify --quiet "$from_ref" >/dev/null 2>&1 || {
            echo "worktree create: --from ref not found: $from_ref" >&2; return 1; }
        base="$from_ref"; base_label="$from_ref"
    else
        base="$(_wt_master_ref)" || {
            echo "worktree create: no master/main ref to branch from (use --from <ref>)" >&2; return 1; }
        base_label="${base#refs/heads/}"; base_label="${base_label#refs/remotes/}"
    fi

    mkdir -p "$wt_parent" || return 1

    echo "Creating worktree '$name' on branch '$branch' (from $base_label)..."
    if ! git worktree add -b "$branch" "$wt_path" "$base"; then
        echo "worktree create: git worktree add failed" >&2
        return 1
    fi

    # Vendor-sync so the new worktree's .agentic-framework/ matches its source. For a
    # fresh checkout from master this is already consistent (idempotent confirm); it
    # also repairs any base-ref vendor drift. Non-fatal -- never block creation on it.
    if [ -f "$wt_path/bin/fw" ]; then
        if ( cd "$wt_path" && bash bin/fw vendor self ) >/dev/null 2>&1; then
            echo "Vendored .agentic-framework/ synced."
        else
            echo "NOTE: vendor self did not complete (non-fatal) -- run it in the worktree if needed." >&2
        fi
    fi

    echo ""
    echo "Worktree ready: $wt_path"
    echo "  Branch:     $branch (from $base_label)"
    echo "  Next:       cd $wt_path && fw work-on \"<task>\" --type build"
    echo "  Topology:   fw worktree status        (is this branch live on the host?)"
    echo "  Merge back: fw integrate run          (from inside the worktree -- T-2471)"
    return 0
}

# ── fw worktree remove (T-2825, G-076) ───────────────────────────────────────
# Sanctioned teardown path. `git worktree remove` on its own has no opinion about
# whether the branch it points at is reachable from anywhere but this one working
# directory -- remove the worktree and any commits on that branch become invisible
# to the normal workflow (no cwd left to push from). Origin: T-2428/T-2825 -- a
# 6-commit branch survived `git worktree remove` only because that command doesn't
# delete branches, and sat unpushed for 5 weeks because nothing ever re-surfaced it.
#
# Guard: refuse removal when the worktree's branch holds commits that are absent
# from EVERY configured remote (i.e. no remote has all of the branch's commits).
# `--force` proceeds anyway and logs a Tier-2 entry to
# .context/working/.gate-bypass-log.yaml (same convention as lib/inception.sh,
# lib/review.sh). A repo with zero remotes configured cannot prove anything is
# pushed, so it is treated as unpushed too (fail closed).

# _wt_remove_resolve <name-or-path> -> sets _WT_REMOVE_PATH / _WT_REMOVE_BRANCH
# Returns 1 (nothing printed) when no linked worktree matches.
_wt_remove_resolve() {
    local needle="$1"
    local -a _WT_PATH _WT_HEAD _WT_BRANCH
    _wt_parse
    local main_root="${_WT_PATH[0]}"
    local abs=""
    abs="$(cd "$needle" 2>/dev/null && pwd || true)"
    local i
    for i in "${!_WT_PATH[@]}"; do
        [ "$i" = "0" ] && continue
        if [ -n "$abs" ] && [ "${_WT_PATH[$i]}" = "$abs" ]; then
            _WT_REMOVE_PATH="${_WT_PATH[$i]}"; _WT_REMOVE_BRANCH="${_WT_BRANCH[$i]}"
            return 0
        fi
        if [ "${_WT_PATH[$i]}" = "$main_root/.claude/worktrees/$needle" ]; then
            _WT_REMOVE_PATH="${_WT_PATH[$i]}"; _WT_REMOVE_BRANCH="${_WT_BRANCH[$i]}"
            return 0
        fi
    done
    return 1
}

# _wt_is_governance_path <relpath> -> 0 (true) when <relpath> is framework
# governance state, 1 otherwise.
#
# T-3102 / T-2822 -- governance state (.context/**, .tasks/**) is TRACKED
# content, so every linked worktree carries a FORK of it, and hooks firing in
# the MAIN session mutate that fork independently of anything the worktree's
# own work did. Measured on the four live worktrees at T-3102 time: 26/23,
# 5/4, 2/1, 17/15 dirty/governance. The dirt is not the worktree's work; it is
# ambient drift.
#
# T-2822's adopted GO settles what that dirt is WORTH: governance state inside
# a linked worktree is NON-AUTHORITATIVE BY CONSTRUCTION -- master is the
# authority, and the worktree's copy is a stale branch of it that nothing ever
# reads back. Discarding it loses nothing that master does not already hold.
#
# SUPERSEDES T-2831's regenerable-vs-content split for governance paths.
# T-2831 refused `.tasks/**`, `.context/project/decisions.yaml` and
# `.context/working/feedback-stream.yaml` UNCONDITIONALLY on the theory that
# they were irreplaceable content. Under T-2822 that theory is wrong for the
# worktree copy specifically -- the authoritative copy is on master and is
# untouched by this removal. What T-2831 was actually protecting -- "never
# silently discard uncommitted work" -- survives intact below as the SOURCE
# class, which is still refused unconditionally, --force included.
#
# The prefix rule is deliberate here, where T-2831's exact-match allowlist was
# deliberate there: T-2831 needed narrowness because it was deciding whether a
# file was regenerable (a per-file property). T-3102 decides whether a file is
# authoritative in THIS working copy (a per-directory property -- the whole
# governance tree is non-authoritative in a worktree, uniformly).
#
# NOTE (T-3102 correction): this predicate no longer decides on its own whether
# dirt blocks removal -- see _wt_is_discardable_dirt below. It survives because
# the discard SUMMARY still distinguishes governance dirt (non-authoritative
# fork) from vendored/generated dirt (regenerable), and those are different
# sentences to say to an operator.
_wt_is_governance_path() {
    case "$1" in
        .context/*|.tasks/*) return 0 ;;
        *) return 1 ;;
    esac
}

# _wt_is_discardable_dirt <relpath> -> 0 (true) when a dirty <relpath> inside a
# linked worktree can be discarded on removal without losing work.
#
# T-3102 CORRECTION. The first cut of this task classed only `.context/**` and
# `.tasks/**` as discardable. That basis was too narrow to be operational: the
# read-only dry run found all four live worktrees still refused, every one of
# them on a dirty `VERSION`, two of them also on `.agentic-framework/**` and
# `lib/ts/dist/**`. The fix removed governance dirt as a CAUSE of refusal and
# unblocked nothing.
#
# The right set already existed. `_wt_is_ignorable_path` (defined further down,
# for `fw worktree gc`) enumerates exactly "vendored, generated, or
# session-local churn" -- content that is not work. We REUSE it rather than
# restate it: a second copy of that pattern list is precisely the drift bug this
# task exists to fix. (Definition order is irrelevant -- the whole file is
# sourced before any call, so the forward reference resolves.)
#
# Two deltas, both deliberate:
#
#   + .tasks/*   is discardable HERE but is NOT added to
#                _wt_is_ignorable_path. gc calls that function for LANDING
#                decisions ("did this branch's work reach master?"), and there a
#                `.tasks/` file IS a deliverable -- sweeping it into gc's
#                ignorable set would let gc reclaim a branch whose only real
#                content was a task file. The dirt caller asks a different
#                question ("would discarding this working copy lose anything?"),
#                and under T-2822 the answer for `.tasks/` is no: master holds
#                the authoritative copy. TWO CALLERS, TWO CORRECT ANSWERS. Do
#                not "unify" them -- unifying them is the bug.
#
#   - .fabric/*  is ignorable for gc but is NOT discardable here. Sanity-checked
#                at T-3102 rather than assumed: `fw fabric scan` SKIPS cards that
#                already exist (agents/fabric/lib/register.sh:203,331) -- it only
#                creates missing ones. So a MODIFIED card is not regenerable, and
#                cards carry hand-authored prose (`purpose:`, `standalone_reason:`
#                citing task ids). Discarding a dirty card would silently destroy
#                that. It stays ignorable for gc, where the question is "is a
#                changed card a deliverable?" (no), but blocking here, where the
#                question is "would discarding it lose content?" (yes). None of
#                the four live worktrees carries `.fabric/` dirt, so excluding it
#                costs nothing operationally and keeps the guard honest.
#
# The other classes WERE checked, not assumed:
#   .context/*            non-authoritative fork; master is the authority (T-2822)
#   .agentic-framework/*  vendored copy of this repo's own source, rewritten
#                         wholesale by `fw vendor self` (bin/fw:_self_vendor)
#   VERSION               derived from FW_VERSION in bin/fw, restamped by
#                         `fw version sync` (lib/version.sh:298)
#   lib/ts/dist/*         build output of lib/ts/src (`npm run build` ->
#                         lib/ts/../build.sh)
#   *.budget-status|*.hook-counter|*.tool-counter|*.loop-detect.json
#                         session-local counters, rewritten on next tool call
_wt_is_discardable_dirt() {
    case "$1" in
        .fabric/*) return 1 ;;   # see above -- fabric scan will not regenerate it
        .tasks/*)  return 0 ;;   # see above -- deliberately NOT in the gc set
    esac
    _wt_is_ignorable_path "$1"
}

# _wt_porcelain_path <porcelain-line> -> echoes the working-tree path.
# Handles rename/copy records (`R  old -> new`) by taking the destination, and
# strips git's quoting for paths with unusual characters.
_wt_porcelain_path() {
    local path="${1:3}"
    case "$path" in
        *' -> '*) path="${path##* -> }" ;;
    esac
    # git quotes paths containing specials; drop the wrapping quotes so the
    # classification sees `.context/x`, not `".context/x"`.
    case "$path" in
        '"'*'"') path="${path:1:${#path}-2}" ;;
    esac
    printf '%s' "$path"
}

# _wt_dirty_summary <worktree_path> -> classifies `git status --porcelain` for
# the worktree into discardable dirt vs real work. Prints a human-readable report.
#
# THE RULE (T-3102, corrected):
#     blocking dirt = a dirty path that is NOT _wt_is_discardable_dirt
# and _wt_is_discardable_dirt is _wt_is_ignorable_path (gc's vendored/generated/
# session-local set) plus `.tasks/*`, minus `.fabric/*`. See that function for
# why each delta exists and why the two callers must NOT be unified.
#
# Return codes:
#   0 = clean (nothing dirty)
#   1 = at least one SOURCE path is dirty -- names the specific paths (capped),
#       refused unconditionally, --force included (T-2831 AC3, preserved)
#   2 = dirty, but ONLY discardable paths -- safe to discard on removal
_wt_dirty_summary() {
    local wt_path="$1"
    local -a source=() gov=() gen=()
    local line path
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        path="$(_wt_porcelain_path "$line")"
        if ! _wt_is_discardable_dirt "$path"; then
            source+=("$path")
        elif _wt_is_governance_path "$path"; then
            # discardable AND governance -- "non-authoritative fork" (T-2822)
            gov+=("$path")
        else
            # discardable AND vendored/generated/session-local -- "regenerable"
            gen+=("$path")
        fi
    done < <(git -C "$wt_path" status --porcelain --untracked-files=all 2>/dev/null)

    if [ "${#source[@]}" -eq 0 ] && [ "${#gov[@]}" -eq 0 ] && [ "${#gen[@]}" -eq 0 ]; then
        return 0
    fi

    # Source wins over governance in a mixed worktree: the presence of ANY
    # uncommitted source makes the removal lossy, whatever else is dirty.
    if [ "${#source[@]}" -gt 0 ]; then
        echo "${#source[@]} uncommitted source file(s) in $wt_path:"
        local i shown=0
        for i in "${!source[@]}"; do
            [ "$shown" -ge 5 ] && break
            echo "  ${source[$i]}"
            shown=$((shown + 1))
        done
        if [ "${#source[@]}" -gt 5 ]; then
            echo "  ... $(( ${#source[@]} - 5 )) more"
        fi
        return 1
    fi

    # Name the class, not just the count -- the two discardable classes have
    # different reasons for being safe, and the operator should be able to tell
    # which one they are looking at. The governance-only wording is preserved
    # verbatim from the first cut so its meaning does not shift underneath the
    # tests that pin it.
    if [ "${#gen[@]}" -eq 0 ]; then
        echo "${#gov[@]} governance file(s) dirty in $wt_path (non-authoritative fork; master is the authority) -- discardable"
    elif [ "${#gov[@]}" -eq 0 ]; then
        echo "${#gen[@]} vendored/generated file(s) dirty in $wt_path (regenerable: fw vendor self / fw version sync / build) -- discardable"
    else
        echo "$(( ${#gov[@]} + ${#gen[@]} )) discardable file(s) dirty in $wt_path: ${#gov[@]} governance (non-authoritative fork; master is the authority), ${#gen[@]} vendored/generated (regenerable) -- discardable"
    fi
    return 2
}

# _wt_unpushed_summary <branch> -> prints a non-empty summary and returns 1 when
# <branch> holds commits reachable from NO remote-tracking ref; prints nothing
# and returns 0 when every commit is already on some remote.
#
# T-2829 / OBS-177 -- the question this answers is "would removing this worktree
# STRAND anything?", i.e. "is any commit here absent from every remote?". The
# original implementation asked a narrower question -- "is refs/remotes/<r>/<branch>
# caught up?" -- and reported the answer using the wider question's words
# ("not on any remote"), while consulting exactly one ref per remote.
#
# Those two questions come apart under the T-100196 flow, which is the NORMAL
# flow here: work FF-lands onto **master**, so origin/<branch> is stale or was
# never created, while every commit sits safely on origin/master. Measured on
# t100199-close: `origin/<branch>..<branch>` = 31, `<branch> --not --remotes` = 0.
# Effect: every master-landed worktree was unremovable except via --force,
# reinstating exactly the bypass habit the guard exists to prevent.
#
# `--not --remotes` is the primitive that matches the claim: reachable from the
# branch, reachable from no remote-tracking ref. (`fw worktree gc` uses content
# comparison instead -- deliberately, per T-100142, because re-derivation defeats
# ref comparison. Different question, different primitive: gc asks "did this work
# LAND", remove asks "would this work be LOST".)
_wt_unpushed_summary() {
    local branch="$1"
    local -a remotes=()
    while IFS= read -r r; do [ -n "$r" ] && remotes+=("$r"); done < <(git remote 2>/dev/null)

    if [ "${#remotes[@]}" -eq 0 ]; then
        echo "no git remotes configured -- cannot verify anything is pushed"
        return 1
    fi

    # Undecidable ⇒ REFUSE, never allow. If the branch ref does not resolve we
    # cannot compute reachability at all, and an empty `rev-list` result must not
    # be read as "nothing stranded". Caught during T-2829's own live test: passing
    # a worktree DIRECTORY name (which is not always the branch name -- here
    # `.claude/worktrees/rca-worktree-push-strand` is on branch
    # `worktree-rca-worktree-push-strand`) made rev-list print nothing, and the
    # first draft's `${stranded:-0}` turned that silence into rc=0 "safe to
    # remove". The predicate it replaced failed SAFE in this case (missing remote
    # ref => refuse), so the fix would have been a regression in the one direction
    # that loses work. Same class as the bug being fixed: a value that is empty
    # for two different reasons, read as though it had only one.
    if ! git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
        echo "branch '$branch' does not resolve -- cannot verify what would be stranded"
        return 1
    fi

    # The actual gate: reachable from <branch>, reachable from no remote ref.
    local stranded
    stranded="$(git rev-list --count "refs/heads/$branch" --not --remotes 2>/dev/null || echo "")"
    if [ -z "$stranded" ]; then
        echo "could not compute reachability for '$branch' -- refusing rather than guessing"
        return 1
    fi
    if [ "$stranded" = "0" ]; then
        return 0
    fi

    # Only now -- once something IS genuinely stranded -- build the per-remote
    # detail, so the operator can see which remote to push to.
    local r remote_ref count
    local -a lines=()
    lines+=("$stranded commit(s) on '$branch' are on no remote (git log $branch --not --remotes)")
    for r in "${remotes[@]}"; do
        remote_ref="refs/remotes/$r/$branch"
        if ! git rev-parse --verify --quiet "$remote_ref" >/dev/null 2>&1; then
            lines+=("$r: branch '$branch' not present on remote")
            continue
        fi
        count="$(git rev-list --count "${remote_ref}..refs/heads/$branch" 2>/dev/null || echo "")"
        [ "${count:-0}" = "0" ] || \
            lines+=("$r: $count commit(s) on '$branch' not on $r/$branch (git log $r/$branch..$branch)")
    done

    printf '%s\n' "${lines[@]}"
    return 1
}

# do_worktree_remove <name-or-path> [--force]
do_worktree_remove() {
    local target="" force=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) force=1 ;;
            -h|--help)
                echo "usage: fw worktree remove <name-or-path> [--force]"
                echo "  Removes the worktree directory (branch is kept). Refuses when the"
                echo "  branch holds commits absent from every remote unless --force is given"
                echo "  (logged Tier-2 to .context/working/.gate-bypass-log.yaml)."
                echo "  Dirty worktrees (T-3102): governance state (.context/**, .tasks/**)"
                echo "  does NOT block -- it is a non-authoritative fork of master's copy and"
                echo "  is discarded with a summary line. Uncommitted SOURCE changes are"
                echo "  refused unconditionally -- --force never discards them."
                return 0 ;;
            -*) echo "worktree remove: unknown option: $1" >&2; return 2 ;;
            *)
                if [ -z "$target" ]; then target="$1"
                else echo "worktree remove: unexpected argument: $1" >&2; return 2; fi
                ;;
        esac
        shift
    done

    if [ -z "$target" ]; then
        echo "usage: fw worktree remove <name-or-path> [--force]" >&2
        return 2
    fi

    git rev-parse --git-dir >/dev/null 2>&1 || {
        echo "worktree remove: not inside a git repository" >&2; return 1; }

    local _WT_REMOVE_PATH="" _WT_REMOVE_BRANCH=""
    if ! _wt_remove_resolve "$target"; then
        echo "worktree remove: no linked worktree matches '$target'" >&2
        echo "  Run 'fw worktree status' to see registered worktrees." >&2
        return 1
    fi

    # T-2831 + T-3102 -- classify uncommitted dirt BEFORE ever attempting `git
    # worktree remove`. Uncommitted work is invisible to the strand guard below
    # (it only counts commits), and git's own dirty refusal gives no indication
    # of value -- exactly the shape that trains --force, and --force (via `git
    # worktree remove --force`) discards uncommitted content with no warning.
    #
    # Two classes, and they get opposite treatment:
    #   SOURCE      -> refused UNCONDITIONALLY, --force included. --force is the
    #                  named strand-override, not a content-discard action
    #                  (T-2831 AC3, preserved verbatim).
    #   DISCARDABLE -> does NOT block. Two sub-classes, both safe for different
    #                  reasons: governance state (non-authoritative fork under
    #                  T-2822 -- master holds the authoritative copy) and
    #                  vendored/generated/session-local churn (regenerable).
    #                  Predicate: _wt_is_discardable_dirt, which REUSES gc's
    #                  _wt_is_ignorable_path rather than restating it.
    #
    # Scoping this to governance ALONE (the first cut of T-3102) was measurably
    # too narrow: all four live worktrees still refused, every one on a dirty
    # `VERSION`. Refusing on non-work made --force routine on EVERY worktree
    # (OBS-177), and --force then discarded genuinely unlanded commits.
    local dirty_summary dirty_rc=0 discard_ok=0
    dirty_summary="$(_wt_dirty_summary "$_WT_REMOVE_PATH")" || dirty_rc=$?

    if [ "$dirty_rc" = "1" ]; then
        echo "worktree remove: REFUSED -- uncommitted SOURCE changes in '$_WT_REMOVE_PATH'" >&2
        echo "$dirty_summary" | sed 's/^/  /' >&2
        echo "" >&2
        echo "  This is source, not governance drift -- --force will NOT discard it." >&2
        echo "  (If instead the branch has unlanded COMMITS, that is a different refusal" >&2
        echo "   with a different remedy -- push/land the branch. This one is about" >&2
        echo "   changes you have not committed at all.)" >&2
        echo "  Review the diff, then either land it or explicitly discard per file:" >&2
        echo "    git -C $_WT_REMOVE_PATH diff HEAD -- <file>     (inspect)" >&2
        echo "    git -C $_WT_REMOVE_PATH checkout HEAD -- <file> (discard, per file, on purpose)" >&2
        return 1
    fi

    if [ "$dirty_rc" = "2" ]; then
        # Discardable-only: proceed. The unlanded-commit guard below is a
        # SEPARATE refusal and still applies -- a worktree whose dirt is all
        # discardable but whose branch holds unlanded commits must still refuse.
        # (Confirmed live: after this correction all four worktrees have zero
        # blocking dirt, and the two strands still refuse on 3 and 1 commits.)
        discard_ok=1
    fi

    # T-2825 gotcha: bin/fw runs under `set -euo pipefail` -- `summary="$(cmd)"; rc=$?`
    # aborts the whole script the instant cmd returns non-zero (a plain assignment
    # statement is not exempt from errexit). `|| rc=$?` keeps the statement's own
    # exit status 0 so errexit never fires.
    local summary rc=0
    summary="$(_wt_unpushed_summary "$_WT_REMOVE_BRANCH")" || rc=$?

    if [ "$rc" != "0" ] && [ "$force" != "1" ]; then
        echo "worktree remove: REFUSED -- branch '$_WT_REMOVE_BRANCH' has commits not on any remote" >&2
        echo "$summary" | sed 's/^/  /' >&2
        echo "" >&2
        echo "  Removing this worktree now would strand those commits (no cwd left to push" >&2
        echo "  from -- origin: T-2428/T-2825, a branch that sat unpushed for 5 weeks this way)." >&2
        echo "" >&2
        echo "  Push first:   git -C $_WT_REMOVE_PATH push origin $_WT_REMOVE_BRANCH" >&2
        echo "  Or override:  fw worktree remove $target --force   (logged Tier-2)" >&2
        return 1
    fi

    if [ "$rc" != "0" ] && [ "$force" = "1" ]; then
        echo "worktree remove: --force override -- proceeding with unpushed commits:" >&2
        echo "$summary" | sed 's/^/  /' >&2
        _wt_log_tier2_bypass "$_WT_REMOVE_BRANCH" "$summary"
    fi

    # Announce the discard only once every guard has passed and removal is
    # actually about to happen -- printing it at classification time would claim
    # a discard that the unlanded guard may still refuse.
    if [ "$discard_ok" = "1" ]; then
        echo "$dirty_summary"
    fi

    if [ "$discard_ok" != "1" ] && git worktree remove "$_WT_REMOVE_PATH" 2>/dev/null; then
        echo "Removed worktree: $_WT_REMOVE_PATH (branch '$_WT_REMOVE_BRANCH' kept)"
    elif [ "$discard_ok" = "1" ] && git worktree remove --force "$_WT_REMOVE_PATH" 2>/dev/null; then
        echo "Removed worktree: $_WT_REMOVE_PATH (branch '$_WT_REMOVE_BRANCH' kept)"
    elif [ "$force" = "1" ] && git worktree remove --force "$_WT_REMOVE_PATH" 2>/dev/null; then
        echo "Removed worktree --force: $_WT_REMOVE_PATH (branch '$_WT_REMOVE_BRANCH' kept)"
    else
        echo "worktree remove: git worktree remove failed (dirty/locked?) -- inspect manually: $_WT_REMOVE_PATH" >&2
        return 1
    fi
    return 0
}

# _wt_log_tier2_bypass <branch> <summary> — append a Tier-2 entry, same append-only
# YAML-list-of-blocks convention as lib/inception.sh:_log_file / lib/review.sh.
_wt_log_tier2_bypass() {
    local branch="$1" summary="$2"
    local log_file="${PROJECT_ROOT:-.}/.context/working/.gate-bypass-log.yaml"
    local ts; ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    mkdir -p "$(dirname "$log_file")" 2>/dev/null
    {
        echo "- timestamp: '$ts'"
        echo "  branch: '$branch'"
        echo "  flag: '--force'"
        echo "  caller: 'do_worktree_remove'"
        echo "  reason: 'worktree teardown unpushed-commit guard (G-076, T-2825)'"
        printf '  summary: %s\n' "$(printf '%s' "$summary" | head -1 | tr -d '\n' | sed "s/'/''/g" | sed "s/^/'/; s/\$/'/")"
    } >> "$log_file" 2>/dev/null
}

# ── fw worktree gc (T-100196 slice 2) ────────────────────────────────────────
# Reclaim landed worktrees + branches. The core problem (T-100199 finding):
# `git cherry` compares patch-ids, which NEVER match after re-derivation
# (`fw integrate` + `fw vendor self` re-commit different file sets), so it reports
# genuinely-landed branches as unlanded and nothing can be safely pruned. gc
# instead does a CONTENT comparison of deliverable files, which survives
# re-derivation: if every source file a branch changed is byte-identical on
# master, the branch's *work* is landed even though its commits never will be.

# Paths that don't count as "deliverable work" for landing decisions — they are
# vendored (re-derived), generated, or session-local governance churn, and differ
# between branch and master even when the real work is landed. This is exactly the
# set that defeats git cherry.
_wt_is_ignorable_path() {
    case "$1" in
        .context/*|.agentic-framework/*|.fabric/*|VERSION) return 0 ;;
        lib/ts/dist/*) return 0 ;;
        *.budget-status|*.hook-counter|*.tool-counter|*.loop-detect.json) return 0 ;;
    esac
    return 1
}

# _wt_work_landed <branch> <master_ref>
# Echoes a reason token; return: 0 = work landed, 1 = unlanded, 2 = undecidable.
#   0 "merged"                    — every commit on the branch is IN master
#   0 "no-deliverables"           — branch changed only ignorable paths
#   0 "all-deliverables-on-master"— every deliverable file byte-identical on master
#   1 "unlanded:<n>/<total>"      — n deliverable files differ from master
#   2 "no-merge-base"             — cannot relate branch to master
_wt_work_landed() {
    local branch="$1" master_ref="$2"
    local mb; mb="$(git merge-base "$branch" "$master_ref" 2>/dev/null)" || { echo "no-merge-base"; return 2; }
    [ -n "$mb" ] || { echo "no-merge-base"; return 2; }

    # ANCESTRY FIRST — and it is not an optimisation (T-3117).
    #
    # The content comparison below asks "is every file this branch touched
    # byte-identical on master TODAY?". For a branch whose commits are all
    # already in master but which is 571 commits BEHIND, the answer is no —
    # master has since changed those files again — and gc reported
    # `unlanded:1440/1442` for a branch git itself calls a strict ancestor.
    # That verdict is not conservative, it is wrong: there is nothing to land,
    # so nothing can be at risk, and "push before any prune" is advice about
    # commits that are already pushed.
    #
    # Measured: t100196-vendor-fix and t100199-close, both strict ancestors of
    # origin/master, sat unreclaimable from 6 July because of this — the exact
    # worktrees whose stale enforcement code produced the duplicate task IDs
    # R7 was built to stop. The tool that should have removed them was telling
    # the operator they held unlanded work.
    #
    # Ancestry is the stronger statement and needs no heuristic: if every
    # commit is contained in master, the work landed. Ask that first; fall
    # through to content comparison only for branches with unique commits,
    # which is the case it was written for (re-derivation defeats `git cherry`).
    if git merge-base --is-ancestor "$branch" "$master_ref" 2>/dev/null; then
        echo "merged"; return 0
    fi

    local -a deliverables=()
    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        _wt_is_ignorable_path "$f" && continue
        deliverables+=("$f")
    done < <(git diff --name-only "$mb" "$branch" 2>/dev/null)

    if [ "${#deliverables[@]}" -eq 0 ]; then
        echo "no-deliverables"; return 0
    fi

    local diffcount=0 bblob mblob
    for f in "${deliverables[@]}"; do
        bblob="$(git rev-parse "$branch:$f" 2>/dev/null || echo MISSING_B)"
        mblob="$(git rev-parse "$master_ref:$f" 2>/dev/null || echo MISSING_M)"
        [ "$bblob" != "$mblob" ] && diffcount=$((diffcount + 1))
    done
    if [ "$diffcount" -eq 0 ]; then
        echo "all-deliverables-on-master"; return 0
    fi
    echo "unlanded:$diffcount/${#deliverables[@]}"; return 1
}

# do_worktree_gc [--apply] [--json]
# Dry-run by default. Classifies every linked worktree + local branch as
# reclaimable (work landed) / keep (unlanded) / active (current or master).
# --apply removes reclaimable *worktrees* (git worktree remove — safe, keeps the
# branch) and surfaces the Tier-0 `git branch -D` commands (never self-run: branch
# deletion is Tier-0, the operator approves it).
do_worktree_gc() {
    local apply=0 json=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --apply) apply=1 ;;
            --json)  json=1 ;;
            -h|--help)
                echo "usage: fw worktree gc [--apply] [--json]"
                echo "  Reclaim landed worktrees/branches by CONTENT comparison (survives re-derivation)."
                echo "  Dry-run default. --apply removes landed worktrees; branch deletes stay Tier-0 (surfaced)."
                return 0 ;;
            *) echo "worktree gc: unknown arg: $1" >&2; return 64 ;;
        esac
        shift
    done

    git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not in a git repository" >&2; return 4; }
    local master_ref; master_ref="$(_wt_master_ref)" || { echo "ERROR: no master/main ref found" >&2; return 4; }

    local -a _WT_PATH _WT_HEAD _WT_BRANCH
    _wt_parse
    local main_path="${_WT_PATH[0]}"
    local cur_top; cur_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"

    # Branch -> worktree path map (a branch checked out in a linked worktree).
    # reclaim/keep rows are "kind|branch|path|reason|has_remote".
    local -a rows=()
    local i br wtpath reason rc has_remote

    # 1) linked worktrees
    for i in "${!_WT_PATH[@]}"; do
        [ "$i" = "0" ] && continue
        wtpath="${_WT_PATH[$i]}"; br="${_WT_BRANCH[$i]}"
        case "$br" in master|main|"(detached)") continue ;; esac
        if reason="$(_wt_work_landed "refs/heads/$br" "$master_ref")"; then rc=0; else rc=$?; fi
        has_remote=no
        git rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null 2>&1 && has_remote=yes
        if [ "$wtpath" = "$cur_top" ]; then
            rows+=("active|$br|$wtpath|current-worktree|$has_remote")
        elif [ "$rc" = "0" ]; then
            rows+=("reclaim-wt|$br|$wtpath|$reason|$has_remote")
        else
            rows+=("keep-wt|$br|$wtpath|$reason|$has_remote")
        fi
    done

    # 2) local branches with no worktree (skip master/main + branches already listed)
    local listed
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        case "$br" in master|main) continue ;; esac
        listed=0
        for i in "${!_WT_BRANCH[@]}"; do [ "${_WT_BRANCH[$i]}" = "$br" ] && listed=1 && break; done
        [ "$listed" = "1" ] && continue
        if reason="$(_wt_work_landed "refs/heads/$br" "$master_ref")"; then rc=0; else rc=$?; fi
        has_remote=no
        git rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null 2>&1 && has_remote=yes
        if [ "$rc" = "0" ]; then
            rows+=("reclaim-branch|$br|-|$reason|$has_remote")
        else
            rows+=("keep-branch|$br|-|$reason|$has_remote")
        fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)

    if [ "$json" = "1" ]; then
        printf '%s\n' "${rows[@]}" | python3 -c '
import sys, json
out=[]
for line in sys.stdin:
    line=line.rstrip("\n")
    if not line: continue
    kind,branch,path,reason,has_remote=line.split("|",4)
    out.append({"kind":kind,"branch":branch,"path":(None if path=="-" else path),
                "reason":reason,"has_remote":has_remote=="yes"})
print(json.dumps({"master_ref":sys.argv[1] if len(sys.argv)>1 else None,"items":out},indent=2))
' "$master_ref"
        return 0
    fi

    # ---- human format ----
    local n_reclaim=0 n_keep=0 r kind rbr rpath rreason rrem
    echo "worktree gc — reclaim analysis (content-verified, survives re-derivation)"
    echo ""
    for r in "${rows[@]}"; do
        IFS='|' read -r kind rbr rpath rreason rrem <<<"$r"
        case "$kind" in
            reclaim-wt)
                n_reclaim=$((n_reclaim+1))
                echo "  ✓ RECLAIM worktree  $rbr  ($rreason)"
                echo "      $rpath"
                if [ "$apply" = "1" ]; then
                    if git worktree remove "$rpath" 2>/dev/null; then
                        echo "      → removed worktree (branch kept)"
                    elif git worktree remove --force "$rpath" 2>/dev/null; then
                        echo "      → removed worktree --force (branch kept)"
                    else
                        echo "      → could NOT remove (dirty/locked?) — inspect manually" >&2
                    fi
                fi
                echo "      Tier-0 to delete branch:  git branch -D $rbr   ($([ "$rrem" = yes ] && echo 'on origin — safe' || echo 'NO remote — pushed?'))"
                ;;
            reclaim-branch)
                n_reclaim=$((n_reclaim+1))
                echo "  ✓ RECLAIM branch    $rbr  ($rreason)"
                echo "      Tier-0 to delete:  git branch -D $rbr   ($([ "$rrem" = yes ] && echo 'on origin — safe' || echo 'NO remote — push first'))"
                ;;
            keep-wt|keep-branch)
                n_keep=$((n_keep+1))
                echo "  ✗ KEEP  ${rbr}  ($rreason)$([ "$rrem" = no ] && echo '  [no remote — push before any prune]')"
                ;;
            active)
                echo "  • ACTIVE (current) $rbr — skipped"
                ;;
        esac
    done
    echo ""
    echo "Summary: $n_reclaim reclaimable, $n_keep to keep (unlanded work — push-then-triage)."
    [ "$apply" = "0" ] && [ "$n_reclaim" -gt 0 ] && echo "Dry-run — re-run with --apply to remove reclaimable worktrees (branch deletes stay Tier-0)."
    return 0
}
