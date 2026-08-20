#!/usr/bin/env bats
# T-3110: task-corpus commit guard in the SHARED pre-commit hook (R7 leg L1).
#
# Fixture is a REAL `git worktree add` driving a REAL `git commit` through the
# REAL hook that `fw git install-hooks` generates. Nothing here is mocked, for
# two reasons:
#
#   1. The claim under test is a property of git's own worktree model — that
#      .git/hooks resolves to the shared common dir from every checkout alike.
#      A mocked path shape would assert nothing about that.
#   2. The guard is deliberately resolved from the AUTHORITY (--git-common-dir)
#      rather than from the committing checkout, which is the opposite of every
#      other scanner in that hook. Only a genuine linked worktree exercises the
#      difference.
#
# The fixture is a CONSUMER shape (`.framework.yaml` with framework_path), so the
# third resolution branch — the one 31 vendored consumers will actually take —
# is the one under test rather than the framework-repo shortcut.
#
# THE TEST THAT MATTERS MOST is "main checkout: commit touching .tasks/ is
# allowed". That is the path every normal session takes — handovers, task
# closes, every `fw task update`. A false positive there breaks everything,
# silently, for everyone. It is written first on purpose.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    GUARD="$_FW_ROOT/agents/git/lib/worktree-corpus-guard.sh"
    GIT_AGENT="$_FW_ROOT/agents/git/git.sh"
    [ -f "$GUARD" ] || skip "guard not found: $GUARD"
    [ -f "$GIT_AGENT" ] || skip "git agent not found: $GIT_AGENT"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    WT="$TEST_ROOT/wt"
    mkdir -p "$MAIN"

    git -C "$MAIN" init -q
    git -C "$MAIN" config user.email t@t
    git -C "$MAIN" config user.name t

    mkdir -p "$MAIN/.tasks/active" "$MAIN/.context/working" "$MAIN/lib"
    echo "task"   > "$MAIN/.tasks/active/T-0001-x.md"
    echo "source" > "$MAIN/lib/thing.sh"
    # Consumer shape: the guard is reachable only via framework_path.
    printf 'framework_path: %s\n' "$_FW_ROOT" > "$MAIN/.framework.yaml"
    git -C "$MAIN" add -A >/dev/null 2>&1
    git -C "$MAIN" commit -qm "T-3110: fixture" >/dev/null 2>&1

    PROJECT_ROOT="$MAIN" bash "$GIT_AGENT" install-hooks --force >/dev/null 2>&1
    [ -f "$MAIN/.git/hooks/pre-commit" ] || skip "install-hooks produced no pre-commit hook"
    # Isolate the unit under test: commit-msg / post-commit / pre-push have their
    # own gates (task refs, audit) that would decide these commits for unrelated
    # reasons. Only pre-commit is on trial here.
    rm -f "$MAIN/.git/hooks/commit-msg" "$MAIN/.git/hooks/post-commit" "$MAIN/.git/hooks/pre-push"

    git -C "$MAIN" worktree add -q -b t3110-fixture "$WT" >/dev/null 2>&1
    [ -d "$WT/.tasks/active" ] || skip "git worktree add did not reproduce the tracked corpus"
    git -C "$WT" config user.email t@t
    git -C "$WT" config user.name t

    unset FW_ALLOW_WORKTREE_CORPUS_COMMIT
}

