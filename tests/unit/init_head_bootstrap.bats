#!/usr/bin/env bats
# T-2821 — `fw init` runs `git init` but never committed, leaving every fresh
# project with an unborn HEAD (`git rev-parse HEAD` -> exit 128). Claude Code's
# background-session isolation (`EnterWorktree`) preflights with exactly that
# check and refuses to isolate; refusing to isolate means refusing every
# Write/Edit — deadlocking the very first background session in a brand-new
# project before it can write anything, including its own task file.
#
# Fix: `fw init` now makes a single empty bootstrap commit (T-000 placeholder,
# same convention as agents/handover/handover.sh) after git hooks are
# installed, so the commit is validated BY the project's own commit-msg +
# pre-commit hooks rather than bypassing them, and succeeds even with no git
# identity configured (author/committer scoped to the one commit via env).

bats_require_minimum_version 1.5.0

setup_file() {
    FW="${BATS_TEST_DIRNAME}/../../bin/fw"
    export FW

    # Deliberately OUTSIDE the framework tree (see init_git_identity_blocker.bats
    # for why: a fixture nested under the repo can exercise a different vendor
    # code path than a real consumer does, OBS-162).
    HDIR="${BATS_FILE_TMPDIR:-/tmp}/t2821"
    export HDIR
    rm -rf "$HDIR"; mkdir -p "$HDIR/home" "$HDIR/fresh"

    # No global git identity resolvable — the common case (T-2818), and the
    # harder path for the fix (a bootstrap commit must succeed WITHOUT any
    # identity anywhere).
    env HOME="$HDIR/home" GIT_CONFIG_GLOBAL="$HDIR/no-such-gitconfig" \
        "$FW" init "$HDIR/fresh" --provider generic > "$HDIR/fresh.log" 2>&1 || true

    # Existing-project control: a repo that already has a real commit before
    # `fw init` ever touches it. Proves the bootstrap is a no-op when HEAD
    # already resolves — no piling up of empty commits on top of real history.
    mkdir -p "$HDIR/existing"
    git -C "$HDIR/existing" init -q
    git -C "$HDIR/existing" config user.email a@example.com
    git -C "$HDIR/existing" config user.name "A"
    echo hi > "$HDIR/existing/README.md"
    git -C "$HDIR/existing" add README.md
    git -C "$HDIR/existing" commit -q -m "initial"
    env HOME="$HDIR/home" GIT_CONFIG_GLOBAL="$HDIR/no-such-gitconfig" \
        "$FW" init "$HDIR/existing" --provider generic > "$HDIR/existing.log" 2>&1 || true
}

@test "fresh init: HEAD resolves" {
    run git -C "$HDIR/fresh" rev-parse -q --verify HEAD
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "fresh init: git worktree add succeeds and checks out from the real HEAD, not an orphan" {
    run git -C "$HDIR/fresh" worktree add "$HDIR/fresh-wt"
    [ "$status" -eq 0 ]
    # An orphan-inferred worktree (the pre-fix, unborn-HEAD case on this git
    # version) prints "inferring '--orphan'" and starts at commit 0000000.
    [[ "$output" != *"inferring"* ]]
    [[ "$output" != *"orphan"* ]]
    run git -C "$HDIR/fresh-wt" rev-parse HEAD
    [ "$status" -eq 0 ]
    [ "$output" != "0000000000000000000000000000000000000000" ]

    # T-2827 / OBS-178 — EVERY assertion above passed while the worktree was
    # EMPTY. They measure the ref; the deadlock lives in the TREE. A bootstrap
    # commit with a zero-file tree resolves, is not an orphan, and checks out
    # nothing — so a background agent isolates into a directory containing only
    # `.git`, which is the identical user-visible failure OBS-175 described.
    # Resolvability was a PROXY for "HEAD has content" and diverged from it.
    # Measured live on published bytes in T-2826: 1 entry, no CLAUDE.md.
    #
    # Assert the thing, not the proxy: the worktree must actually be populated
    # with what a governed session needs to function.
    [ -f "$HDIR/fresh-wt/CLAUDE.md" ]
    [ -d "$HDIR/fresh-wt/.tasks" ]
    [ -d "$HDIR/fresh-wt/.claude" ]
    # Without the vendored CLI there is no `fw` in the worktree and no
    # governance runs at all — a populated-looking but non-functional worktree.
    [ -d "$HDIR/fresh-wt/.agentic-framework" ]

    git -C "$HDIR/fresh" worktree remove "$HDIR/fresh-wt" --force
}

@test "fresh init: bootstrap commit uses the T-000 placeholder convention and has a NON-EMPTY tree" {
    run git -C "$HDIR/fresh" log -1 --format=%s
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-000"* ]]

    # T-2827 supersedes T-2821's "and is empty" assertion. An empty tree was the
    # OBS-178 defect, not the intended state — see T-2827 Decisions for why the
    # framework tracks the scaffolding it created.
    run git -C "$HDIR/fresh" ls-tree -r --name-only HEAD
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *".tasks/"* ]]
}

