#!/usr/bin/env bats
# T-3126: the pre-push audit gate must act on REF-scoped failures only.
#
# Origin (observed live 2026-08-23, immediately downstream of T-3125): the gate
# runs `audit.sh --section structure` and blocks on exit 2. The audit reads the
# WORKING TREE; the push operates on a REF. Two FAILs owned entirely by another
# session's in-flight work held the push —
#   'Self-vendor drift: libs class — 3 file(s) out of sync' (uncommitted bin/fw
#    and agents/audit/audit.sh)
#   'Invariant suite: 1 of 74 RED' (two UNTRACKED tests/lint/*.bats a runner
#    collects)
# — neither of which existed in the commit being pushed.
#
# The fix partitions findings: the audit tags each FAIL `ref` or `worktree` and
# emits a machine-readable `AUDIT-SCOPE: fails=N ref=X worktree=Y` line; the gate
# blocks only when X > 0, when the line is absent, or when the audit did not run.
#
# L-599: everything here lives in a synthetic repo under a tmpdir. The hook under
# test is GENERATED INTO the fixture from agents/git/lib/hooks.sh, so this suite
# measures the SOURCE rather than whatever sits in the live repo's .git/hooks —
# and no assertion depends on the live tree's dirty state, which would pass for
# the wrong reason today and go red the moment someone tidies up.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t3126-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "t3126@local"
    git config user.name "T-3126 fixture"
    git config commit.gpgsign false

    mkdir -p agents/audit bin
    _install_audit_stub
    _install_fw_stub

    echo "1.0.0" > VERSION
    git add -A
    git commit -q -m "T-3126: fixture init"
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

# The audit under the gate is a stub: this suite pins the GATE's reading of the
# scope contract, not the audit's classification of any particular check. Its
# behaviour is driven entirely by env vars so each case can name the exact shape
# the real audit would emit.
#
#   T3126_EXIT        exit code to return (0 / 1 / 2 / 75)
#   T3126_REF         value for ref=   in the AUDIT-SCOPE line
#   T3126_WT          value for worktree= in the AUDIT-SCOPE line
#   T3126_NO_SCOPE=1  omit the AUDIT-SCOPE line entirely (pre-T-3126 audit)
#   T3126_WT_TITLES   newline-separated worktree-scoped FAIL titles
_install_audit_stub() {
    cat > "$TMP_REPO/agents/audit/audit.sh" <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
if [ "${T3126_EXIT:-0}" = "75" ]; then
    echo "Another audit is already running — exiting (no verdict produced)" >&2
    exit 75
fi
_ref="${T3126_REF:-0}"
_wt="${T3126_WT:-0}"
if [ "$_ref" != "0" ]; then
    echo "[FAIL] a ref-scoped finding"
    echo "       Scope: ref — property of committed content"
fi
if [ -n "${T3126_WT_TITLES:-}" ]; then
    while IFS= read -r _t; do
        [ -z "$_t" ] && continue
        echo "[FAIL] $_t"
        echo "       Scope: worktree — not present in any committed ref"
    done <<< "$T3126_WT_TITLES"
fi
if [ "${T3126_NO_SCOPE:-0}" != "1" ]; then
    echo "AUDIT-SCOPE: fails=$(( _ref + _wt )) ref=$_ref worktree=$_wt"
    if [ -n "${T3126_WT_TITLES:-}" ]; then
        while IFS= read -r _t; do
            [ -z "$_t" ] && continue
            echo "AUDIT-SCOPE-WORKTREE: $_t"
        done <<< "$T3126_WT_TITLES"
    fi
fi
echo "=== END AUDIT ==="
exit "${T3126_EXIT:-0}"
STUB
    chmod +x "$TMP_REPO/agents/audit/audit.sh"
}

# The gate runs several checks before the audit. Neutralise them so a failure
# here can only be the audit gate.
_install_fw_stub() {
    cat > "$TMP_REPO/bin/fw" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$TMP_REPO/bin/fw"
}

