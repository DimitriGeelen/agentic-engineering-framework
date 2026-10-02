#!/usr/bin/env bats
# T-3740: the post-commit fabric advisories build the location->card map once.
# The old loop ran one grep per changed file per card; a re-vendor commit
# (1561 files x 506 cards, 832 T-1004) sat in post-commit for 10+ minutes.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    mkdir -p "$PROJ/.fabric/components" "$PROJ/src"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
    # diff-tree lists nothing for a root commit, so the commit under test is the second
    echo init > "$PROJ/README"
    git -C "$PROJ" add README
    git -C "$PROJ" commit -q -m "T-0001: init"
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_card() {  # _card <n> <location>
    printf 'id: c%s\nname: comp-%s\nlocation: %s\ndepended_by:\n  - target: x\n' "$1" "$1" "$2" \
        > "$PROJ/.fabric/components/c$1.yaml"
}

_install_and_run_post_commit() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    bash -n "$PROJ/.git/hooks/post-commit"
    cd "$PROJ"
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" timeout 60 bash .git/hooks/post-commit 2>&1
}

@test "normal commit: names the modified component and lists an unregistered new file" {
    _card 1 src/a.sh
    echo a > "$PROJ/src/a.sh"
    echo b > "$PROJ/src/b.sh"
    git -C "$PROJ" add -A
    git -C "$PROJ" commit -q -m "T-0001: seed"   # hooks not installed yet
    echo "$output" >/dev/null
    run _install_and_run_post_commit
    echo "$output" | tail -20
    [[ "$output" == *"FABRIC: 1 component(s) modified: comp-1"* ]]
    [[ "$output" == *"new file(s) without component cards: src/b.sh"* ]]
}

@test "re-vendor sized commit: 1500 files x 500 cards finishes in under 10 s with a summary line" {
    for i in $(seq 1 500); do _card "$i" "src/f$i.sh"; done
    for i in $(seq 1 1500); do echo "$i" > "$PROJ/src/f$i.sh"; done
    git -C "$PROJ" add -A
    git -C "$PROJ" commit -q -m "T-0001: big"    # hooks not installed yet
    start=$(date +%s)
    run _install_and_run_post_commit
    elapsed=$(( $(date +%s) - start ))
    echo "elapsed=${elapsed}s"
    [ "$elapsed" -lt 10 ]
    [[ "$output" == *"500 component(s) modified across"*"detail skipped above 200"* ]]
    [[ "$output" == *"1000 new file(s) without component cards (list skipped above 20)"* ]]
}
