#!/usr/bin/env bats
# Unit tests for _count_inception_exploration_commits (T-2195)
#
# The inception commit-budget gate must count only EXPLORATION commits.
# Storage commits (filing-only, demote, status-flip, frontmatter edit) are
# bookkeeping with zero exploration content and must be exempt.
#
# Origin: T-2186 itself hit the budget at commit 3 (Step 0 findings) because
# filing + demote consumed 2/2 with zero exploration — the same scoring-shaped
# rigidity the inception was trying to recalibrate.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1

    cd "$TEST_TEMP_DIR"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p .tasks/active docs/reports
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: source just the classifier function from hooks.sh
_load_classifier() {
    # The function is self-contained — pull it out of hooks.sh.
    # Extract from "_count_inception_exploration_commits()" through its matching "}".
    awk '
        /^_count_inception_exploration_commits\(\)/ { in_fn=1; brace=0 }
        in_fn { print; for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="{") brace++; if (c=="}") { brace--; if (brace==0 && in_fn) { in_fn=0 } } } }
    ' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh" > "$TEST_TEMP_DIR/_classifier.sh"
    source "$TEST_TEMP_DIR/_classifier.sh"
}

@test "classifier function is defined in hooks.sh" {
    grep -q "^_count_inception_exploration_commits()" "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}

@test "filing-only commit counts as 0 exploration commits" {
    _load_classifier
    echo "task body" > .tasks/active/T-9001-test.md
    git add .tasks/active/T-9001-test.md
    git commit -q -m "T-9001: file task"

    run _count_inception_exploration_commits "T-9001"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "filing + demote (both task-file-only) count as 0 exploration commits" {
    _load_classifier
    echo "task body" > .tasks/active/T-9002-test.md
    git add .tasks/active/T-9002-test.md
    git commit -q -m "T-9002: file task"

    echo "task body v2" > .tasks/active/T-9002-test.md
    git add .tasks/active/T-9002-test.md
    git commit -q -m "T-9002: demote to captured"

    run _count_inception_exploration_commits "T-9002"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "research-artifact commit counts as 1 exploration commit" {
    _load_classifier
    echo "task body" > .tasks/active/T-9003-test.md
    git add .tasks/active/T-9003-test.md
    git commit -q -m "T-9003: file task"

    echo "step 0 findings" > docs/reports/T-9003-seed.md
    git add docs/reports/T-9003-seed.md
    git commit -q -m "T-9003: step 0 findings"

    run _count_inception_exploration_commits "T-9003"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

@test "T-2186-shaped sequence (file + demote + research) counts as 1" {
    _load_classifier
    # Filing: task file + seed material (mixed → exploration)
    echo "task body" > .tasks/active/T-9004-test.md
    echo "seed material" > docs/reports/T-9004-seed.md
    git add .tasks/active/T-9004-test.md docs/reports/T-9004-seed.md
    git commit -q -m "T-9004: file inception with seed material"

    # Demote: task file only (storage)
    echo "task body v2" > .tasks/active/T-9004-test.md
    git add .tasks/active/T-9004-test.md
    git commit -q -m "T-9004: demote to captured"

    # Step 0 findings: research artifact (exploration)
    echo "step 0 findings appended" >> docs/reports/T-9004-seed.md
    git add docs/reports/T-9004-seed.md
    git commit -q -m "T-9004: step 0 findings"

    # 3 total commits: filing (exploration) + demote (storage) + step0 (exploration) = 2
    run _count_inception_exploration_commits "T-9004"
    [ "$status" -eq 0 ]
    [ "$output" -eq 2 ]
}

@test "body-mention of T-XXX in unrelated commit does not inflate count" {
    _load_classifier
    # Unrelated commit mentioning T-9005 in body but with different subject
    echo "other" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "T-9999: unrelated work" -m "Related: T-9005"

    # The actual T-9005 inception filing
    echo "task body" > .tasks/active/T-9005-test.md
    git add .tasks/active/T-9005-test.md
    git commit -q -m "T-9005: file task"

    # Should not double-count
    run _count_inception_exploration_commits "T-9005"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "implementation-touching commit counts as exploration" {
    _load_classifier
    echo "task body" > .tasks/active/T-9006-test.md
    git add .tasks/active/T-9006-test.md
    git commit -q -m "T-9006: file task"

    # Touching implementation source code = exploration (this is what the
    # original 2-commit budget was designed to bound)
    mkdir -p lib
    echo "echo hello" > lib/foo.sh
    git add lib/foo.sh
    git commit -q -m "T-9006: prototype spike"

    run _count_inception_exploration_commits "T-9006"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}