_run_push_hook() {
    local sha; sha="$(git rev-parse HEAD)"
    run env T3126_EXIT="${T3126_EXIT:-0}" \
            T3126_REF="${T3126_REF:-0}" \
            T3126_WT="${T3126_WT:-0}" \
            T3126_NO_SCOPE="${T3126_NO_SCOPE:-0}" \
            T3126_WT_TITLES="${T3126_WT_TITLES:-}" \
        bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
            | .git/hooks/pre-push origin http://localhost"
}

# ── (a) worktree-only FAIL → allowed + WARN ─────────────────────────────────

@test "t3126 (a) worktree-only FAIL → push ALLOWED with WARN" {
    T3126_EXIT=2 T3126_REF=0 T3126_WT=1 \
        T3126_WT_TITLES="Invariant suite: 1 of 74 structural invariant(s) RED (T-2837)" \
        _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" != *"Push blocked"* ]]
    [[ "$output" == *"WARNING"* ]]
}

@test "t3126 (a2) the WARN states all three things plainly" {
    T3126_EXIT=2 T3126_REF=0 T3126_WT=1 \
        T3126_WT_TITLES="Invariant suite: 1 of 74 structural invariant(s) RED (T-2837)" \
        _run_push_hook
    [ "$status" -eq 0 ]
    # 1. the finding is in the working tree
    [[ "$output" == *"WORKING TREE"* ]]
    # 2. it is not in the ref being pushed
    [[ "$output" == *"NOT in the ref being pushed"* ]]
    # 3. it is therefore not blocking this push
    [[ "$output" == *"NOT BLOCKING THIS PUSH"* ]]
    # and it names the finding rather than hiding it
    [[ "$output" == *"Invariant suite: 1 of 74"* ]]
}

# ── (b) ref FAIL → BLOCKED ──────────────────────────────────────────────────

@test "t3126 (b) ref-scoped FAIL → push BLOCKED" {
    T3126_EXIT=2 T3126_REF=1 T3126_WT=0 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" == *"REF-scoped"* ]]
    [[ "$output" == *"--no-verify"* ]]
}

# ── (c) both → BLOCKED ──────────────────────────────────────────────────────

@test "t3126 (c) ref AND worktree FAILs → push BLOCKED (ref dominates)" {
    T3126_EXIT=2 T3126_REF=2 T3126_WT=3 \
        T3126_WT_TITLES="Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)" \
        _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" != *"NOT BLOCKING THIS PUSH"* ]]
}

# ── (d) exit 75 → BLOCKED (T-2930 must not be weakened) ─────────────────────

@test "t3126 (d) audit could not run (exit 75) → push BLOCKED" {
    T3126_EXIT=75 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit COULD NOT RUN"* ]]
}

@test "t3126 (d2) exit 75 blocks even with a scope line claiming ref=0" {
    # A gate that did not run is not a gate that passed: the contention branch
    # must fire before any scope reasoning can reach it.
    T3126_EXIT=75 T3126_REF=0 T3126_WT=0 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit COULD NOT RUN"* ]]
    [[ "$output" != *"NOT BLOCKING THIS PUSH"* ]]
}

# ── (e) the literal 2026-08-23 shape ────────────────────────────────────────

@test "t3126 (e) the 2026-08-23 shape (self-vendor libs + invariant RED, both worktree) pushes cleanly" {
    T3126_EXIT=2 T3126_REF=0 T3126_WT=2 \
        T3126_WT_TITLES="Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)
Invariant suite: 1 of 74 structural invariant(s) RED (T-2837)" \
        _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" != *"Push blocked"* ]]
    [[ "$output" == *"Self-vendor drift: libs class"* ]]
    [[ "$output" == *"Invariant suite: 1 of 74"* ]]
    [[ "$output" == *"NOT BLOCKING THIS PUSH"* ]]
}

# ── fail-safe: an audit with no scope contract still blocks ─────────────────

@test "t3126 (f) FAIL with no AUDIT-SCOPE line → BLOCKED (pre-T-3126 audit)" {
    # A consumer running a vendored audit that predates the partition must not
    # have its failures read as worktree-scoped.
    T3126_EXIT=2 T3126_NO_SCOPE=1 T3126_REF=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" == *"scope could not be determined"* ]]
}

