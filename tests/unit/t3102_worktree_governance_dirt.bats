#!/usr/bin/env bats
# T-3102 -- `fw worktree remove` must not be blocked by governance-only dirt.
#
# Measured premise (four live worktrees, 2026-08-20): dirty/governance counts
# 26/23, 5/4, 2/1, 17/15. Governance state is TRACKED, so each worktree holds a
# fork of it, and hooks firing in the MAIN session mutate that fork. git's dirty
# check therefore refused removal on EVERY worktree, which made --force routine
# (OBS-177) -- and --force on a worktree with unlanded commits destroys them.
#
# T-2822's adopted GO: governance state inside a linked worktree is
# NON-AUTHORITATIVE by construction (master is the authority). So governance dirt
# must not block. Source dirt still must. The unlanded-commit guard stays a
# SEPARATE refusal that governance-only dirt does NOT unlock.
#
# T-3102 CORRECTION. Governance alone was too narrow a basis to be operational:
# the dry run found all four live worktrees STILL refusing, every one on a dirty
# `VERSION`, two also on `.agentic-framework/**` and `lib/ts/dist/**`. The rule
# is now
#       blocking dirt = NOT _wt_is_discardable_dirt
# where _wt_is_discardable_dirt REUSES gc's _wt_is_ignorable_path (vendored /
# generated / session-local churn), plus `.tasks/*`, minus `.fabric/*` -- the
# latter because `fw fabric scan` skips existing cards, so a modified card is
# NOT regenerable. Tests 8-13 pin the corrected basis class by class.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=../../lib/worktree.sh
    source "$FRAMEWORK_ROOT/lib/worktree.sh"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    FIX="$(mktemp -d)"
    REMOTE="$FIX/remote.git"
    REPO="$FIX/repo"

    git init -q --bare -b master "$REMOTE"
    git init -q -b master "$REPO"
    mkdir -p "$REPO/.context/working" "$REPO/.context/project" "$REPO/.tasks/active" "$REPO/lib"
    mkdir -p "$REPO/.agentic-framework/lib" "$REPO/lib/ts/dist" "$REPO/.fabric/components"
    echo a > "$REPO/a.txt"
    echo "echo hi" > "$REPO/lib/thing.sh"
    # T-3102 correction fixture: the vendored / generated / derived classes that
    # made all four LIVE worktrees refuse under the first, too-narrow basis.
    echo "1.0.0" > "$REPO/VERSION"
    echo "echo vendored" > "$REPO/.agentic-framework/lib/foo.sh"
    echo "console.log(1)" > "$REPO/lib/ts/dist/foo.js"
    echo "id: c1" > "$REPO/.fabric/components/c1.yaml"
    echo "focus: none" > "$REPO/.context/working/session.yaml"
    echo "decisions: []" > "$REPO/.context/project/decisions.yaml"
    echo "status: captured" > "$REPO/.tasks/active/T-1-base.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    git -C "$REPO" remote add origin "$REMOTE"
    git -C "$REPO" push -q origin master

    export PROJECT_ROOT="$REPO"
}

teardown() {
    if [ -n "${REPO:-}" ] && [ -d "$REPO" ]; then
        git -C "$REPO" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r p; do
            [ "$p" != "$REPO" ] && rm -rf "$p" 2>/dev/null || true
        done
    fi
    [ -n "${FIX:-}" ] && rm -rf "$FIX" 2>/dev/null || true
}

# Worktree whose branch is fully pushed -- the unlanded guard is satisfied, so
# any refusal comes from the dirty classifier alone.
_mk_pushed_wt() {
    local name="$1"
    git -C "$REPO" worktree add -q -b "$name" "$REPO/.claude/worktrees/$name" master
    git -C "$REPO/.claude/worktrees/$name" push -q origin "$name"
}

# Worktree whose branch holds commits on NO remote -- the unlanded guard fires.
_mk_unlanded_wt() {
    local name="$1"
    git -C "$REPO" worktree add -q -b "$name" "$REPO/.claude/worktrees/$name" master
    echo "new work" > "$REPO/.claude/worktrees/$name/lib/feature.sh"
    git -C "$REPO/.claude/worktrees/$name" add -A
    git -C "$REPO/.claude/worktrees/$name" commit -q -m "T-1: unlanded work"
}

_remove() {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove $*"
}

