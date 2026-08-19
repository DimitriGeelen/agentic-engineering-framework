#!/usr/bin/env bats
# T-3090 — a pathspec-scoped commit must not absorb a concurrent writer's index.
#
# The defect: `agents/git/lib/commit.sh` ran `git commit -m "$message"` with no
# pathspec, so it committed the WHOLE INDEX. The handover's narrow
# `git add <2 files>` bounded staging only — and staging is half the operation.
# Live instance: commit d3d3e49db ("T-3028: Session handover S-2026-0819-2334")
# carried 4 files, two of them a concurrent session's T-3089 work, and emptied
# that session's index out from under it mid-compose.
#
# ── What these tests are actually asserting ──────────────────────────────────
# NOT "the commit succeeded" and NOT "the foreign file is absent". A do_commit
# that committed NOTHING AT ALL would satisfy "the foreign file is absent"
# trivially — two empty sets are equal (L-616). Every leak assertion below is
# therefore paired with a positive control asserting the INTENDED file IS in the
# commit. Both halves, or the test proves nothing.
#
# ── Isolation (T-3077) ───────────────────────────────────────────────────────
# Every test builds a throwaway git repo under $BATS_TEST_TMPDIR and commits
# there. Nothing here touches the framework working tree — which matters more
# than usual for this file, since the subject under test is "what ends up in a
# commit".

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"

setup() {
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/.tasks/active" "$REPO/.context"
    git -C "$REPO" init -q .
    git -C "$REPO" config user.email "test@example.invalid"
    git -C "$REPO" config user.name "T-3090 fixture"
    # Hooks would drag the live framework's gates into a sandbox that has none
    # of its state; the subject under test is argv handling, not the hooks.
    git -C "$REPO" config core.hooksPath /dev/null

    # A task file so the agent's task_exists() check stays quiet.
    printf -- '---\nid: T-3090\nstatus: started-work\n---\n# T-3090\n' \
        > "$REPO/.tasks/active/T-3090-fixture.md"

    echo base > "$REPO/base.txt"
    git -C "$REPO" add base.txt
    git -C "$REPO" commit -qm "T-0000: base"
    export REPO
}

# _commit ARGS... — drive the real git agent against the sandbox repo.
_commit() {
    run env PROJECT_ROOT="$REPO" TASKS_DIR="$REPO/.tasks" \
        bash "$GIT_AGENT" commit "$@"
}

# _files_in_head — newline-separated paths carried by the tip commit.
_files_in_head() {
    git -C "$REPO" show --pretty=format: --name-only HEAD | grep -v '^$'
}

# ── Why refutations go through a helper and never through bare `!` ───────────
# `! cmd` in NON-FINAL position inside a bats test body is INERT. bats runs the
# body under `set -e`, and `set -e` is specified to ignore the status of a
# command whose value is inverted with `!`. So this:
#
#     ! _files_in_head | grep -qx 'peer.txt'     # leak assertion
#     _files_in_head   | grep -qx 'handover.md'  # positive control
#
# passes even when peer.txt IS in the commit — the negated line's failure is
# discarded and the last line decides the test. Measured, not theorised: the
# first draft of this suite used exactly that shape and stayed GREEN under a
# mutation that disabled pathspec forwarding entirely. Only the FINAL line of a
# body is checked, because there bats uses the body's own return value.
#
# Sibling of L-387 (pipefail/SIGPIPE in verification lines) and of L-616 (two
# empty sets are equal): all three are assertions that look like they check
# something and do not.
#
# _refute_in_head PATH — fails the test if PATH is in the tip commit.
_refute_in_head() {
    if _files_in_head | grep -qx "$1"; then
        echo "LEAK: '$1' is in the commit and must not be" >&2
        _files_in_head >&2
        return 1
    fi
    return 0
}

# _assert_in_head PATH — fails the test if PATH is absent from the tip commit.
# This is the positive control (L-616): without it, a do_commit that committed
# NOTHING would satisfy every _refute_in_head above it.
_assert_in_head() {
    if ! _files_in_head | grep -qx "$1"; then
        echo "MISSING: '$1' should be in the commit and is not" >&2
        _files_in_head >&2
        return 1
    fi
    return 0
}

# ============================================================================
# The regression: a concurrent writer's staged file must survive
# ============================================================================

@test "T-3090: pathspec commit excludes a concurrent writer's staged file" {
    echo mine   > "$REPO/handover.md"
    echo theirs > "$REPO/peer.txt"
    git -C "$REPO" add handover.md peer.txt      # both staged, as in the incident

    _commit -m "T-3090: handover" -- handover.md
    [ "$status" -eq 0 ]

    # Leak assertion — the foreign file did NOT ride along…
    _refute_in_head 'peer.txt'
    # …and the positive control (L-616) — the intended file DID.
    _assert_in_head 'handover.md'
}

