#!/usr/bin/env bats
# Unit tests for lib/release.sh (T-1256)
#
# Tests version bumping, tag detection, idempotent no-op, and dry-run.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh" 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/release.sh"

    # Build a tiny git repo with a seed tag
    git -C "$TEST_TEMP_DIR" init -q
    git -C "$TEST_TEMP_DIR" config user.email "test@example.com"
    git -C "$TEST_TEMP_DIR" config user.name "Test"
    echo "seed" > "$TEST_TEMP_DIR/README"
    git -C "$TEST_TEMP_DIR" add README
    git -C "$TEST_TEMP_DIR" commit -q -m "seed"
    git -C "$TEST_TEMP_DIR" tag -a v1.5.742 -m "seed tag"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "release: bump patch from v1.5.742 -> v1.5.743" {
    run release_bump_version v1.5.742 patch
    [ "$status" -eq 0 ]
    [ "$output" = "v1.5.743" ]
}

@test "release: bump minor from v1.5.742 -> v1.6.0" {
    run release_bump_version v1.5.742 minor
    [ "$status" -eq 0 ]
    [ "$output" = "v1.6.0" ]
}

@test "release: bump major from v1.5.742 -> v2.0.0" {
    run release_bump_version v1.5.742 major
    [ "$status" -eq 0 ]
    [ "$output" = "v2.0.0" ]
}

@test "release: bump default is patch" {
    run release_bump_version v0.1.0
    [ "$status" -eq 0 ]
    [ "$output" = "v0.1.1" ]
}

@test "release: bump strips pre-release suffix from patch" {
    run release_bump_version v1.5.742-rc1 patch
    [ "$status" -eq 0 ]
    [ "$output" = "v1.5.743" ]
}

@test "release: latest_tag finds seed tag" {
    run release_latest_tag "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.5.742" ]
}

@test "release: commits_since is 0 when HEAD == tag" {
    run release_commits_since v1.5.742 "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "release: commits_since counts new commits" {
    echo "change" >> "$TEST_TEMP_DIR/README"
    git -C "$TEST_TEMP_DIR" commit -q -am "change"
    run release_commits_since v1.5.742 "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "release: tag_and_release is idempotent (no-op when no commits)" {
    run release_tag_and_release
    [ "$status" -eq 0 ]
    [[ "$output" == *"would skip"* ]] || [[ "$output" == *"nothing to release"* ]]
}

@test "release: dry-run shows next version without tagging" {
    echo "change" >> "$TEST_TEMP_DIR/README"
    git -C "$TEST_TEMP_DIR" commit -q -am "change"
    run release_tag_and_release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would tag v1.5.743"* ]]
    # Confirm no tag was actually created
    run git -C "$TEST_TEMP_DIR" tag -l v1.5.743
    [ -z "$output" ]
}

@test "release: dry-run with --bump minor shows v1.6.0" {
    echo "change" >> "$TEST_TEMP_DIR/README"
    git -C "$TEST_TEMP_DIR" commit -q -am "change"
    run release_tag_and_release --dry-run --bump minor
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.6.0"* ]]
}

@test "release: status shows latest tag and commit count" {
    run release_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.5.742"* ]]
    [[ "$output" == *"Commits since"* ]]
}

@test "release: main routes help" {
    run release_main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw release"* ]]
    [[ "$output" == *"tag-and-release"* ]]
}

@test "release: main rejects unknown subcommand" {
    run release_main bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown"* ]]
}

@test "release: main routes status" {
    run release_main status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Latest tag"* ]]
}

@test "release: main default subcommand is tag-and-release (no-op path)" {
    run release_main
    [ "$status" -eq 0 ]
    [[ "$output" == *"would skip"* ]] || [[ "$output" == *"nothing"* ]]
}

@test "release: tag_and_release creates tag when commits exist" {
    echo "change" >> "$TEST_TEMP_DIR/README"
    git -C "$TEST_TEMP_DIR" commit -q -am "change"
    # No remotes configured, gh won't be reached; tag creation + remote loop should still succeed
    run release_tag_and_release
    # Exit may be 0 (no remotes to fail on)
    # Verify tag created
    run git -C "$TEST_TEMP_DIR" tag -l v1.5.743
    [ "$output" = "v1.5.743" ]
}
