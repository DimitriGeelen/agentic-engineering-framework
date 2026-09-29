#!/usr/bin/env bats
# T-3550 — a push killed by `timeout` is INDETERMINATE, not failed.
#
# `timeout N git push` bounds the local process. It does not bound, and cannot
# roll back, the transaction on the remote. Measured on handover
# S-2026-0929-0932: origin accepted c97d39fb1 and advanced its ref, timeout
# killed local git at 455s before it could write refs/remotes/ or exit 0, and
# the operator was told `Some pushes failed. Run 'git push' manually`.
#
# The trap these tests exist for: the obvious verification AGREES with the
# false red. The kill is exactly what stops the tracking ref advancing, so
# `rev-list origin/<b>..HEAD` reports commits outstanding and confirms a
# failure that did not happen. Two voices, one stale cache, no disagreement to
# notice. Only `ls-remote` resolves it.
#
# THE CONTROLS ARE LOAD-BEARING. Without "a normal push still reports success"
# and "a genuinely-unlanded push still fails", every other assertion here is
# satisfied by a build that reports success unconditionally — which is the
# defect inverted, not fixed.

load ../test_helper

HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT

    REAL_GIT="$(command -v git)"

    BARE_REMOTE="$TEST_TEMP_DIR/remote.git"
    git init -q --bare "$BARE_REMOTE"

    PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    git -C "$PROJECT_ROOT" init -q -b master
    git -C "$PROJECT_ROOT" config user.email "t3550@test.local"
    git -C "$PROJECT_ROOT" config user.name "T-3550 test"
    git -C "$PROJECT_ROOT" remote add origin "$BARE_REMOTE"
    echo init > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" -c commit.gpgsign=false commit -q -m init
    git -C "$PROJECT_ROOT" push -q origin HEAD:refs/heads/master
    git -C "$PROJECT_ROOT" fetch -q origin 2>/dev/null || true

    . "$FRAMEWORK_ROOT/lib/push-resolve.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Make a local-only commit so HEAD is ahead of what the remote carries.
_local_commit() {
    echo "$RANDOM" >> "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" -c commit.gpgsign=false commit -q -m "local $RANDOM"
}

# ── a `git` shim, first on PATH ──────────────────────────────────────────────
#
# mode=land   : REALLY push, then rewind the tracking ref the way a kill would
#               have left it (never written), then exit 124. This is the exact
#               event of 2026-09-29 — the remote has it, local git died before
#               recording that it does.
# mode=noland : exit 124 without pushing. Nothing reached the remote.
# mode=refuse : exit 1 without pushing. A gate/remote said no.
# mode=blind  : as `noland`, and ALSO break ls-remote, so the resolver cannot
#               find out. The third state.
_install_git_shim() {
    local mode="$1"
    SHIM_DIR="$TEST_TEMP_DIR/shim"
    mkdir -p "$SHIM_DIR"
    cat > "$SHIM_DIR/git" <<SHIM
#!/usr/bin/env bash
REAL="$REAL_GIT"
ROOT="$PROJECT_ROOT"
MODE="$mode"
_is() { for a in "\$@"; do [ "\$a" = "\$1x" ] && return 0; done; return 1; }
verb=""
for a in "\$@"; do
    case "\$a" in
        push|ls-remote) verb="\$a"; break ;;
    esac
done
if [ "\$verb" = "ls-remote" ] && [ "\$MODE" = "blind" ]; then
    exit 128
fi
if [ "\$verb" = "push" ]; then
    case "\$MODE" in
        land)
            prev=\$("\$REAL" -C "\$ROOT" rev-parse -q --verify refs/remotes/origin/master 2>/dev/null)
            "\$REAL" "\$@" >/dev/null 2>&1
            # A killed push never writes refs/remotes/. Put it back so the
            # fixture reproduces the stale-ref state, not a tidied-up one.
            if [ -n "\$prev" ]; then
                "\$REAL" -C "\$ROOT" update-ref refs/remotes/origin/master "\$prev" 2>/dev/null
            else
                "\$REAL" -C "\$ROOT" update-ref -d refs/remotes/origin/master 2>/dev/null
            fi
            exit 124 ;;
        noland|blind) exit 124 ;;
        refuse)       exit 1 ;;
    esac
fi
exec "\$REAL" "\$@"
SHIM
    chmod +x "$SHIM_DIR/git"
}

_run_handover() {
    run env PATH="$SHIM_DIR:$PATH" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        PROJECT_ROOT="$PROJECT_ROOT" NO_COLOR=1 \
        timeout 240 "$HANDOVER" --checkpoint --task T-000 --session "S-T3550-$RANDOM"
}

# ═══ the resolver, directly ══════════════════════════════════════════════════

@test "CONTROL: remote carries HEAD -> landed" {
    run fw_push_resolve_killed "$PROJECT_ROOT" origin 30
    [ "$status" -eq 0 ]
    [ "$output" = "landed" ]
}

@test "landed REPAIRS the tracking ref the kill prevented git from writing" {
    _local_commit
    head=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    # Land it on the remote without letting the tracking ref learn about it —
    # the exact state a killed push leaves behind.
    git -C "$PROJECT_ROOT" push -q origin HEAD:refs/heads/master
    prev=$(git -C "$PROJECT_ROOT" rev-parse refs/remotes/origin/master)
    git -C "$PROJECT_ROOT" update-ref refs/remotes/origin/master "$prev~1" 2>/dev/null || \
        git -C "$PROJECT_ROOT" update-ref -d refs/remotes/origin/master

    run fw_push_resolve_killed "$PROJECT_ROOT" origin 30
    [ "$output" = "landed" ]
    [ "$(git -C "$PROJECT_ROOT" rev-parse refs/remotes/origin/master)" = "$head" ]
}

