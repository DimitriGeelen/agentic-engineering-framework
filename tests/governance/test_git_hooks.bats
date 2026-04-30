#!/usr/bin/env bats
# T-1607 (T-1601 GO follow-up, Phase 2): red-team harness for git hooks.
#
# Phase 1 (T-1606, tests/governance/test_pretooluse_gates.bats) covered the 7
# PreToolUse hooks. Phase 2 covers the git-hook layer of governance:
#
#   - commit-msg → blocks commits missing `T-XXX` reference
#   - pre-push → rejects lightweight tag pushes (T-1593)
#   - pre-push → blocks audit FAIL severity
#
# VERSION monotonicity (4th git hook) is already pinned by
# tests/unit/pre_push_version_monotonicity.bats (T-1603) — not duplicated here.
#
# Pattern (copied from T-1603's pre_push_version_monotonicity.bats):
#   1. Spin a fresh temp git repo with mktemp
#   2. Stub agents/audit/audit.sh so the hook's audit step is controllable
#   3. Copy the installed hook bytes from FRAMEWORK_ROOT/.git/hooks/<hook>
#   4. Drive it via stdin (pre-push) or commit message (commit-msg)
#   5. Assert exit code + stderr keyword
#   6. Cleanup in teardown
#
# No mutation of the framework repo — every test is isolated to its temp dir.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    # Stub audit — tests choose pass/fail per-test via overwriting this stub
    mkdir -p agents/audit
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x agents/audit/audit.sh
    # Initial seed commit (no governance constraint — no hook installed yet)
    echo "1.0.0" > VERSION
    git add VERSION agents/audit/audit.sh
    git commit -q -m "T-0: init"
    # Now install hooks by copying the framework's installed bytes (same pattern as T-1603)
    mkdir -p .git/hooks
    if [ -f "$FRAMEWORK_ROOT/.git/hooks/commit-msg" ]; then
        cp "$FRAMEWORK_ROOT/.git/hooks/commit-msg" .git/hooks/commit-msg
        chmod +x .git/hooks/commit-msg
    fi
    if [ -f "$FRAMEWORK_ROOT/.git/hooks/pre-push" ]; then
        cp "$FRAMEWORK_ROOT/.git/hooks/pre-push" .git/hooks/pre-push
        chmod +x .git/hooks/pre-push
    fi
}

teardown() {
    cd /
    rm -rf "$TMP_REPO"
}

# ============================================================================
# commit-msg hook
# ============================================================================

@test "commit-msg: blocks message without T-XXX reference" {
    [ -f .git/hooks/commit-msg ] || skip "commit-msg hook not installed in framework repo"
    echo "change" > note.txt
    git add note.txt
    run git commit -q -m "untagged change with no task reference"
    [ "$status" -ne 0 ]
    [[ "$output" == *"task reference"* ]] || [[ "$output" == *"T-XXX"* ]] || [[ "$output" == *"No task"* ]]
}

@test "commit-msg: ALLOWS message with T-XXX prefix" {
    [ -f .git/hooks/commit-msg ] || skip "commit-msg hook not installed in framework repo"
    echo "change" > note.txt
    git add note.txt
    run git commit -q -m "T-9999: tagged change"
    [ "$status" -eq 0 ]
}

@test "commit-msg: ALLOWS T-XXX in body even if subject lacks prefix" {
    # The hook uses grep -qE 'T-[0-9]+' against the full message — anywhere counts.
    # This pins current behaviour; if it ever tightens to subject-only, this test
    # will fail loudly and the harness will be the place to record the change.
    [ -f .git/hooks/commit-msg ] || skip "commit-msg hook not installed in framework repo"
    echo "change" > note.txt
    git add note.txt
    run git commit -q -m "$(printf 'subject\n\nrefs T-1234')"
    [ "$status" -eq 0 ]
}

# ============================================================================
# pre-push hook — lightweight tag rejection (T-1593)
# ============================================================================

