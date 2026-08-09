#!/usr/bin/env bash
# lib/git-identity.sh — one answer to "can this machine commit?" (T-2883)
#
# Six surfaces used to ask this question and each asked it slightly differently,
# all of them by reading `git config user.email` / `user.name`. That probe is
# wrong in one direction and the direction matters: it misses identity supplied
# through the environment, which is exactly how CI, cron and dispatch workers
# supply it. Measured 2026-08-09 — with GIT_AUTHOR_*/GIT_COMMITTER_* set and no
# config, `fw doctor` said "commits will fail" and the commit landed RC=0.
#
# A warning that fires when nothing is wrong stops carrying information (L-527),
# and this one fired on every automated run.
#
# `git var GIT_COMMITTER_IDENT` is the authoritative probe because it is the same
# resolution `git commit` performs: env vars, then local, global and system
# config, then git's own fallbacks. It cannot report a problem `git commit` would
# not have, and it cannot miss one it would.
#
# Six copies of a predicate can disagree and nothing makes them agree (L-399).
# This is the single copy. Source it; do not re-derive it.

# fw_git_identity_ok [dir] — 0 when a commit made here would resolve an identity.
#
# `dir` defaults to the current directory. Runs with -C so repo-local config is
# honoured; falls back to a bare invocation when the directory is not a repo, so
# host-level identity is still answerable outside one.
fw_git_identity_ok() {
    local dir="${1:-.}"
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$dir" var GIT_COMMITTER_IDENT >/dev/null 2>&1
    else
        git var GIT_COMMITTER_IDENT >/dev/null 2>&1
    fi
}

# fw_git_identity_show [dir] — the resolved "Name <email>", or empty.
#
# For the OK branch of a report. Strips git's trailing "<unix-ts> <tz>" so the
# caller gets the part a human recognises.
fw_git_identity_show() {
    local dir="${1:-.}" ident
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        ident=$(git -C "$dir" var GIT_COMMITTER_IDENT 2>/dev/null) || return 1
    else
        ident=$(git var GIT_COMMITTER_IDENT 2>/dev/null) || return 1
    fi
    printf '%s\n' "${ident% * *}"
}

# fw_git_identity_remedy [dir] — the copy-pasteable one-liner that fixes it.
#
# Single line with an explicit `cd`, per CLAUDE.md §Copy-Pasteable Commands: the
# operator seeing this is by definition on a machine that has never been set up,
# so "run git config" without a working directory is advice they cannot follow
# from wherever they happen to be standing.
fw_git_identity_remedy() {
    local dir="${1:-.}"
    printf "cd %s && git config user.email 'you@example.com' && git config user.name 'Your Name'\n" "$dir"
}