@test "T-3090: the concurrent writer's file is still staged afterwards" {
    # The incident's sharpest symptom was not the bad commit — it was the other
    # session's index coming back EMPTY between its add and its commit. A fix
    # that committed correctly but still cleared their index would not be a fix.
    echo mine   > "$REPO/handover.md"
    echo theirs > "$REPO/peer.txt"
    git -C "$REPO" add handover.md peer.txt

    _commit -m "T-3090: handover" -- handover.md
    [ "$status" -eq 0 ]

    run git -C "$REPO" diff --cached --name-only
    [ "$status" -eq 0 ]
    [ "$output" = "peer.txt" ]
}

@test "T-3090: multi-path pathspec takes exactly its paths, no more, no fewer" {
    # The real handover passes two paths. Guards an argv bug that drops all but
    # the first, which the single-path tests above could not see.
    echo one    > "$REPO/handover.md"
    echo two    > "$REPO/LATEST.md"
    echo theirs > "$REPO/peer.txt"
    git -C "$REPO" add handover.md LATEST.md peer.txt

    _commit -m "T-3090: handover" -- handover.md LATEST.md
    [ "$status" -eq 0 ]

    _assert_in_head 'handover.md'
    _assert_in_head 'LATEST.md'
    _refute_in_head 'peer.txt'
    [ "$(_files_in_head | wc -l)" -eq 2 ]
}

@test "T-3090: an UNTRACKED pathspec is refused — the caller's git add is required" {
    # Measured, and the opposite of what the first draft of this fix assumed.
    # `git commit -- <paths>` operates on TRACKED paths; an untracked one fails
    # the whole commit with "did not match any file(s) known to git".
    #
    # This is why the `git add` in handover.sh is load-bearing, not vestigial: a
    # handover file is new every session. Pinned so nobody "simplifies" a caller
    # by deleting its add on the theory that the pathspec covers it — that would
    # turn every handover commit into a hard failure.
    echo mine   > "$REPO/handover.md"      # never staged
    echo theirs > "$REPO/peer.txt"
    git -C "$REPO" add peer.txt

    _commit -m "T-3090: handover" -- handover.md
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "did not match any file"

    # Nothing was committed, and the other writer's index is untouched.
    run git -C "$REPO" rev-list --count HEAD
    [ "$output" = "1" ]
    run git -C "$REPO" diff --cached --name-only
    [ "$output" = "peer.txt" ]
}

@test "T-3090: the same path, once git add-ed, commits cleanly (control for the above)" {
    # Pairs with the untracked test: proves that test fails on TRACKEDNESS and
    # not on some unrelated breakage in the pathspec plumbing.
    echo mine   > "$REPO/handover.md"
    echo theirs > "$REPO/peer.txt"
    git -C "$REPO" add handover.md peer.txt

    _commit -m "T-3090: handover" -- handover.md
    [ "$status" -eq 0 ]
    _assert_in_head 'handover.md'
}

# ============================================================================
# Backward compatibility: the no-pathspec contract is unchanged
# ============================================================================

@test "T-3090: with NO pathspec the whole index is still committed" {
    # Every existing caller does `git add …` then `fw git commit` and expects
    # the index. If this test ever goes red, the fix broke the ordinary flow —
    # which would be a worse bug than the one being fixed.
    echo a > "$REPO/a.txt"
    echo b > "$REPO/b.txt"
    git -C "$REPO" add a.txt b.txt

    _commit -m "T-3090: ordinary flow"
    [ "$status" -eq 0 ]

    _assert_in_head 'a.txt'
    _assert_in_head 'b.txt'
}

@test "T-3090: pass-through git flags still reach git alongside a pathspec" {
    # git_args and pathspec are separate arrays now; assert they compose.
    #
    # The flag is deliberately `--cleanup=verbatim` and NOT `--no-verify`: the
    # Tier 0 hook classifies --no-verify as a hook bypass and blocks the whole
    # command string, so a test using it would file a real approval request on
    # the operator's queue every time the suite runs (same class as T-3077).
    # Any flag exercises the same argv path.
    echo mine > "$REPO/handover.md"
    git -C "$REPO" add handover.md

    _commit -m "T-3090: flag passthrough" --cleanup=verbatim -- handover.md
    [ "$status" -eq 0 ]
    _assert_in_head 'handover.md'
}

# ============================================================================
# The task gate still gates — the fix must not open a hole in P-002
# ============================================================================

@test "T-3090: a message with no task reference is still refused, pathspec or not" {
    echo mine > "$REPO/handover.md"

    _commit -m "no task ref here" -- handover.md
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "No task reference found"

    # And nothing was committed.
    run git -C "$REPO" rev-list --count HEAD
    [ "$output" = "1" ]
}

# ============================================================================
# The callers under repair actually pass a pathspec
# ============================================================================

@test "T-3090: both handover commit legs pass a -- pathspec" {
    # Source-level guard. The behavioural tests above prove do_commit honours a
    # pathspec; this proves the two callers that caused the incident send one.
    run grep -c 'commit -m "\$COMMIT_TASK: .*" -- "\$HANDOVER_FILE"' \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    [ "$status" -eq 0 ]
    [ "$output" -eq 2 ]
}