@test "pre-push: BLOCKS lightweight tag push" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    git tag v-lite-1.0  # lightweight tag — points at a commit, not a tag object
    TAG_SHA="$(git rev-parse v-lite-1.0)"
    run bash -c "echo 'refs/tags/v-lite-1.0 $TAG_SHA refs/tags/v-lite-1.0 0000000000000000000000000000000000000000' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lightweight tag"* ]]
}

@test "pre-push: ALLOWS annotated tag push" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    git tag -a v-annot-1.0 -m "release v1.0"  # annotated — has its own tag object
    TAG_SHA="$(git rev-parse v-annot-1.0)"
    run bash -c "echo 'refs/tags/v-annot-1.0 $TAG_SHA refs/tags/v-annot-1.0 0000000000000000000000000000000000000000' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
}

# ============================================================================
# pre-push hook — audit FAIL enforcement
# ============================================================================

@test "pre-push: BLOCKS branch push when audit script exits FAIL (2)" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    # Replace stub audit with one that fails. The pre-push hook resolves audit via
    # PROJECT_ROOT/agents/audit/audit.sh first (root-level wins, T-1396), so
    # overwriting the stubbed copy in the temp repo is sufficient.
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "[FAIL] simulated audit failure for harness" >&2
exit 2
STUB
    chmod +x agents/audit/audit.sh
    # Need a remote SHA to compare against; second commit makes a delta to push
    echo "more" >> VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: bump"
    LOCAL_SHA="$(git rev-parse HEAD)"
    REMOTE_SHA="$(git rev-parse HEAD~1)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
}

@test "pre-push: ALLOWS branch push when audit script exits 0" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    # Stub already exits 0 from setup. Make a delta to push.
    echo "1.1.0" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: bump"
    LOCAL_SHA="$(git rev-parse HEAD)"
    REMOTE_SHA="$(git rev-parse HEAD~1)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
}

# ============================================================================
# pre-push hook — YAML well-formedness gate (T-1610)
# ============================================================================

@test "pre-push: BLOCKS push when .context/project/*.yaml has T-1599-shape corruption" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    # T-1599 corruption shape: `- id:` line at column 0 (outside parent mapping).
    # This produces yaml.YAMLError on safe_load — the exact case the gate exists for.
    mkdir -p .context/project
    cat > .context/project/concerns.yaml <<'EOF'
concerns:
  - id: G-001
    severity: low
    description: "valid entry inside the mapping"
- id: G-002
  severity: high
  description: "BUG: leading dash at column 0 — outside concerns: block"
EOF
    # Need a delta to push (pre-push only fires when there's something to push)
    echo "1.2.0" > VERSION
    git add VERSION .context/project/concerns.yaml
    git -c commit.gpgsign=false commit -q -m "T-0: bump with corrupted yaml"
    LOCAL_SHA="$(git rev-parse HEAD)"
    REMOTE_SHA="$(git rev-parse HEAD~1)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
    [[ "$output" == *"YAML parse failure"* ]] || [[ "$output" == *"yaml"* ]]
}

@test "pre-push: ALLOWS push when .context/project/*.yaml is well-formed" {
    [ -f .git/hooks/pre-push ] || skip "pre-push hook not installed in framework repo"
    # Same shape as above but properly indented — gate should let this through.
    mkdir -p .context/project
    cat > .context/project/concerns.yaml <<'EOF'
concerns:
  - id: G-001
    severity: low
    description: "valid"
  - id: G-002
    severity: high
    description: "also valid"
EOF
    echo "1.3.0" > VERSION
    git add VERSION .context/project/concerns.yaml
    git -c commit.gpgsign=false commit -q -m "T-0: bump with valid yaml"
    LOCAL_SHA="$(git rev-parse HEAD)"
    REMOTE_SHA="$(git rev-parse HEAD~1)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
}