@test "remote BEHIND head -> not-landed" {
    _local_commit
    run fw_push_resolve_killed "$PROJECT_ROOT" origin 30
    [ "$output" = "not-landed" ]
}

@test "remote answers but has NO such branch -> not-landed, not indeterminate" {
    # ls-remote exits 0 with empty output here. The remote answered; the answer
    # is 'no such branch'. That is knowledge, and must not be filed as absence
    # of knowledge.
    git -C "$PROJECT_ROOT" checkout -q -b never-pushed
    run fw_push_resolve_killed "$PROJECT_ROOT" origin 30
    [ "$output" = "not-landed" ]
}

@test "UNREACHABLE remote -> indeterminate, never silently not-landed" {
    # The load-bearing one. Degrading to not-landed would rebuild the very
    # defect this task removes, one level further down.
    git -C "$PROJECT_ROOT" remote set-url origin "$TEST_TEMP_DIR/does-not-exist.git"
    run fw_push_resolve_killed "$PROJECT_ROOT" origin 10
    [ "$output" = "indeterminate:unreachable" ]
}

@test "detached HEAD -> indeterminate:no-branch, its own reason" {
    git -C "$PROJECT_ROOT" checkout -q --detach
    run fw_push_resolve_killed "$PROJECT_ROOT" origin 10
    [ "$output" = "indeterminate:no-branch" ]
}

@test "the resolver ALWAYS returns 0 — a finding is not an error (OBS-566)" {
    # Its caller runs a report after it. A non-zero return under set -e kills
    # that report, which is the silent-failure class this framework keeps
    # rediscovering (L-387, L-665).
    git -C "$PROJECT_ROOT" remote set-url origin "$TEST_TEMP_DIR/nope.git"
    run bash -c ". '$FRAMEWORK_ROOT/lib/push-resolve.sh'; set -euo pipefail; \
        out=\$(fw_push_resolve_killed '$PROJECT_ROOT' origin 10); rc=\$?; \
        echo \"rc=\$rc out=\$out\"; echo still-alive"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'rc=0'
    echo "$output" | grep -q 'still-alive'
}

# ═══ the caller: handover.sh ═════════════════════════════════════════════════

@test "CONTROL: an ordinary push still reports success and claims no failure" {
    # Without this, everything below is satisfied by a build that never reports
    # a push failure at all.
    SHIM_DIR="$TEST_TEMP_DIR/noshim"; mkdir -p "$SHIM_DIR"
    _run_handover
    echo "$output" | grep -q 'Pushed to origin'
    [ "$(echo "$output" | grep -c 'Some pushes failed')" -eq 0 ]
}

@test "killed BUT LANDED is reported as success, not as a failure" {
    _install_git_shim land
    _run_handover
    echo "$output" | grep -q 'Pushed to origin'
    [ "$(echo "$output" | grep -c 'Some pushes failed')" -eq 0 ]
}

@test "killed but landed does NOT tell the operator to push manually" {
    # The operator-facing point of the whole task: do not send someone to redo
    # finished work. That is how a real warning gets trained into noise.
    _install_git_shim land
    _run_handover
    [ "$(echo "$output" | grep -ci "run 'git push' manually")" -eq 0 ]
}

@test "killed but landed REPAIRS the tracking ref through the caller" {
    _install_git_shim land
    _run_handover
    head=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    [ "$(git -C "$PROJECT_ROOT" rev-parse refs/remotes/origin/master)" = "$head" ]
}

@test "CONTROL: killed and genuinely NOT landed still fails, loudly" {
    # The other half of the control pair. A build that calls everything landed
    # passes every assertion above and fails this one.
    _install_git_shim noland
    _run_handover
    echo "$output" | grep -q 'Some pushes failed'
    echo "$output" | grep -q 'KILLED'
    echo "$output" | grep -q 'does NOT carry HEAD'
}

@test "killed and UNREACHABLE says UNKNOWN, and names ls-remote as the way out" {
    _install_git_shim blind
    _run_handover
    echo "$output" | grep -q 'UNKNOWN, not failed'
    echo "$output" | grep -q 'ls-remote'
    # and it must NOT claim the remote confirmed anything
    [ "$(echo "$output" | grep -c 'does NOT carry HEAD')" -eq 0 ]
}

@test "a non-124 exit is still REFUSED — the other paths are untouched" {
    _install_git_shim refuse
    _run_handover
    echo "$output" | grep -q 'REFUSED'
    echo "$output" | grep -q 'Some pushes failed'
    [ "$(echo "$output" | grep -c 'KILLED')" -eq 0 ]
}

# ═══ shape ═══════════════════════════════════════════════════════════════════

@test "handover.sh and push-resolve.sh parse" {
    bash -n "$HANDOVER"
    bash -n "$FRAMEWORK_ROOT/lib/push-resolve.sh"
}

@test "push-state.sh no longer asserts the tracking ref answers the question" {
    # Its old comment read 'the ref is updated by our own pushes, which is
    # exactly the question being asked'. A killed push is precisely where that
    # is false, and leaving the claim standing is how the next reader
    # re-derives the bug. Comments are stripped nowhere here on purpose: the
    # assertion under test IS a comment.
    [ "$(grep -c 'which is exactly the question being asked' "$FRAMEWORK_ROOT/lib/push-state.sh")" -eq 0 ]
    grep -q 'T-3550' "$FRAMEWORK_ROOT/lib/push-state.sh"
}
