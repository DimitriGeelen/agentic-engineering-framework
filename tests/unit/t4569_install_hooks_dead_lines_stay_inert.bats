#!/usr/bin/env bats
# T-4569: T-4515 keeps the project lines of an old framework hook ACTIVE below the
# managed block. A line that sat AFTER the old hook's unconditional `exit 0` never
# ran — kept active, it starts running on every commit after the upgrade (cloud
# job 2: `echo PROJECT-GATE-RAN` appended to a stock v1.8.14 pre-commit). Keeping a
# line must keep whether it ran: dead lines stay inert, reachable ones stay live.
#
# Like t4515, these tests RUN the installed hook and count what executed, rather
# than grepping for text.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

BEGIN_RE='^# >>> agentic-framework hook'
END_LINE='# <<< agentic-framework hook <<<'

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
    TRACE="$TEST_TMP/ran"
    DEAD_LINE="echo dead >> \"$TRACE\""
    LIVE_LINE="echo live >> \"$TRACE\""
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="${1:-$FRAMEWORK_ROOT}" \
        bash "${1:-$FRAMEWORK_ROOT}/agents/git/git.sh" install-hooks
}

# The pre-T-4403 shape: the raw framework template written whole, no markers.
_raw_old_framework_hook() {
    awk -v b="$BEGIN_RE" -v e="$END_LINE" '
        $0 ~ b {inb=1; next}
        $0 == e {inb=0; next}
        inb && ($0 == "(" || $0 == ") || exit $?") {next}
        {print}' "$1"
}

_run_pre_commit() {
    rm -f "$TRACE"
    cd "$PROJ"
    run bash "$HOOKS/pre-commit"
}

_ran() { if [ -f "$TRACE" ]; then grep -cx "$1" "$TRACE" || true; else echo 0; fi; }

@test "T-4569: a line after the old framework hook's exit 0 stays inert after install-hooks" {
    run _install
    [ "$status" -eq 0 ]
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    grep -qx 'exit 0' "$TEST_TMP/raw"
    echo "$DEAD_LINE" >> "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"; chmod +x "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$(_ran dead)" -eq 0 ]          # dead in the old hook

    run _install
    [ "$status" -eq 0 ]
    grep -q '^# T-4569: project lines kept INERT' "$HOOKS/pre-commit"
    grep -qxF "# $DEAD_LINE" "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$status" -eq 0 ]
    [ "$(_ran dead)" -eq 0 ]          # still dead after the upgrade
    # doctor's T-4403 "commented out" WARN is for lines that USED to run — not these
    ! grep -q '^# T-4403: kept from the previous' "$HOOKS/pre-commit" || false
}

@test "T-4569: a reachable line before the exit stays ACTIVE and runs; a dead one beside it stays inert" {
    run _install
    [ "$status" -eq 0 ]
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    sed -i "2i $LIVE_LINE" "$TEST_TMP/raw"
    echo "$DEAD_LINE" >> "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"; chmod +x "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$(_ran live)" -eq 1 ]
    [ "$(_ran dead)" -eq 0 ]

    run _install
    [ "$status" -eq 0 ]
    grep -qxF "$LIVE_LINE" "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$status" -eq 0 ]
    [ "$(_ran live)" -eq 1 ]          # T-4515: still runs
    [ "$(_ran dead)" -eq 0 ]          # T-4569: still does not
}

@test "T-4569: cloud job 2 — a line appended to a stock v1.8.14 pre-commit does not start running after upgrade" {
    git -C "$FRAMEWORK_ROOT" cat-file -e 'v1.8.14^{commit}' 2>/dev/null \
        || skip "v1.8.14 tag not in this clone"
    mkdir -p "$TEST_TMP/fw814"
    git -C "$FRAMEWORK_ROOT" archive v1.8.14 agents lib bin | tar -x -C "$TEST_TMP/fw814"
    run _install "$TEST_TMP/fw814"
    [ "$status" -eq 0 ]
    ! grep -q "$BEGIN_RE" "$HOOKS/pre-commit" || false   # a pre-block stock hook
    echo "$DEAD_LINE" >> "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$(_ran dead)" -eq 0 ]

    run _install
    grep -q "$BEGIN_RE" "$HOOKS/pre-commit"
    grep -qxF "# $DEAD_LINE" "$HOOKS/pre-commit"
    _run_pre_commit
    [ "$status" -eq 0 ]
    [ "$(_ran dead)" -eq 0 ]
}