# ── 1. governance-only dirt -> removal proceeds ──────────────────────────────
@test "governance-only dirt: removal PROCEEDS and prints a discard summary" {
    _mk_pushed_wt wt-gov
    local wt="$REPO/.claude/worktrees/wt-gov"
    echo "focus: T-9999" > "$wt/.context/working/session.yaml"
    echo "decisions: [{id: D-1}]" > "$wt/.context/project/decisions.yaml"
    echo "status: started-work" > "$wt/.tasks/active/T-9-scratch.md"

    # Precondition: the dirt is genuinely there, and is genuinely governance-only.
    run git -C "$wt" status --porcelain --untracked-files=all
    [ -n "$output" ]

    _remove wt-gov
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" == *"governance file(s) dirty"* ]]
    [[ "$output" == *"non-authoritative fork"* ]]
    [[ "$output" == *"master is the authority"* ]]
    [ ! -d "$wt" ]
    # branch survives (removal never deletes branches)
    run git -C "$REPO" rev-parse --verify --quiet refs/heads/wt-gov
    [ "$status" -eq 0 ]
}

# ── 2. source dirt only -> refused, NAMES the source paths ───────────────────
@test "source dirt only: REFUSED and the message names the specific source path(s)" {
    _mk_pushed_wt wt-src
    local wt="$REPO/.claude/worktrees/wt-src"
    echo "echo changed" > "$wt/lib/thing.sh"
    echo "brand new" > "$wt/newfile.py"

    _remove wt-src
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"lib/thing.sh"* ]]
    [[ "$output" == *"newfile.py"* ]]
    [ -d "$wt" ]

    # --force is the strand-override, NOT a content-discard action (T-2831 AC3).
    _remove wt-src --force
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [ -d "$wt" ]
}

@test "source path list is capped at 5 with an accurate '... N more' tail" {
    _mk_pushed_wt wt-many
    local wt="$REPO/.claude/worktrees/wt-many"
    for i in 1 2 3 4 5 6 7 8; do echo "x$i" > "$wt/src$i.py"; done

    _remove wt-many
    [ "$status" -eq 1 ]
    [[ "$output" == *"8 uncommitted source file(s)"* ]]
    [[ "$output" == *"... 3 more"* ]]
    # exactly 5 named paths, not 8
    local named
    named="$(printf '%s\n' "$output" | grep -cE '^ +src[0-9]\.py$')"
    [ "$named" -eq 5 ]
}

# ── 3. mixed dirt -> source wins ─────────────────────────────────────────────
@test "mixed governance + source dirt: REFUSED (source wins over governance)" {
    _mk_pushed_wt wt-mixed
    local wt="$REPO/.claude/worktrees/wt-mixed"
    echo "focus: T-9999" > "$wt/.context/working/session.yaml"
    echo "status: started-work" > "$wt/.tasks/active/T-9-scratch.md"
    echo "echo changed" > "$wt/lib/thing.sh"

    _remove wt-mixed
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"lib/thing.sh"* ]]
    # governance files are not counted as source
    [[ "$output" == *"1 uncommitted source file(s)"* ]]
    [ -d "$wt" ]
}

# ── 4. governance-only dirt AND unlanded commits -> STILL refused ────────────
# This is the critical one: two live worktrees hold 6 and 37 unlanded commits
# and MUST NOT become removable because their dirt happens to be governance.
@test "governance-only dirt + unlanded commits: STILL REFUSED, and names unlanded-commits not dirt" {
    _mk_unlanded_wt wt-strand
    local wt="$REPO/.claude/worktrees/wt-strand"
    echo "focus: T-9999" > "$wt/.context/working/session.yaml"
    echo "status: started-work" > "$wt/.tasks/active/T-9-scratch.md"

    # Precondition: dirt is governance-only (classifier would say "proceed").
    run bash -c "source '$FRAMEWORK_ROOT/lib/worktree.sh'; _wt_dirty_summary '$wt'"
    [ "$status" -eq 2 ]

    _remove wt-strand
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"commits not on any remote"* ]]
    # The operator must be able to tell the two remedies apart: this refusal is
    # about unlanded COMMITS, not about uncommitted source.
    [[ "$output" != *"uncommitted SOURCE"* ]]
    [[ "$output" == *"push"* ]]
    [ -d "$wt" ]
    # the unlanded commit is still reachable
    run git -C "$REPO" rev-list --count refs/heads/wt-strand --not --remotes
    [ "$output" -ge 1 ]
}

# ── 5. clean worktree, nothing unlanded -> removes as before ─────────────────
@test "clean worktree with nothing unlanded: removes as before, no discard summary" {
    _mk_pushed_wt wt-clean
    _remove wt-clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" != *"governance file(s) dirty"* ]]
    [ ! -d "$REPO/.claude/worktrees/wt-clean" ]
}

