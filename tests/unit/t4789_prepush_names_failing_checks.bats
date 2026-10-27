#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4789 (OBS-274): when the pre-push audit gate refuses a push on FAIL, the
# refusal must name the failing check(s) next to itself. The audit output it
# pointed at ("Fix the issues above") is ~200 lines scrolled away, and an agent
# that pipes the push to `tail` saw a refusal with no cause.
#
# Same fixture shape as t3126_prepush_audit_gate_scope.bats: the hook is
# GENERATED into a tmp repo from agents/git/lib/hooks.sh, and the audit is a
# stub that prints FAIL blocks in the real audit's format (ANSI colour included).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t4789-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "t4789@local"
    git config user.name "T-4789 fixture"
    git config commit.gpgsign false

    mkdir -p agents/audit bin
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
if [ "${T4789_EXIT:-0}" = "75" ]; then
    echo "Another audit is already running — exiting (no verdict produced)" >&2
    exit 75
fi
_red=$'\033[0;31m'; _nc=$'\033[0m'
echo -e "${_red}[FAIL]${_nc} Self-vendor drift: libs class — 3 file(s) out of sync"
echo "       Evidence: lib/update.sh lib/promote.sh bin/fw differ from .agentic-framework/ $(printf 'x%.0s' $(seq 1 300))"
echo "       Mitigation: bin/fw vendor self"
echo "       Scope: ref — property of committed content"
for i in $(seq 1 200); do echo "[PASS] filler check $i"; done
echo -e "${_red}[FAIL]${_nc} Invariant suite (tests/lint): 1 of 74 RED"
echo "       Evidence: tests/lint/foo.bats"
echo "       Mitigation: fix it"
echo "       Scope: ref — property of committed content"
echo "AUDIT-SCOPE: fails=2 ref=2 worktree=0"
echo "=== END AUDIT ==="
exit "${T4789_EXIT:-0}"
STUB
    chmod +x agents/audit/audit.sh
    printf '#!/bin/bash\nexit 0\n' > bin/fw
    chmod +x bin/fw

    echo "1.0.0" > VERSION
    git add -A
    git commit -q -m "T-4789: fixture init"
    REMOTE_SHA="$(git rev-parse HEAD)"

    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    export REMOTE_SHA BRANCH
}

teardown() {
    cd /
    [ -n "${TMP_REPO:-}" ] && rm -rf "$TMP_REPO"
    return 0
}

_run_push_hook() {
    local sha; sha="$(git rev-parse HEAD)"
    run env T4789_EXIT="${T4789_EXIT:-0}" FW_PREPUSH_LOCK_WAIT=0 \
        bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
            | .git/hooks/pre-push origin http://localhost 2>&1"
}

# Everything the hook prints from the refusal line on — what `| tail` shows.
_refusal() {
    printf '%s\n' "$output" | sed -n '/ERROR: Push blocked/,$p'
}

@test "t4789 audit FAIL: the refusal names every failing check" {
    T4789_EXIT=2 _run_push_hook
    [ "$status" -eq 1 ]
    r="$(_refusal)"
    [[ "$r" == *"audit has FAILURES"* ]]
    [[ "$r" == *"Self-vendor drift: libs class — 3 file(s) out of sync"* ]]
    [[ "$r" == *"Invariant suite (tests/lint): 1 of 74 RED"* ]]
}

@test "t4789 audit FAIL: each check carries its first evidence line, cut short" {
    T4789_EXIT=2 _run_push_hook
    [ "$status" -eq 1 ]
    r="$(_refusal)"
    [[ "$r" == *"lib/update.sh lib/promote.sh bin/fw differ"* ]]
    [[ "$r" == *"tests/lint/foo.bats"* ]]
    # the 300-char evidence is truncated, not dumped whole
    ! printf '%s\n' "$r" | grep -qE 'x{150}' || false
    [[ "$r" == *"x..."* ]]
    # no raw ANSI escape in the summary
    ! printf '%s\n' "$r" | grep -q $'\033' || false
}

@test "t4789 audit FAIL: the check names survive 'git push | tail -15'" {
    T4789_EXIT=2 _run_push_hook
    [ "$status" -eq 1 ]
    t="$(printf '%s\n' "$output" | tail -15)"
    [[ "$t" == *"Self-vendor drift"* ]]
    [[ "$t" == *"Invariant suite"* ]]
}

@test "t4789 lock held: the refusal says the lock is held and is not an audit failure" {
    T4789_EXIT=75 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit COULD NOT RUN"* ]]
    [[ "$output" == *"Lock: holder unknown"* || "$output" == *"Lock: held by"* ]]
    [[ "$output" != *"audit has FAILURES"* ]]
    [[ "$output" != *"Failing check"* ]]
}