@test "t3126 (g) clean audit → push allowed, no scope noise" {
    T3126_EXIT=0 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" != *"Push blocked"* ]]
    [[ "$output" != *"NOT BLOCKING THIS PUSH"* ]]
}

@test "t3126 (h) audit WARN (exit 1) still allowed and unchanged" {
    T3126_EXIT=1 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"Audit has warnings"* ]]
}

# ── audit side: the scope predicates themselves ─────────────────────────────
#
# The cases above pin the GATE's reading of the contract with a stubbed audit.
# These pin the AUDIT's side of it: the three predicates that decide whether a
# self-vendor drift or a RED invariant is a property of the commit or of the
# working tree. They are extracted from agents/audit/audit.sh (so the source is
# what is measured) and exercised against a synthetic repo — never the live one.

_load_scope_predicates() {
    local _fn="$TMP_REPO/scope-predicates.sh"
    awk '/^# --- T-3126 scope predicates/,/^warn_unenumerable\(\) \{/' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh" \
        | sed '/^warn_unenumerable() {/d' > "$_fn"
    # Refuse to pass on an extraction that found nothing.
    grep -q '_t3126_pair_drifts_in_head()' "$_fn"
    grep -q '_t3126_path_uncommitted()' "$_fn"
    grep -q '_t3126_git_ok()' "$_fn"
    # shellcheck disable=SC1090
    source "$_fn"
}

@test "t3126 (i) self-vendor pair clean in HEAD, dirty in worktree → not ref drift" {
    _load_scope_predicates
    mkdir -p lib .agentic-framework/lib
    echo "v1" > lib/thing.sh
    echo "v1" > .agentic-framework/lib/thing.sh
    git add -A && git commit -q -m "T-3126: vendored pair in sync"
    # A concurrent session's uncommitted edit — the origin shape.
    echo "v2 uncommitted" > lib/thing.sh
    run _t3126_pair_drifts_in_head "$TMP_REPO" "lib/thing.sh"
    [ "$status" -ne 0 ]
}

@test "t3126 (j) self-vendor pair drifting in HEAD → ref drift" {
    _load_scope_predicates
    mkdir -p lib .agentic-framework/lib
    echo "v1" > lib/thing.sh
    echo "v0-stale" > .agentic-framework/lib/thing.sh
    git add -A && git commit -q -m "T-3126: committed vendored drift"
    run _t3126_pair_drifts_in_head "$TMP_REPO" "lib/thing.sh"
    [ "$status" -eq 0 ]
}

@test "t3126 (k) source committed but never vendored → ref drift (missing dest counts)" {
    _load_scope_predicates
    mkdir -p lib
    echo "brand new" > lib/newthing.sh
    git add -A && git commit -q -m "T-3126: new lib file, never vendored"
    run _t3126_pair_drifts_in_head "$TMP_REPO" "lib/newthing.sh"
    [ "$status" -eq 0 ]
}

@test "t3126 (l) untracked and modified paths read as uncommitted; clean tracked does not" {
    _load_scope_predicates
    mkdir -p tests/lint
    echo "committed" > tests/lint/pinned.bats
    git add -A && git commit -q -m "T-3126: a committed lint file"
    echo "dropped in by a concurrent session" > tests/lint/untracked.bats
    echo "edited" >> tests/lint/pinned.bats

    run _t3126_path_uncommitted "$TMP_REPO" "tests/lint/untracked.bats"
    [ "$status" -eq 0 ]

    run _t3126_path_uncommitted "$TMP_REPO" "tests/lint/pinned.bats"
    [ "$status" -eq 0 ]

    git checkout -q -- tests/lint/pinned.bats
    run _t3126_path_uncommitted "$TMP_REPO" "tests/lint/pinned.bats"
    [ "$status" -ne 0 ]
}