# ── 6. no .context/ directory at all -> no crash, source rules apply ─────────
@test "worktree with no .context/ directory: no crash, behaves under source rules" {
    git -C "$REPO" rm -rq .context .tasks
    git -C "$REPO" commit -q -m "drop governance dirs"
    git -C "$REPO" push -q origin master
    _mk_pushed_wt wt-nogov
    local wt="$REPO/.claude/worktrees/wt-nogov"
    [ ! -d "$wt/.context" ]

    # clean -> removes
    _remove wt-nogov
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]

    # source dirt -> refused, named
    _mk_pushed_wt wt-nogov2
    echo "echo changed" > "$REPO/.claude/worktrees/wt-nogov2/lib/thing.sh"
    _remove wt-nogov2
    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"lib/thing.sh"* ]]
}

# ── 7. the discard summary states the count ACCURATELY ──────────────────────
@test "discard summary count matches the number of dirty governance files exactly" {
    _mk_pushed_wt wt-count
    local wt="$REPO/.claude/worktrees/wt-count"
    # 4 governance files: 2 modified tracked, 2 untracked
    echo "focus: T-1" > "$wt/.context/working/session.yaml"
    echo "decisions: [{id: D-1}]" > "$wt/.context/project/decisions.yaml"
    echo "status: started-work" > "$wt/.tasks/active/T-9-scratch.md"
    echo "- l1" > "$wt/.context/working/feedback-stream.yaml"

    local actual
    actual="$(git -C "$wt" status --porcelain --untracked-files=all | wc -l | tr -d ' ')"
    [ "$actual" -eq 4 ]

    _remove wt-count
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 governance file(s) dirty"* ]]
    # and not an off-by-one or a hardcode
    [[ "$output" != *"3 governance file(s) dirty"* ]]
    [[ "$output" != *"5 governance file(s) dirty"* ]]
}

# ── classifier unit checks (path-level, no worktree needed) ─────────────────
@test "classifier: governance prefixes match, sibling look-alikes do not" {
    source "$FRAMEWORK_ROOT/lib/worktree.sh"
    _wt_is_governance_path ".context/working/session.yaml"
    _wt_is_governance_path ".tasks/active/T-1.md"
    _wt_is_governance_path ".context/project/decisions.yaml"
    if _wt_is_governance_path "lib/worktree.sh"; then false; fi
    if _wt_is_governance_path "docs/context/notes.md"; then false; fi
    if _wt_is_governance_path "contextual.py"; then false; fi
    ! _wt_is_governance_path "tests/unit/x.bats"
}

@test "classifier: rename records classify on the destination path" {
    source "$FRAMEWORK_ROOT/lib/worktree.sh"
    run _wt_porcelain_path "R  lib/old.sh -> lib/new.sh"
    [ "$output" = "lib/new.sh" ]
    run _wt_porcelain_path " M .context/working/session.yaml"
    [ "$output" = ".context/working/session.yaml" ]
}

# ── T-3102 CORRECTION: the vendored / generated / derived classes ────────────
# Each of these was a REAL blocking path on the four live worktrees under the
# first, governance-only basis. One test per class, so a regression names the
# class it broke instead of just "something blocks".

@test "correction: dirty VERSION alone does NOT block removal" {
    _mk_pushed_wt wt-version
    local wt="$REPO/.claude/worktrees/wt-version"
    echo "9.9.9" > "$wt/VERSION"

    # precondition: VERSION really is the only dirty path
    run bash -c "git -C '$wt' status --porcelain --untracked-files=all"
    [ "$output" = " M VERSION" ]

    _remove wt-version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" != *"REFUSED"* ]]
    [[ "$output" == *"vendored/generated file(s) dirty"* ]]
    [ ! -d "$wt" ]
}

@test "correction: dirty .agentic-framework/lib/foo.sh alone does NOT block removal" {
    _mk_pushed_wt wt-vendored
    local wt="$REPO/.claude/worktrees/wt-vendored"
    echo "echo revendored" > "$wt/.agentic-framework/lib/foo.sh"

    _remove wt-vendored
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" != *"REFUSED"* ]]
    [ ! -d "$wt" ]
}

@test "correction: dirty lib/ts/dist/foo.js alone does NOT block removal" {
    _mk_pushed_wt wt-dist
    local wt="$REPO/.claude/worktrees/wt-dist"
    echo "console.log(2)" > "$wt/lib/ts/dist/foo.js"

    _remove wt-dist
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" != *"REFUSED"* ]]
    [ ! -d "$wt" ]
}

