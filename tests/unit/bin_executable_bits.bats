#!/usr/bin/env bats
# T-2793 — everything in bin/ must be committed executable.
#
# ── Why this guard exists ──────────────────────────────────────────────────────
#
# `bin/fw-shim` — the project-detecting router built by T-664 to "eliminate the
# global install dependency" — was committed mode 100644 and stayed that way for
# months. install.sh:link_fw tests `[[ ! -x "$shim_src" ]]` and reads a
# non-executable shim as "older install that doesn't have fw-shim yet", so it
# silently fell back to symlinking ~/.local/bin/fw at the GLOBAL CLI. Every
# fresh install therefore ran the global CLI against each project's vendored
# libs — the split brain of T-2793 — while the feature built to prevent exactly
# that sat in the clone, unreachable.
#
# It never reproduced for a framework developer because this repo sets
# `core.fileMode = false`: the working tree keeps its +x, git ignores the bit,
# and a fresh clone is the only place the difference is observable. `git archive
# HEAD bin/fw-shim | tar -t -v` was the check nobody had reason to run.
#
# ── Why the INDEX and not the filesystem ───────────────────────────────────────
#
# With core.fileMode=false, `test -x bin/fw-shim` passes on the developer's box
# for a file that ships non-executable. Asking the filesystem gives the answer
# the defect is made of. `git ls-files -s` reads the index, which is what a
# consumer actually receives.

bats_require_minimum_version 1.5.0

load ../test_helper

@test "every tracked file in bin/ is committed executable (100755)" {
    cd "$FRAMEWORK_ROOT"
    local offenders
    offenders="$(git ls-files -s bin/ | awk '$1 != "100755" { print $1, $4 }')"
    if [ -n "$offenders" ]; then
        echo "Files in bin/ committed non-executable:" >&2
        echo "$offenders" >&2
        echo "" >&2
        echo "Fix: git update-index --chmod=+x <path>" >&2
        echo "(chmod alone is invisible here — core.fileMode is false in this repo.)" >&2
        return 1
    fi
}

@test "a fresh checkout of bin/ really is executable" {
    # The index mode above is the cause; this asserts the effect a consumer sees.
    # Belt and braces on purpose: the two can only agree, and if they ever stop
    # agreeing the assumption that index mode == delivered mode is what broke.
    cd "$FRAMEWORK_ROOT"
    local tmp
    tmp="$(mktemp -d)"
    git archive HEAD bin/ | tar -x -C "$tmp"
    local not_exec
    not_exec="$(find "$tmp/bin" -type f ! -perm -u+x -printf '%f\n' 2>/dev/null)"
    rm -rf "$tmp"
    if [ -n "$not_exec" ]; then
        echo "Not executable after a clean extract of HEAD:" >&2
        echo "$not_exec" >&2
        return 1
    fi
}

@test "install.sh's shim branch is reachable with the shipped mode" {
    # Pins the specific join that failed: link_fw picks the shim only when the
    # shipped file is executable. Extract HEAD like a fresh clone would and run
    # install.sh's own predicate against it.
    cd "$FRAMEWORK_ROOT"
    local tmp
    tmp="$(mktemp -d)"
    git archive HEAD bin/fw-shim bin/fw-router | tar -x -C "$tmp"
    [ -x "$tmp/bin/fw-shim" ]
    [ -x "$tmp/bin/fw-router" ]
    rm -rf "$tmp"
}