@test "fresh init: exactly one commit — no double-bootstrap" {
    run git -C "$HDIR/fresh" log --oneline
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
}

@test "fresh init: bootstrap commit passed the project's own commit-msg hook (not --no-verify)" {
    # The commit call itself carries no --no-verify flag (source-level proof the
    # fix does not bypass the gates it must pass through). Scoped to the actual
    # invocation line, not the whole file — lib/init.sh's comments legitimately
    # discuss --no-verify elsewhere (bypass-log semantics, rationale prose).
    run grep -c -- "git .*commit --allow-empty" "${BATS_TEST_DIRNAME}/../../lib/init.sh"
    [ "$output" -eq 1 ]
    run grep -- "git .*commit --allow-empty" "${BATS_TEST_DIRNAME}/../../lib/init.sh"
    [[ "$output" != *"--no-verify"* ]]

    # Hooks were installed and executable BEFORE the bootstrap commit ran (they are
    # what actually validated it) — proven by presence on disk after fresh init,
    # since the hooks step (T-880/F3) runs immediately before the bootstrap block.
    [ -x "$HDIR/fresh/.git/hooks/commit-msg" ]
    [ -x "$HDIR/fresh/.git/hooks/pre-commit" ]

    # A commit-msg-hook-conformant message satisfies the T-[0-9]+ pattern the
    # installed hook enforces (would BLOCK "no task reference found" otherwise).
    run git -C "$HDIR/fresh" log -1 --format=%s
    [[ "$output" =~ T-[0-9]+ ]]

    # Negative control — the assertions above establish that the hook files exist
    # and that the bootstrap message *would* satisfy them, which is not the same
    # claim as "the hook ran and passed it". A hook can be present and inert
    # (core.hooksPath redirected, silent no-op install — `fw git install-hooks`
    # is known to exit 0 having installed nothing). Both states look identical
    # from presence alone, so presence cannot witness enforcement.
    #
    # Firing the gate in the negative direction is what witnesses it: a commit
    # carrying NO task reference must be REFUSED in this same repo. If it were
    # accepted, every assertion above would still pass while the "not
    # --no-verify" claim in this test's name became vacuous.
    run env GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost \
            GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost \
            git -C "$HDIR/fresh" commit --allow-empty -q -m "no task reference here"
    [ "$status" -ne 0 ]

    # …and the refusal must come from the framework's gate, not from some
    # unrelated failure (missing identity, bad repo) that would also be non-zero.
    [[ "$output" == *"task"* ]]
}

@test "fresh init: framework scaffolding IS tracked, and the tree is clean afterwards" {
    # T-2827 inverts T-2821's assertion. The old test pinned "payload stays
    # untracked" so T-003 would have a real first commit to make; the cost was a
    # zero-file tree and therefore an empty worktree (OBS-178). T-003 still has
    # a real first commit to make — of the OPERATOR's project content, which a
    # freshly initialised project contains none of. See T-2827 Decisions.
    run git -C "$HDIR/fresh" ls-files
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *".agentic-framework/"* ]]

    # Nothing left dangling: a fresh init is a VALID git state, which is the
    # property worktree isolation actually requires.
    run git -C "$HDIR/fresh" status --porcelain
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "re-init (--force) does not add a second bootstrap commit" {
    run env HOME="$HDIR/home" GIT_CONFIG_GLOBAL="$HDIR/no-such-gitconfig" \
        "$FW" init "$HDIR/fresh" --provider generic --force
    [ "$status" -eq 0 ]
    run git -C "$HDIR/fresh" log --oneline
    [ "${#lines[@]}" -eq 1 ]
}

@test "existing project with prior history: fw init does not touch HEAD or add a bootstrap commit" {
    run git -C "$HDIR/existing" log --oneline
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *"initial"* ]]
    run cat "$HDIR/existing.log"
    [[ "$output" != *"Bootstrap commit created"* ]]
}
