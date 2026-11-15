#!/usr/bin/env bats
# T-5049 (R-58) — an outside contributor's commit on bleeding-edge that did not arrive
# through a PR the operator merged raises an alarm by name; internal and operator-merged
# commits stay silent; an unverifiable PR is WARN, never OK.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FRAMEWORK_ROOT
    CHECK="$FRAMEWORK_ROOT/lib/outside_commits.py"

    R="$TEST_TEMP_DIR/repo"
    git init -q -b bleeding-edge "$R"
    git -C "$R" config user.email op@internal.invalid
    git -C "$R" config user.name op
    git -C "$R" config core.hooksPath /dev/null
    # Pre-baseline outside commit: must never be judged.
    _commit "Old Outsider" old@outside.invalid "T-0000: before the check existed"
    _commit op op@internal.invalid "T-0000: baseline"
    BASE=$(git -C "$R" rev-parse HEAD)

    cat > "$TEST_TEMP_DIR/policy.yaml" <<EOF
# test policy
baseline_commit: $BASE
operator_github_login: DimitriGeelen
internal_authors:
  - op@internal.invalid
  - "dispatch+*@aef.local"
EOF
    export FW_INTERNAL_IDENTITIES="$TEST_TEMP_DIR/policy.yaml"
    export FW_GITHUB_REPO="owner/repo"
    export PROJECT_ROOT="$R"

    cat > "$TEST_TEMP_DIR/gh" <<'EOF'
#!/bin/bash
echo "$*" >> "$TEST_TEMP_DIR/gh.calls"
[ -n "$STUB_GH_FAIL" ] && { echo "gh: not authenticated" >&2; exit 4; }
# T-5155: "which merged PRs contain this commit" answers its own list (default: none)
case "$2" in */commits/*/pulls) echo "${STUB_COMMIT_PRS:-}"; exit 0 ;; esac
echo "$STUB_MERGED_BY"
EOF
    chmod +x "$TEST_TEMP_DIR/gh"
    export FW_GH_BIN="$TEST_TEMP_DIR/gh"
    export STUB_MERGED_BY=DimitriGeelen
    unset STUB_GH_FAIL
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_commit() {  # name email subject [file]
    local f="${4:-f.txt}"
    echo "$3" >> "$R/$f"
    git -C "$R" add "$f"
    GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" git -C "$R" commit -q -m "$3"
}

@test "internal commits only: exit 0, silent, no gh call" {
    _commit op op@internal.invalid "T-0001: internal"
    _commit worker "dispatch+w1@aef.local" "T-0002: worker"
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"no outside commits"* ]]
    [[ "$output" != *"FAIL outside"* ]]
    [ ! -f "$TEST_TEMP_DIR/gh.calls" ]
}

@test "outside commit pushed directly: exit 2 naming sha and author" {
    _commit "Eve Outside" eve@outside.invalid "T-0003: direct push"
    sha=$(git -C "$R" rev-parse --short=9 HEAD)
    run python3 "$CHECK" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL outside commit $sha by Eve Outside <eve@outside.invalid>"* ]]
    [[ "$output" == *"pushed directly, not through a PR"* ]]
}

@test "outside squash commit (#7) merged by the operator: exit 0" {
    _commit "Eve Outside" eve@outside.invalid "T-0004 (#3): fix thing (#7)"
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" != *"FAIL outside"* ]]
    grep -q "repos/owner/repo/pulls/7" "$TEST_TEMP_DIR/gh.calls"
}

@test "outside squash commit (#7) merged by someone else: exit 2 naming PR #7" {
    export STUB_MERGED_BY=someone
    _commit "Eve Outside" eve@outside.invalid "T-0004 (#3): fix thing (#7)"
    run python3 "$CHECK" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"PR #7 merged by someone, not the operator"* ]]
}

@test "gh failing: exit 1 unverified, never OK" {
    export STUB_GH_FAIL=1
    _commit "Eve Outside" eve@outside.invalid "T-0004 (#3): fix thing (#7)"
    run python3 "$CHECK" audit
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARN outside commit"* ]]
    [[ "$output" == *"unverified"* ]]
}

@test "outside commit before the baseline is ignored" {
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" != *old@outside.invalid* ]]
}

@test "merge-commit form with outside second parent and operator merger: exit 0" {
    git -C "$R" checkout -q -b contrib
    _commit "Eve Outside" eve@outside.invalid "T-0005 (#4): contributed change"
    git -C "$R" checkout -q bleeding-edge
    _commit op op@internal.invalid "T-0006: meanwhile" g.txt
    git -C "$R" merge -q --no-ff contrib -m "Merge pull request #8 from x/y"
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" != *"FAIL outside"* ]]
    grep -q "repos/owner/repo/pulls/8" "$TEST_TEMP_DIR/gh.calls"
}

@test "merge-commit form merged by someone else: exit 2 naming PR #8" {
    export STUB_MERGED_BY=someone
    git -C "$R" checkout -q -b contrib
    _commit "Eve Outside" eve@outside.invalid "T-0005 (#4): contributed change"
    git -C "$R" checkout -q bleeding-edge
    git -C "$R" merge -q --no-ff contrib -m "Merge pull request #8 from x/y"
    run python3 "$CHECK" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"PR #8 merged by someone"* ]]
}

@test "no policy file: not configured, exit 0" {
    export FW_INTERNAL_IDENTITIES="$TEST_TEMP_DIR/absent.yaml"
    _commit "Eve Outside" eve@outside.invalid "T-0003: direct push"
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
}

@test "operator pending lists an open FAIL alarm with commit and author" {
    _commit "Eve Outside" eve@outside.invalid "T-0003: direct push"
    sha=$(git -C "$R" rev-parse --short=9 HEAD)
    run python3 -c "import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib'); import operator_pending as o; d={'inceptions':[],'reviews':[],'runmes':[],'paid_proposals':[],'waiting_on_agent':0,'outside_commits':o.outside_commit_alarms()}; print(o.render(d))"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Outside commits"* ]]
    [[ "$output" == *"$sha"* ]]
    [[ "$output" == *"eve@outside.invalid"* ]]
}

# ── T-5155: a PR merged with a custom merge subject is found through GitHub ─────────────────

@test "T-5155: outside commit in a PR merged by the operator under a custom subject: exit 0" {
    export STUB_COMMIT_PRS=115
    _commit "Eve Outside" eve@outside.invalid "T-5006 (#114): docs fix"
    run python3 "$CHECK" audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 operator-merged"* ]]
    grep -q "commits/.*/pulls" "$TEST_TEMP_DIR/gh.calls"
    grep -q "repos/owner/repo/pulls/115" "$TEST_TEMP_DIR/gh.calls"
}

@test "T-5155: the PR that contains it was merged by someone else: exit 2 naming the PR" {
    export STUB_COMMIT_PRS=115 STUB_MERGED_BY=someone
    _commit "Eve Outside" eve@outside.invalid "T-5006 (#114): docs fix"
    run python3 "$CHECK" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"PR #115 merged by someone, not the operator"* ]]
}

@test "T-5155: GitHub cannot be asked: still FAIL, with the reason" {
    export STUB_GH_FAIL=1
    _commit "Eve Outside" eve@outside.invalid "T-0003: direct push"
    run python3 "$CHECK" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"pushed directly, not through a PR (GitHub could not be asked"* ]]
}