@test "t3126 (m) no resolvable HEAD → git_ok false, so callers fall back to ref" {
    _load_scope_predicates
    # A repo with no commit yet: `git -C` succeeds, HEAD does not resolve. This
    # is the shape the guard exists for — the predicates must not silently answer
    # "worktree" for a tree they cannot read a committed state out of. Created
    # OUTSIDE TMP_REPO, because a plain directory inside a repo would resolve to
    # its parent's HEAD and pass for the wrong reason.
    local _nohead; _nohead="$(mktemp -d -t fw-t3126-nohead-XXXXXX)"
    git -C "$_nohead" init -q
    run _t3126_git_ok "$_nohead"
    rm -rf "$_nohead"
    [ "$status" -ne 0 ]

    run _t3126_git_ok "$TMP_REPO"
    [ "$status" -eq 0 ]
}

# ── audit side: RED-test attribution (lib/bats_red_attribution.py) ──────────
#
# The invariant-suite finding is the hard one: some structural invariants assert
# things about COMMITTED code (help↔router parity) and some assert things about
# the WORKING TREE (no untracked test files). The declaring .bats file is
# committed in both cases, so attribution has to look at what the failure is
# ABOUT, not only where the assertion lives.

_attribute() {
    printf '%s\n' "$1" | python3 "$FRAMEWORK_ROOT/lib/bats_red_attribution.py" "$TMP_REPO"
}

@test "t3126 (n) evidence paths are harvested; the declaring file is not counted as evidence" {
    # Reproduces the 2026-08-23 shape: a COMMITTED invariant complaining about an
    # UNTRACKED test file. Counting the declaring file as evidence would make the
    # evidence rule unreachable, since bats names it in every failure block.
    mkdir -p tests/lint tests/unit
    echo "committed assertion" > tests/lint/no-untracked-test-files.bats
    echo "dropped in by a concurrent session" > tests/unit/stray.bats
    run _attribute "not ok 43 every collectable test file under tests/ is tracked by git
# (in test file tests/lint/no-untracked-test-files.bats, line 59)
#   \`false' failed
# Test files a runner would collect, absent from git:
#   tests/unit/stray.bats
ok 44 something else"
    [ "$status" -eq 0 ]
    [ "$output" = "tests/lint/no-untracked-test-files.bats|tests/unit/stray.bats" ]
}

@test "t3126 (o) a failure naming no repo paths yields evidence-free attribution" {
    # → the caller falls back to the declaring-file rule, which for a committed
    #   assertion means ref-scoped. This is the help↔router-parity shape.
    mkdir -p tests/lint
    echo "committed assertion" > tests/lint/help-router-parity.bats
    run _attribute "not ok 7 every fw verb appears in fw help
# (in test file tests/lint/help-router-parity.bats, line 12)
#   20 verbs drifted out of help
ok 8 next"
    [ "$status" -eq 0 ]
    [ "$output" = "tests/lint/help-router-parity.bats|" ]
}

@test "t3126 (p) paths that do not resolve to real files are not treated as evidence" {
    # Prose fragments and version strings must not be mistaken for paths, or the
    # evidence rule would fire on nonsense and downgrade a real ref failure.
    mkdir -p tests/lint
    echo "committed assertion" > tests/lint/some-invariant.bats
    run _attribute "not ok 3 a thing holds
# (in test file tests/lint/some-invariant.bats, line 4)
#   expected lib/does-not-exist.sh to match agents/also/missing.py
ok 4 next"
    [ "$status" -eq 0 ]
    [ "$output" = "tests/lint/some-invariant.bats|" ]
}

@test "t3126 (q) only RED tests are attributed; green ones emit nothing" {
    mkdir -p tests/lint
    echo "committed assertion" > tests/lint/a.bats
    run _attribute "ok 1 fine
ok 2 also fine
not ok 3 broken
# (in test file tests/lint/a.bats, line 9)
ok 4 fine again"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
    [ "$output" = "tests/lint/a.bats|" ]
}

@test "t3126 (r) a RED test with no parseable marker at all attributes to nothing" {
    # An empty row is how the caller learns it could not attribute — which it
    # treats as ref-scoped, never as worktree-scoped.
    run _attribute "not ok 1 mystery failure
# no marker, no paths"
    [ "$status" -eq 0 ]
    [ "$output" = "|" ]
}