@test "correction: dirty .tasks/T-1-base.md alone does NOT block removal" {
    _mk_pushed_wt wt-tasks
    local wt="$REPO/.claude/worktrees/wt-tasks"
    echo "status: started-work" > "$wt/.tasks/active/T-1-base.md"

    _remove wt-tasks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" != *"REFUSED"* ]]
    # .tasks/ is governance, NOT vendored/generated -- the wording must say so
    [[ "$output" == *"governance file(s) dirty"* ]]
    [ ! -d "$wt" ]
}

@test "correction: dirty lib/foo.sh DOES still block removal" {
    _mk_pushed_wt wt-realsrc
    local wt="$REPO/.claude/worktrees/wt-realsrc"
    echo "echo real work" > "$wt/lib/foo.sh"

    _remove wt-realsrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"lib/foo.sh"* ]]
    [ -d "$wt" ]
}

@test "correction: VERSION + lib/foo.sh blocks, and the message names lib/foo.sh not VERSION" {
    _mk_pushed_wt wt-mix2
    local wt="$REPO/.claude/worktrees/wt-mix2"
    echo "9.9.9" > "$wt/VERSION"
    echo "echo real work" > "$wt/lib/foo.sh"

    _remove wt-mix2
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"lib/foo.sh"* ]]
    # exactly ONE blocking path: VERSION must not be counted or named as source
    [[ "$output" == *"1 uncommitted source file(s)"* ]]
    if printf '%s\n' "$output" | grep -qE '^ +VERSION$'; then false; fi
    [ -d "$wt" ]
}

@test "correction: dirty .fabric/ card DOES block -- fabric scan will not regenerate it" {
    _mk_pushed_wt wt-fabric
    local wt="$REPO/.claude/worktrees/wt-fabric"
    echo "id: c1
purpose: hand-written prose that scan will never re-derive" > "$wt/.fabric/components/c1.yaml"

    _remove wt-fabric
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *".fabric/components/c1.yaml"* ]]
    [ -d "$wt" ]
}

@test "correction: mixed governance + vendored dirt reports BOTH classes" {
    _mk_pushed_wt wt-both
    local wt="$REPO/.claude/worktrees/wt-both"
    echo "focus: T-9999" > "$wt/.context/working/session.yaml"
    echo "9.9.9" > "$wt/VERSION"
    echo "console.log(3)" > "$wt/lib/ts/dist/foo.js"

    _remove wt-both
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 discardable file(s) dirty"* ]]
    [[ "$output" == *"1 governance"* ]]
    [[ "$output" == *"2 vendored/generated"* ]]
    [ ! -d "$wt" ]
}

@test "correction: vendored/generated dirt + unlanded commits STILL REFUSES" {
    # Sibling of test 4, for the widened class. The whole point of the widening
    # is that it must NOT weaken the strand guard.
    _mk_unlanded_wt wt-strand2
    local wt="$REPO/.claude/worktrees/wt-strand2"
    echo "9.9.9" > "$wt/VERSION"
    echo "echo revendored" > "$wt/.agentic-framework/lib/foo.sh"

    run bash -c "source '$FRAMEWORK_ROOT/lib/worktree.sh'; _wt_dirty_summary '$wt'"
    [ "$status" -eq 2 ]

    _remove wt-strand2
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"commits not on any remote"* ]]
    [[ "$output" != *"uncommitted SOURCE"* ]]
    [ -d "$wt" ]
}

@test "correction: _wt_is_discardable_dirt reuses the gc set, plus .tasks, minus .fabric" {
    source "$FRAMEWORK_ROOT/lib/worktree.sh"
    # reused from _wt_is_ignorable_path -- must stay in lockstep, not be copied
    for p in ".context/working/session.yaml" ".agentic-framework/bin/fw" \
             "VERSION" "lib/ts/dist/loop-detect.js" ".context/working/.hook-counter"; do
        _wt_is_ignorable_path "$p" || { echo "gc set changed: $p"; false; }
        _wt_is_discardable_dirt "$p" || { echo "not discardable: $p"; false; }
    done
    # delta +: .tasks/ discardable HERE, deliberately NOT in the gc set
    _wt_is_discardable_dirt ".tasks/active/T-1.md"
    if _wt_is_ignorable_path ".tasks/active/T-1.md"; then false; fi
    # delta -: .fabric/ ignorable for gc, NOT discardable here
    _wt_is_ignorable_path ".fabric/components/c1.yaml"
    if _wt_is_discardable_dirt ".fabric/components/c1.yaml"; then false; fi
    # real work is neither
    if _wt_is_discardable_dirt "lib/worktree.sh"; then false; fi
    if _wt_is_discardable_dirt "tests/unit/x.bats"; then false; fi
    ! _wt_is_discardable_dirt "docs/context/notes.md"
}
