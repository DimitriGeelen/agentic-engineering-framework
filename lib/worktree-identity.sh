#!/usr/bin/env bash
# lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7)
#
# ONE PREDICATE, THREE SURFACES. The question *am I a linked worktree* is asked by:
#
#   1. lib/paths.sh            — sources this file, so every agent that sources
#                                paths.sh keeps `fw_is_linked_worktree` verbatim.
#   2. bin/fw's L2 redirect    — must answer it BEFORE FRAMEWORK_ROOT exists, and
#                                cannot source paths.sh (which resolves and exports
#                                paths as a side effect of being sourced).
#   3. bin/fw doctor           — suppresses HOST-level drift checks in a worktree
#                                (T-2435/OBS-077); previously an inline copy.
#
# The predicate lived in lib/paths.sh with an independent inline copy in bin/fw's
# doctor. T-3113 measured what that costs one level down: a comparison predicate
# had drifted into three inline copies, and the invariant guarding it named one
# file and was therefore blind to the other two. Adding L2 as a *fourth* copy —
# in the file that decides which binary runs — is the version of that mistake
# with the largest blast radius. So the definition moved here first.
#
# Sourceable and side-effect free by contract: no `set -e`, no exports, no output
# on source, no dependency on FRAMEWORK_ROOT or PROJECT_ROOT. bin/fw sources it
# on every invocation, before anything is resolved; anything it touched at source
# time would run before the framework exists.

[ -n "${_FW_WORKTREE_IDENTITY_LOADED:-}" ] && return 0
_FW_WORKTREE_IDENTITY_LOADED=1

# fw_is_linked_worktree [dir] — exit 0 if DIR (default PROJECT_ROOT/$PWD) is a *linked*
# git worktree (created via `git worktree add`), exit 1 if it's the main checkout or not a
# git repo. Discriminator: a linked worktree's git-dir (<main>/.git/worktrees/<name>)
# differs from its git-common-dir (<main>/.git); in the main checkout the two collapse to
# the same path. Used to suppress HOST-level drift checks (cron install state, self-vendor
# host snapshot) that are owned by the main checkout and false-FAIL in a transient worktree,
# and (T-3111) to decide whether fw is running from a replica of its own enforcement code.
# Origin: T-2435 (OBS-077) — the pre-push audit false-FAILed on every worktree push.
fw_is_linked_worktree() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}"
    local gd gcd
    gd=$(git -C "$dir" rev-parse --git-dir 2>/dev/null) || return 1
    gcd=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    # Absolute-ize relative forms (the main checkout returns ".git" for both).
    case "$gd" in /*) ;; *) gd="$dir/$gd" ;; esac
    case "$gcd" in /*) ;; *) gcd="$dir/$gcd" ;; esac
    # ...then CANONICALISE, because absolute is not the same as comparable.
    # git does not answer the two questions in one form: called against a
    # SUBDIRECTORY of the main checkout it returns --git-dir absolute and
    # --git-common-dir relative ("../.git"), so the prefixing above yields
    # "<root>/.git" vs "<root>/bin/../.git" — textually different, same
    # directory, and the predicate reports every subdirectory of the main
    # checkout as a linked worktree. Silent until T-3111 called it with
    # $FW_BIN_DIR; every prior caller happened to pass a repo root.
    gd=$(readlink -f "$gd" 2>/dev/null || echo "$gd")
    gcd=$(readlink -f "$gcd" 2>/dev/null || echo "$gcd")
    [ "$gd" != "$gcd" ]
}
