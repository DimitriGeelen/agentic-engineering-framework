# tests/live_repo_guard.bash — fail a test that changes the real framework repo (T-4671)
#
# Load from a bats file (`load ../live_repo_guard`), then:
#   setup()    { live_repo_guard_begin; ... }
#   teardown() { ...; live_repo_guard_end; }
#
# WHY. tests/governance/test_register_requirements_gate.bats used to cd into the
# framework repo and close T-99xx fixtures there. update-task.sh's T-4094
# postcondition `git add`s every task it closes, so the fixtures landed in the
# REAL index; teardown removed them from disk only, and an unrelated commit
# (a2e53a22a) picked them up. A disk-only cleanup cannot see the index.
#
# WHAT. Snapshot the repo's `git status --porcelain` and the content of its index
# (`git ls-files -s`, read-only — no stat refresh, no lock) before the test, and
# refuse after it if either moved. Neither command writes to the repo.
#
# SCOPE. With no pathspec the comparison is whole-repo, so another process
# changing the same checkout during the test (a parallel worker's edit or commit)
# trips it too — measured on the first run here. In a shared checkout pass the
# pathspecs the test's fixtures could land on; the guard then watches exactly
# that namespace (status and index entries) and nothing another worker touches.

_live_repo_guard_snapshot() {
    local repo="$1"; shift
    git --no-optional-locks -C "$repo" status --porcelain -uall -- "$@" 2>&1
    echo "--- index"
    git --no-optional-locks -C "$repo" ls-files -s -z -- "$@" 2>&1 | sha256sum
}

# _live_watchtower_pid REPO — T-4706: the pid of REPO's Watchtower when it is
# alive, else empty. Read-only: the pid file and kill -0, never a signal.
_live_watchtower_pid() {
    local p
    p=$(tr -cd '0-9' < "$1/.context/working/watchtower.pid" 2>/dev/null) || true
    [ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo "$p"
    return 0
}

# live_repo_guard_begin [REPO [PATHSPEC...]] — default REPO is $FRAMEWORK_ROOT,
# default scope the whole repo. Also notes REPO's live Watchtower pid (T-4706).
live_repo_guard_begin() {
    LIVE_REPO_GUARD_REPO="${1:-$FRAMEWORK_ROOT}"
    shift || true
    LIVE_REPO_GUARD_PATHSPEC=("$@")
    LIVE_REPO_GUARD_BEFORE="$(_live_repo_guard_snapshot "$LIVE_REPO_GUARD_REPO" "${LIVE_REPO_GUARD_PATHSPEC[@]}")"
    LIVE_REPO_GUARD_WT_PID="$(_live_watchtower_pid "$LIVE_REPO_GUARD_REPO")"
}

# live_repo_guard_end — returns 1 (with a diff on stderr) if the repo changed, or
# if a Watchtower that was alive at begin is now dead or replaced (T-4706: a test
# that stops or restarts the operator's live server is a leak like any other).
live_repo_guard_end() {
    [ -n "${LIVE_REPO_GUARD_REPO:-}" ] || return 0
    local after rc=0 wt_after
    after="$(_live_repo_guard_snapshot "$LIVE_REPO_GUARD_REPO" "${LIVE_REPO_GUARD_PATHSPEC[@]}")"
    if [ "$after" != "$LIVE_REPO_GUARD_BEFORE" ]; then
        echo "LIVE REPO GUARD (T-4671): ${BATS_TEST_NAME:-test} changed $LIVE_REPO_GUARD_REPO (status or index):" >&2
        diff <(printf '%s\n' "$LIVE_REPO_GUARD_BEFORE") <(printf '%s\n' "$after") | head -20 >&2
        rc=1
    fi
    if [ -n "${LIVE_REPO_GUARD_WT_PID:-}" ]; then
        wt_after="$(_live_watchtower_pid "$LIVE_REPO_GUARD_REPO")"
        if [ "$wt_after" != "$LIVE_REPO_GUARD_WT_PID" ]; then
            echo "LIVE REPO GUARD (T-4706): ${BATS_TEST_NAME:-test} changed the live Watchtower of $LIVE_REPO_GUARD_REPO: pid $LIVE_REPO_GUARD_WT_PID -> ${wt_after:-dead}" >&2
            rc=1
        fi
    fi
    return "$rc"
}
