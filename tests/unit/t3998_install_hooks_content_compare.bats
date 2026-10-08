#!/usr/bin/env bats
# T-3998: `fw git install-hooks` short-circuited on the commit-msg `# VERSION=`
# marker alone. A hook whose CONTENT changed without a marker bump never
# deployed — T-3821's pre-push fix (do not stamp a tracked VERSION) sat
# undeployed in the framework repo and the old hook rewrote VERSION on every
# push. Content now decides; the marker is only reported.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks "$@"
}

@test "T-3998: a hook whose body changed (marker untouched) is restored without --force" {
    run _install
    [ "$status" -eq 0 ]
    cp "$PROJ/.git/hooks/pre-push" "$TEST_TMP/want"
    # The pre-T-3821 shape: same marker everywhere, different body.
    echo '# stale body line' >> "$PROJ/.git/hooks/pre-push"
    grep -q "^# VERSION=" "$PROJ/.git/hooks/commit-msg"
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hook content differs: pre-push"* ]]
    cmp -s "$TEST_TMP/want" "$PROJ/.git/hooks/pre-push"
}

@test "T-3998/control: identical hooks short-circuit and are not rewritten" {
    run _install
    [ "$status" -eq 0 ]
    touch -d '2001-01-01' "$PROJ/.git/hooks/commit-msg"
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"content identical"* ]]
    [ "$(stat -c %Y "$PROJ/.git/hooks/commit-msg")" -lt 1000000000 ]
}

@test "T-3998: a non-executable installed hook is redeployed" {
    run _install
    chmod -x "$PROJ/.git/hooks/post-commit"
    run _install
    [ "$status" -eq 0 ]
    [ -x "$PROJ/.git/hooks/post-commit" ]
}

@test "T-3998: no staging directory is left behind" {
    export TMPDIR="$TEST_TMP/t"
    mkdir -p "$TMPDIR"
    run _install
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}