teardown() {
    if [ -n "${MAIN:-}" ] && [ -d "$MAIN" ]; then
        git -C "$MAIN" worktree remove --force "$WT" >/dev/null 2>&1 || true
    fi
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# ══ AC #6 — the one that matters most ════════════════════════════════════════

@test "main checkout: commit touching .tasks/ is allowed (AC 6)" {
    echo "edited" >> "$MAIN/.tasks/active/T-0001-x.md"
    git -C "$MAIN" add .tasks/active/T-0001-x.md
    run git -C "$MAIN" commit -m "T-3110: corpus edit at the authority"
    [ "$status" -eq 0 ]
    [[ "$output" != *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
}

@test "main checkout: NEW task file is allowed (AC 6 — allocation happens here)" {
    echo "new" > "$MAIN/.tasks/active/T-0002-y.md"
    git -C "$MAIN" add .tasks/active/T-0002-y.md
    run git -C "$MAIN" commit -m "T-3110: mint a task at the authority"
    [ "$status" -eq 0 ]
}

@test "main checkout: guard emits nothing at all on a source-only commit (AC 1 silence)" {
    echo "more" >> "$MAIN/lib/thing.sh"
    git -C "$MAIN" add lib/thing.sh
    run git -C "$MAIN" commit -m "T-3110: source at the authority"
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-3110"*"guard"* ]]
}

# ══ AC #1 — refuse a corpus commit from a linked worktree ════════════════════

@test "linked worktree: commit touching .tasks/ is refused (AC 1)" {
    echo "edited" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: corpus edit from a replica"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
    # and it really did not land
    run git -C "$WT" log --oneline -1
    [[ "$output" != *"corpus edit from a replica"* ]]
}

@test "linked worktree: a NEWLY MINTED task id is refused (the T-2505 shape)" {
    echo "dup" > "$WT/.tasks/active/T-0002-minted-twice.md"
    git -C "$WT" add .tasks/active/T-0002-minted-twice.md
    run git -C "$WT" commit -m "T-3110: mint from a replica"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
}

@test "linked worktree: deleting a task file is refused too (D is a corpus write)" {
    git -C "$WT" rm -q .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: delete from a replica"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
}

# ══ AC #7 — source from a worktree is the supported flow ═════════════════════

@test "linked worktree: source-only commit is allowed (AC 7)" {
    echo "worktree source" >> "$WT/lib/thing.sh"
    git -C "$WT" add lib/thing.sh
    run git -C "$WT" commit -m "T-3110: build in the worktree"
    [ "$status" -eq 0 ]
    [[ "$output" != *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
}

@test "linked worktree: a new source file is allowed (AC 7)" {
    mkdir -p "$WT/lib/sub"
    echo "n" > "$WT/lib/sub/new.sh"
    git -C "$WT" add lib/sub/new.sh
    run git -C "$WT" commit -m "T-3110: new source in the worktree"
    [ "$status" -eq 0 ]
}

# ══ AC #3 — mixed commit refused, and it NAMES the .tasks/ paths ═════════════

@test "linked worktree: mixed source+corpus commit is refused and names the .tasks/ paths (AC 3)" {
    echo "src"  >> "$WT/lib/thing.sh"
    echo "task" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add lib/thing.sh .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: mixed from a replica"
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/active/T-0001-x.md"* ]]
    # names the authority, so the agent can act without asking the operator
    [[ "$output" == *"$MAIN"* ]]
    # names the bypass mechanism, and names it as an ENV VAR (AC 4)
    [[ "$output" == *"FW_ALLOW_WORKTREE_CORPUS_COMMIT=1"* ]]
    # does NOT name lib/thing.sh as a reason — only .tasks/ is the subject
    [[ "$output" != *"    lib/thing.sh"* ]]
}

@test "block message names the bypass as env-prefix, not a flag (AC 4)" {
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: refused"
    [[ "$output" == *"FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git commit"* ]]
    [[ "$output" != *"--allow-worktree-corpus-commit"* ]]
}

# ══ AC #4 / AC #5 — bypass permits, and logs Tier-2 ══════════════════════════

@test "linked worktree: env bypass permits the commit (AC 4)" {
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    run env FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git -C "$WT" commit -m "T-3110: bypassed"
    [ "$status" -eq 0 ]
}

@test "linked worktree: bypass writes a Tier-2 entry to the AUTHORITY's bypass log (AC 5)" {
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    env FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 FW_TASK_ID=T-3110 \
        git -C "$WT" commit -m "T-3110: bypassed" >/dev/null 2>&1
    LOG="$MAIN/.context/working/.gate-bypass-log.yaml"
    [ -f "$LOG" ]
    grep -q "FW_ALLOW_WORKTREE_CORPUS_COMMIT" "$LOG"
    grep -q "T-3110" "$LOG"
    grep -q "worktree-corpus-guard" "$LOG"
    # names the staged path — the register has to answer WHAT was bypassed
    grep -q ".tasks/active/T-0001-x.md" "$LOG"
    # logged at the authority, not in the replica's forked copy
    [ ! -f "$WT/.context/working/.gate-bypass-log.yaml" ] || \
        ! grep -q "FW_ALLOW_WORKTREE_CORPUS_COMMIT" "$WT/.context/working/.gate-bypass-log.yaml"
    # the entry parses as YAML
    python3 -c "import yaml,sys; d=yaml.safe_load(open('$LOG')); sys.exit(0 if isinstance(d,list) else 1)"
}

@test "no bypass log entry is written when nothing would have been refused" {
    echo "s" >> "$WT/lib/thing.sh"
    git -C "$WT" add lib/thing.sh
    env FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git -C "$WT" commit -m "T-3110: source" >/dev/null 2>&1
    [ ! -f "$MAIN/.context/working/.gate-bypass-log.yaml" ]
}

# ══ AC #2 — one predicate, many surfaces (the T-3101 shape) ══════════════════

@test "predicate is a sourceable library function, not inline in the hook (AC 2)" {
    run bash -c "source '$_FW_ROOT/lib/paths.sh' >/dev/null 2>&1; source '$GUARD'; declare -F fw_worktree_corpus_commit_refused >/dev/null && declare -F fw_worktree_corpus_staged_paths >/dev/null && declare -F fw_worktree_corpus_authority_root >/dev/null && echo HAVE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"HAVE"* ]]
}

@test "sourced predicate agrees with the hook: refuses in worktree, allows in main (AC 2)" {
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    echo "e" >> "$MAIN/.tasks/active/T-0001-x.md"
    git -C "$MAIN" add .tasks/active/T-0001-x.md

    run bash -c "source '$_FW_ROOT/lib/paths.sh' >/dev/null 2>&1; source '$GUARD'; fw_worktree_corpus_commit_refused '$WT' && echo REFUSE || echo ALLOW"
    [[ "$output" == *"REFUSE"* ]]

    run bash -c "source '$_FW_ROOT/lib/paths.sh' >/dev/null 2>&1; source '$GUARD'; fw_worktree_corpus_commit_refused '$MAIN' && echo REFUSE || echo ALLOW"
    [[ "$output" == *"ALLOW"* ]]
}

@test "authority resolution walks back to the main checkout from the worktree" {
    run bash -c "source '$GUARD'; fw_worktree_corpus_authority_root '$WT'"
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN" ]
    run bash -c "source '$GUARD'; fw_worktree_corpus_authority_root '$MAIN'"
    [ "$output" = "$MAIN" ]
}

@test "staged-paths reads staged CHANGES, not the whole index" {
    # Nothing staged → nothing reported, even though .tasks/ is full of tracked files.
    run bash -c "source '$GUARD'; fw_worktree_corpus_staged_paths '$WT'"
    [ -z "$output" ]
}

# ══ AC #8 — install-hooks installs it, and re-install is idempotent ══════════

@test "fw git install-hooks installs the guard block (AC 8)" {
    grep -q "FW-HOOK-BLOCK: t3110-corpus-guard" "$MAIN/.git/hooks/pre-commit"
    grep -q "worktree-corpus-guard.sh" "$MAIN/.git/hooks/pre-commit"
    [ -x "$MAIN/.git/hooks/pre-commit" ]
}

@test "re-running install-hooks is idempotent — byte-identical, one block (AC 8)" {
    cp "$MAIN/.git/hooks/pre-commit" "$TEST_ROOT/pc.1"
    PROJECT_ROOT="$MAIN" bash "$GIT_AGENT" install-hooks --force >/dev/null 2>&1
    run diff "$TEST_ROOT/pc.1" "$MAIN/.git/hooks/pre-commit"
    [ "$status" -eq 0 ]
    run grep -c "FW-HOOK-BLOCK: t3110-corpus-guard" "$MAIN/.git/hooks/pre-commit"
    [ "$output" = "1" ]
    [ -x "$MAIN/.git/hooks/pre-commit" ]
}

@test "the hook resolves the guard from the AUTHORITY, not from the committing checkout" {
    # The distinguishing property of L1. If the hook resolved off
    # `git rev-parse --show-toplevel` like its siblings, deleting the REPLICA's
    # .framework.yaml would disarm the guard — which is exactly the R7
    # circularity. Deleting it at the replica must change nothing.
    rm -f "$WT/.framework.yaml"
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add -A -- .tasks lib 2>/dev/null || git -C "$WT" add .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: replica with no framework pointer"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TASK-CORPUS COMMIT FROM A LINKED WORKTREE"* ]]
}

@test "guard degrades to ALLOW (loudly) when it is unreachable from the authority" {
    # A guard that failed closed on its own missing dependency would block every
    # commit in the repo. Simulate an authority whose payload predates the fix.
    printf 'framework_path: %s\n' "$TEST_ROOT/nonexistent-framework" > "$MAIN/.framework.yaml"
    echo "e" >> "$WT/.tasks/active/T-0001-x.md"
    git -C "$WT" add .tasks/active/T-0001-x.md
    run git -C "$WT" commit -m "T-3110: unreachable guard"
    [ "$status" -eq 0 ]
    [[ "$output" == *"task-corpus commit guard is NOT running"* ]]
}

@test "the degradation warning is silent in the main checkout" {
    printf 'framework_path: %s\n' "$TEST_ROOT/nonexistent-framework" > "$MAIN/.framework.yaml"
    echo "e" >> "$MAIN/.tasks/active/T-0001-x.md"
    git -C "$MAIN" add .tasks/active/T-0001-x.md .framework.yaml
    run git -C "$MAIN" commit -m "T-3110: authority commit, no guard payload"
    [ "$status" -eq 0 ]
    [[ "$output" != *"task-corpus commit guard is NOT running"* ]]
}
