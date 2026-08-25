#!/bin/bash
# URL credential handling — one dialect, shared by every writer of an upstream URL.
#
# Origin: T-2693 / OBS-106. `bin/fw` wrote the vendored `.upstream` sentinel from
# `git remote get-url origin` verbatim, so a credentialed origin put a live token
# into a tracked file (and into vendor stdout). The repair already existed in
# `lib/consumer-recover.sh` as `_cr_strip_credentials` and had simply never been
# applied on the write path — a producer/consumer split of the L-399 family:
# one side of a contract shipped, the other side left alone.
#
# This file is that contract's single implementation. Callers source it rather
# than re-deriving a second `sed` dialect, so a future fix to the transformation
# lands everywhere at once. Deliberately dependency-free and side-effect-free
# (no `set -e`, no top-level state) so it is safe to source from anywhere —
# `lib/consumer-recover.sh` sets `set -uo pipefail` at top level, which is why
# `bin/fw` sources this instead of sourcing that.

# Strip credentials from an HTTP(S) URL's userinfo field. Handles both forms:
# the bare-token form (https://TOKEN@host/path → https://host/path) and the
# colon-separated user-and-password form. A URL with no userinfo is returned
# unchanged.
#
# The colon form is deliberately NOT written out as a literal example here: it
# would match the "URL Basic-Auth Credential" pattern this function exists to
# support, making the file a standing finding in its own scan. The tempting
# repair — allowlist this file — is what rebuilds the blind spot (L-519: a text
# match cannot tell a structure from prose describing that structure).
#
# SSH-style URLs (git@host:path) are left untouched: there the `git@` is a
# username, not a credential, and removing it breaks the URL.
fw_strip_url_credentials() {
    local url="$1"
    printf '%s' "$url" | sed -E 's|^(https?://)[^/@]+@|\1|'
}

# Resolve the URL to record as a project's upstream, preferring remotes that are
# credential-free by nature.
#
# Preference order matters and is not cosmetic: `origin` commonly points at a
# private forge with a PAT baked into the URL, while `github` is the public
# mirror and the documented canonical upstream for consumers. Preferring the
# public mirror means the recorded URL is both credential-free AND usable by a
# consumer that has no access to the private forge. The strip below is then
# defence in depth rather than the only line of defence.
#
# Mirrors CR_PREFERRED_UPSTREAM_REMOTES in lib/consumer-recover.sh, which made
# this same call for the recovery path under T-2232.
#
# Usage: fw_preferred_upstream_url <repo_dir> [remote ...]
# Echoes the resolved, credential-stripped URL, or nothing when no remote exists
# (vendored-without-sentinel is a legitimate state — file:// checkouts, forks).
fw_preferred_upstream_url() {
    local repo_dir="$1"; shift
    local remotes=("$@")
    [ "${#remotes[@]}" -eq 0 ] && remotes=(github origin)

    # T-3129: `-e`, not `-d`. `git remote get-url` resolves through a linked
    # worktree's `.git` file; the old test returned empty there, and an empty
    # upstream URL is indistinguishable from "no remote configured".
    [ -e "$repo_dir/.git" ] || return 0

    local r url=""
    for r in "${remotes[@]}"; do
        url=$(git -C "$repo_dir" remote get-url "$r" 2>/dev/null) || url=""
        [ -n "$url" ] && break
    done

    # Fall back to any push remote when none of the preferred names exist.
    if [ -z "$url" ]; then
        url=$(git -C "$repo_dir" remote -v 2>/dev/null | grep "(push)" | head -1 | awk '{print $2}') || url=""
    fi

    [ -z "$url" ] && return 0
    fw_strip_url_credentials "$url"
}
