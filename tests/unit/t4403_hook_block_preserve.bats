#!/usr/bin/env bats
# T-4403 (also T-3926): `fw upgrade` (lib/upgrade.sh step 4) runs
# `git.sh install-hooks`, which compared and replaced WHOLE hook files, so a
# line a consumer added to .git/hooks/pre-commit was erased on every upgrade
# (832, msg 62736fc8). The framework content now lives between markers; only
# that block is compared and replaced, and everything outside it is kept.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

BEGIN_RE='^# >>> agentic-framework hook'
END_LINE='# <<< agentic-framework hook <<<'

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
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

@test "T-4403: every framework hook is installed as one marked block and parses" {
    run _install
    [ "$status" -eq 0 ]
    for n in commit-msg pre-commit pre-merge-commit post-commit pre-push; do
        [ "$(grep -c "$BEGIN_RE" "$HOOKS/$n")" -eq 1 ]
        [ "$(grep -cxF "$END_LINE" "$HOOKS/$n")" -eq 1 ]
        bash -n "$HOOKS/$n"
    done
    grep -q '^# VERSION=' "$HOOKS/commit-msg"
}

@test "T-4403: a consumer line below the block survives a re-install and --force" {
    run _install
    echo 'echo consumer-tail-line' >> "$HOOKS/pre-commit"
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"content identical"* ]]
    grep -qx 'echo consumer-tail-line' "$HOOKS/pre-commit"
    run _install --force
    [ "$status" -eq 0 ]
    grep -qx 'echo consumer-tail-line' "$HOOKS/pre-commit"
    [ "$(grep -c "$BEGIN_RE" "$HOOKS/pre-commit")" -eq 1 ]
}

@test "T-4403: a consumer line above the block survives a block redeploy" {
    run _install
    sed -i '1a # consumer-head-line' "$HOOKS/pre-push"
    # make the block stale so it really is rewritten
    sed -i "/$BEGIN_RE/a # stale line inside the block" "$HOOKS/pre-push"
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hook content differs: pre-push"* ]]
    grep -qx '# consumer-head-line' "$HOOKS/pre-push"
    ! grep -q 'stale line inside the block' "$HOOKS/pre-push" || false
}

@test "T-4403: an unmarked old framework hook with consumer lines migrates without losing them" {
    # The pre-T-4403 shape: the raw template written whole, plus a consumer line.
    run _install
    awk -v b="$BEGIN_RE" -v e="$END_LINE" '
        $0 ~ b {inb=1; next}
        $0 == e {inb=0; next}
        inb && ($0 == "(" || $0 == ") || exit $?") {next}
        {print}' "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    ! grep -q "$BEGIN_RE" "$TEST_TMP/raw" || false
    echo 'echo consumer-migrated-line' >> "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"
    run _install
    [ "$status" -eq 0 ]
    # Kept ACTIVE (T-4515, G-122): commenting them out disabled 832's gates.
    grep -qx 'echo consumer-migrated-line' "$HOOKS/pre-commit"
    ! grep -qx '# echo consumer-migrated-line' "$HOOKS/pre-commit" || false
    [[ "$output" == *"still active"* ]]
    [ "$(grep -c "$BEGIN_RE" "$HOOKS/pre-commit")" -eq 1 ]
    [ -f "$HOOKS/pre-commit.pre-fw-block" ]
    bash -n "$HOOKS/pre-commit"
    # The template lines were not duplicated outside the block.
    [ "$(grep -c 'Installed by: ./agents/git/git.sh install-hooks' "$HOOKS/pre-commit")" -eq 1 ]
    # A second install neither re-migrates nor duplicates anything.
    cp "$HOOKS/pre-commit" "$TEST_TMP/after1"
    run _install
    [ "$status" -eq 0 ]
    cmp -s "$TEST_TMP/after1" "$HOOKS/pre-commit"
}

@test "T-4403: an unmarked hook identical to the template migrates with no backup and no kept lines" {
    run _install
    awk -v b="$BEGIN_RE" -v e="$END_LINE" '
        $0 ~ b {inb=1; next}
        $0 == e {inb=0; next}
        inb && ($0 == "(" || $0 == ") || exit $?") {next}
        {print}' "$HOOKS/pre-push" > "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-push"
    run _install
    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS/pre-push.pre-fw-block" ]
    ! grep -q 'T-4403: kept from the previous' "$HOOKS/pre-push" || false
}

@test "T-4403: a wholly consumer-owned shell hook keeps its whole body" {
    printf '#!/bin/sh\necho consumer-own-a\necho consumer-own-b\n' > "$HOOKS/post-commit"
    chmod +x "$HOOKS/post-commit"
    run _install
    [ "$status" -eq 0 ]
    grep -qx 'echo consumer-own-a' "$HOOKS/post-commit"
    grep -qx 'echo consumer-own-b' "$HOOKS/post-commit"
    [ "$(grep -c "$BEGIN_RE" "$HOOKS/post-commit")" -eq 1 ]
    [ -f "$HOOKS/post-commit.pre-fw-block" ]
}

@test "T-4403: the marked block still enforces, and a consumer line after it runs" {
    run _install
    echo 'echo CONSUMER-RAN >&2' >> "$HOOKS/commit-msg"
    echo "no task reference here" > "$TEST_TMP/msg"
    run bash "$HOOKS/commit-msg" "$TEST_TMP/msg"
    [ "$status" -ne 0 ]
    [[ "$output" != *"CONSUMER-RAN"* ]]
    echo "T-0001: with a reference" > "$TEST_TMP/msg"
    cd "$PROJ"
    run bash "$HOOKS/commit-msg" "$TEST_TMP/msg"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONSUMER-RAN"* ]]
}
