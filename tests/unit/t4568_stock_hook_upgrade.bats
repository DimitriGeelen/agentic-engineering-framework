#!/usr/bin/env bats
# T-4568: a fresh v1.8.14 consumer upgraded to bleeding-edge printed "WARN Git
# hook installation failed": install-hooks REFUSED commit-msg and pre-push,
# because the lines the v1.8.14 template has and the current one lacks were
# kept as "project lines" and did not parse after the block. Nobody had edited
# those hooks. A stock old hook must upgrade cleanly; lines a project appended
# to it, or edits inside it, must still be protected.
#
# Fixtures are the v1.8.14 templates themselves, read from that release's commit
# (an ancestor of every later branch, so no tag is needed).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

V1814=2328ae76b739b637532c74077c7c64d4ce35ced6
NAMES="commit-msg pre-commit pre-merge-commit post-commit pre-push"
END_LINE='# <<< agentic-framework hook <<<'

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
    # The five stock v1.8.14 hooks, written exactly as its install-hooks wrote them.
    git -C "$FRAMEWORK_ROOT" show "$V1814:agents/git/lib/hooks.sh" > "$TEST_TMP/old-hooks.sh"
    awk -v d="$TEST_TMP" -v names="$NAMES" '
        BEGIN { split(names, nm, " ") }
        /<< '"'"'HOOK_EOF'"'"'$/ { on = 1; n++; next }
        /^HOOK_EOF$/ { on = 0 } on { print > (d "/stock." nm[n]) }' "$TEST_TMP/old-hooks.sh"
    for n in $NAMES; do
        cp "$TEST_TMP/stock.$n" "$HOOKS/$n"
        chmod +x "$HOOKS/$n"
    done
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks "$@"
}

@test "fixture: the v1.8.14 commit-msg is the 1.17 template the cloud run upgraded" {
    grep -qx '# VERSION=1.17' "$HOOKS/commit-msg"
    grep -q 'Agentic Engineering Framework' "$HOOKS/pre-push"
}

@test "stock v1.8.14 hooks: install-hooks succeeds and refuses nothing" {
    run _install
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q 'REFUSED' || false
    ! echo "$output" | grep -q 'not installed' || false
}

@test "stock v1.8.14 hooks: no old template line survives outside the block" {
    _install
    for n in $NAMES; do
        # Everything after the block end is what was carried over: nothing.
        after=$(awk -v e="$END_LINE" 'f { print } $0 == e { f = 1 }' "$HOOKS/$n")
        [ -z "$after" ] || { echo "$n carried: $after"; false; }
        bash -n "$HOOKS/$n"
    done
    grep -q "^# VERSION=$(sed -n 's/^COMMIT_MSG_HOOK_VERSION="\(.*\)"/\1/p' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh")$" "$HOOKS/commit-msg"
}

@test "project line appended to a stock hook is kept active, once, and the old template is not" {
    echo 'echo PROJECT-GATE-RAN' >> "$HOOKS/commit-msg"
    run _install
    [ "$status" -eq 0 ]
    [ "$(grep -cx 'echo PROJECT-GATE-RAN' "$HOOKS/commit-msg")" -eq 1 ]
    after=$(awk -v e="$END_LINE" 'f && !/^#/ { print } $0 == e { f = 1 }' "$HOOKS/commit-msg")
    [ "$after" = "echo PROJECT-GATE-RAN" ]
    [ -f "$HOOKS/commit-msg.pre-fw-block" ]
}

@test "an edit INSIDE a stock hook is not mistaken for stock: never silently dropped" {
    # Not a known template any more, so the digest match must not fire.
    sed -i 's/^COMMIT_MSG_FILE="\$1"$/COMMIT_MSG_FILE="$1"; echo PROJECT-EDIT/' "$HOOKS/commit-msg"
    grep -q 'PROJECT-EDIT' "$HOOKS/commit-msg"
    run _install
    # Either merged with the edited line still active, or refused and left as it was.
    grep -v '^[[:space:]]*#' "$HOOKS/commit-msg" | grep -q 'PROJECT-EDIT'
}

@test "every committed digest names a body this framework's history shipped (format)" {
    grep -v '^#' "$FRAMEWORK_ROOT/agents/git/lib/stock-hook-digests.txt" > "$TEST_TMP/d"
    [ -s "$TEST_TMP/d" ]
    ! grep -vqE '^[0-9]+ [0-9a-f]{64}$' "$TEST_TMP/d" || false
    for n in $NAMES; do
        d="$(wc -l < "$TEST_TMP/stock.$n" | tr -d ' ') $(sha256sum < "$TEST_TMP/stock.$n" | cut -d' ' -f1)"
        grep -qx "$d" "$TEST_TMP/d"
    done
}
