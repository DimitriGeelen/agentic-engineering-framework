#!/usr/bin/env bats
# T-4268: a first `fw git install-hooks` printed "Hook content differs: <all
# five> ... — reinstalling" (an absent hook was folded into "differs"), and the
# "Installed:" banner listed a fixed four hooks whatever was actually written.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks "$@"
}

@test "T-4268: a first install reports hooks as absent, not as differing" {
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" != *"content differs"* ]]
    [[ "$output" == *"Hooks not present: commit-msg pre-commit pre-merge-commit post-commit pre-push — installing"* ]]
    [[ "$output" == *"/pre-merge-commit (parked-branch merge guard)"* ]]
    [ "$(grep -c '^  - .*/hooks/' <<<"$output")" -eq 5 ]
}

@test "T-4268: a partial reinstall separates absent from differing and lists only what it wrote" {
    run _install
    [ "$status" -eq 0 ]
    rm "$PROJ/.git/hooks/post-commit"
    sed -i '/^# >>> agentic-framework hook/a # stale body line' "$PROJ/.git/hooks/pre-push"
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hooks not present: post-commit — installing"* ]]
    [[ "$output" == *"Hook content differs: pre-push ("* ]]
    [ "$(grep -c '^  - .*/hooks/' <<<"$output")" -eq 2 ]
    grep -q '/hooks/post-commit (bypass detection)' <<<"$output"
    grep -q '/hooks/pre-push (audit before push)' <<<"$output"
    ! grep -q '/hooks/commit-msg (' <<<"$output" || false
}

@test "T-4268/control: --force rewrites and lists all five, with no absent/differs line" {
    run _install
    run _install --force
    [ "$status" -eq 0 ]
    [[ "$output" != *"content differs"* ]]
    [[ "$output" != *"not present"* ]]
    [ "$(grep -c '^  - .*/hooks/' <<<"$output")" -eq 5 ]
}
