#!/usr/bin/env bats
# T-4768: the CLI `fw inception decide` appended the Human-tick provenance row to
# .context/reviews/human-ac-ticks.jsonl (tick_inception_decide_acs, T-3695) but never
# committed it. The main checkout audits the working tree and passed; a clean checkout
# (fresh clone, worktree, CI) had only the committed rows and FAILed the decided tick
# as unprovenanced (055 field finding, sidecar 9160ed1c). The Watchtower path commits
# the row with the decision (web/blueprints/inception.py:_is_decision_file, T-4590).
# The CLI path now commits the decision's own paths, the ledger included, the same way.

load ../test_helper
load ../git_fence

setup() {
    R="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$R"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$R/.tasks"
    export CONTEXT_DIR="$R/.context"
    export NO_COLOR=1
    export WATCHTOWER_URL="http://test.invalid:3000"
    export GIT_AUTHOR_NAME=op GIT_AUTHOR_EMAIL=op@example.com GIT_COMMITTER_NAME=op GIT_COMMITTER_EMAIL=op@example.com
    unset CLAUDECODE AI_AGENT

    mkdir -p "$R/lib" "$R/.tasks/active" "$R/.tasks/completed" "$R/.context/working" \
             "$R/.context/episodic" "$R/.context/project" "$R/.context/reviews"
    echo "id: TEST" > "$R/.framework.yaml"
    git -C "$R" init -q
    git -C "$R" config core.hooksPath /dev/null
    cp "$FRAMEWORK_ROOT/lib/human_ac_ticks.py" "$FRAMEWORK_ROOT/lib/comment_strip.py" "$R/lib/"
    echo base > "$R/unrelated.txt"
    git -C "$R" add -A && git -C "$R" commit -q -m "detector"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() { rm -rf "$R" "${C:-}"; }

_make_inception() {
    local f="$R/.tasks/active/$1-test.md"
    : > "$R/.context/working/.reviewed-$1"
    cat > "$f" <<EOF
---
id: $1
name: "CLI decide commit test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-10-26T00:00:00Z
last_update: 2026-10-26T00:00:00Z
---

# $1: CLI decide commit test

## Recommendation

**Recommendation:** $2

**Rationale:** test rationale

**Evidence:**
- evidence point 1

## Acceptance Criteria

### Agent
- [x] All ticked

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Decision

## Updates
EOF
    git -C "$R" add -A && git -C "$R" commit -q -m "$1: file"
}

_decide() {
    set -Eeuo pipefail
    do_inception_decide "$@" --rationale "test" --i-am-human 2>"$R/err"
}

_clean_audit() {
    C="$(mktemp -d)"
    git clone -q "$R" "$C/repo"
    PROJECT_ROOT="$C/repo" python3 "$C/repo/lib/human_ac_ticks.py" audit
}

@test "CLI decide GO commits the provenance row with the decision; a clean clone audits clean" {
    _make_inception T-9801 GO
    run _decide T-9801 go
    [ "$status" -eq 0 ]
    git -C "$R" log -1 --format=%s | grep -q '^T-9801: inception decision GO$'
    git -C "$R" show --name-only --format= HEAD > "$R/files"
    grep -qx '.context/reviews/human-ac-ticks.jsonl' "$R/files"
    grep -qx '.tasks/completed/T-9801-test.md' "$R/files"
    # Nothing of the decision is left uncommitted.
    [ -z "$(git -C "$R" status --porcelain -- .tasks .context/reviews .context/episodic)" ]
    run _clean_audit
    [ "$status" -eq 0 ]
}

@test "CLI decide DEFER commits the task file (active/) with the decision" {
    _make_inception T-9802 DEFER
    run _decide T-9802 defer
    [ "$status" -eq 0 ]
    git -C "$R" log --format=%s | grep -q '^T-9802: inception decision DEFER$'
    [ -z "$(git -C "$R" status --porcelain -- .tasks/active/T-9802-test.md .context/reviews)" ]
    run _clean_audit
    [ "$status" -eq 0 ]
}

@test "unrelated staged and unstaged work is not swept into the decision commit" {
    _make_inception T-9803 GO
    echo staged > "$R/staged.txt"; git -C "$R" add staged.txt
    echo changed >> "$R/unrelated.txt"
    run _decide T-9803 go
    [ "$status" -eq 0 ]
    git -C "$R" show --name-only --format= HEAD > "$R/files"
    ! grep -qx 'staged.txt' "$R/files" || false
    ! grep -qx 'unrelated.txt' "$R/files" || false
    # ...and stays exactly as it was: staged stays staged, modified stays modified.
    git -C "$R" status --porcelain > "$R/st"
    grep -qx 'A  staged.txt' "$R/st"
    grep -qx ' M unrelated.txt' "$R/st"
}

@test "--from-watchtower does not commit: the decide runner commits it (no double commit)" {
    _make_inception T-9804 GO
    local before; before=$(git -C "$R" rev-parse HEAD)
    run _decide T-9804 go --from-watchtower
    [ "$status" -eq 0 ]
    [ "$(git -C "$R" rev-parse HEAD)" = "$before" ]
}

@test "control: without the commit, a clean clone FAILs the decided tick" {
    _make_inception T-9805 GO
    tick_inception_decide_acs "$R/.tasks/active/T-9805-test.md"
    git -C "$R" commit -q -m "T-9805: tick only" -- .tasks/active/T-9805-test.md
    run _clean_audit
    [ "$status" -eq 2 ]
}

@test "not a git repo: decide still records and does not fail" {
    _make_inception T-9806 GO
    rm -rf "$R/.git"
    run _decide T-9806 go
    [ "$status" -eq 0 ]
    grep -q '^\*\*Decision\*\*: GO$' "$R"/.tasks/completed/T-9806-test.md
}
