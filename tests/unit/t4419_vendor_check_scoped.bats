#!/usr/bin/env bats
# T-4419: `vendor self --check` in a task's Verification blocked every close while
# ANY other worker had an uncommitted framework edit — the check only had a
# whole-tree scope. `--check --task T-XXXX` / `--check --paths p…` check only the
# vendored copies of the task's own files and report the rest as "in flight".
#
#   t1  task's file in sync + unrelated drifted file → scoped 0, whole-tree 1
#   t2  task's own file drifted → scoped 1
#   t3  --paths form: unrelated drift → 0, named drifted path → 1
#   t4  a "T-A, T-B:" batch subject counts as T-B's commit

load ../test_helper

setup() {
    CL="$BATS_TEST_TMPDIR/fw"
    git clone -q --shared "$FRAMEWORK_ROOT" "$CL"
    # Test the code under edit, not HEAD's: overlay the files this fix touches.
    cp "$FRAMEWORK_ROOT/bin/fw" "$CL/bin/fw"
    cp "$FRAMEWORK_ROOT/lib/upgrade.sh" "$CL/lib/upgrade.sh"
    _git commit -qm "T-4419: overlay" -- bin/fw lib/upgrade.sh >/dev/null 2>&1 || true
    _cfw vendor self >/dev/null 2>&1 || true
    git -C "$CL" add -A .agentic-framework
    _git commit -qm "T-4419: baseline sync" >/dev/null 2>&1 || true
    run _cfw vendor self --check
    [ "$status" -eq 0 ] || { echo "clone not clean after sync: $output"; return 1; }
}

teardown() { :; }   # the clone lives under BATS_TEST_TMPDIR

_git() { git -C "$CL" -c user.email=t@t -c user.name=t "$@"; }
_cfw() { ( cd "$CL" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u CLAUDE_PROJECT_DIR "$CL/bin/fw" "$@" ); }

# Commit a change to lib/colors.sh under T-9001 and vendor it (the task's own
# work, done right), then leave an unrelated agents/ file drifted and uncommitted
# (another worker's in-flight edit).
_own_synced_plus_inflight() {
    printf '# t4419 own change\n' >> "$CL/lib/colors.sh"
    cp "$CL/lib/colors.sh" "$CL/.agentic-framework/lib/colors.sh"
    _git commit -qm "T-9001: own change" -- lib/colors.sh .agentic-framework/lib/colors.sh
    printf '# t4419 another worker\n' >> "$CL/agents/context/checkpoint.sh"
}

@test "t4419 t1: task file in sync + unrelated drift -> scoped 0, whole-tree 1" {
    _own_synced_plus_inflight
    run _cfw vendor self --check --task T-9001
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"in flight, not this task: agents/context/checkpoint.sh"* ]] || { echo "$output"; return 1; }
    run _cfw vendor self --check
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "t4419 t2: task's own file drifted -> scoped 1" {
    printf '# t4419 own drift\n' >> "$CL/lib/colors.sh"
    _git commit -qm "T-9002: own change, not vendored" -- lib/colors.sh
    printf '# t4419 another worker\n' >> "$CL/agents/context/checkpoint.sh"
    run _cfw vendor self --check --task T-9002
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    [[ "$output" == *"would sync"* ]] || { echo "$output"; return 1; }
}

@test "t4419 t3: --paths: unrelated drift -> 0, named drifted path -> 1" {
    _own_synced_plus_inflight
    run _cfw vendor self --check --paths lib/colors.sh
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    run _cfw vendor self --check --paths ./agents/context/checkpoint.sh
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "t4419 t4: a 'T-A, T-B:' batch subject counts as T-B's commit" {
    printf '# t4419 batch drift\n' >> "$CL/lib/colors.sh"
    _git commit -qm "T-9003, T-9004: batch" -- lib/colors.sh
    run _cfw vendor self --check --task T-9004
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    # A different task whose id is a prefix must not pick it up.
    run _cfw vendor self --check --task T-900
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
