#!/usr/bin/env bats
# T-3848: v1.8.1 pushed master + tag atomically (T-3822) but never pushed the
# development branch carrying the VERSION-reconcile commit, so
# origin/bleeding-edge ended 1 commit BEHIND origin/master — the release-train
# invariant (dev branch is master's only writer, master never leads it) broken
# on the remote the moment the release finished.
#
# Fix: the checked-out dev branch rides in the SAME --atomic push, and the
# T-3819 pre-flight grades it on every remote too. Throwaway repos, file://.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/origin.git"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo 1.0.0 > "$REPO/VERSION"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "file://$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm c2
    git -C "$REPO" push -q origin bleeding-edge

    PREPUSH_LOG="$TEST_TEMP_DIR/prepush.log"
    cat > "$REPO/.git/hooks/pre-push" <<H
#!/bin/sh
echo "RUN \$1" >> "$PREPUSH_LOG"
while read -r lref lsha rref rsha; do echo "  \$rref" >> "$PREPUSH_LOG"; done
exit 0
H
    chmod +x "$REPO/.git/hooks/pre-push"

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_rsha() { git -C "$ORIGIN" rev-parse "$1" 2>/dev/null; }

@test "after a reconciling release, origin/bleeding-edge contains origin/master" {
    _release
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/VERSION")" = "1.0.1" ]
    [ "$(_rsha master)" = "$(git -C "$REPO" rev-parse HEAD)" ]
    git -C "$ORIGIN" merge-base --is-ancestor refs/heads/master refs/heads/bleeding-edge
    [ "$(_rsha bleeding-edge)" = "$(_rsha master)" ]
}

@test "dev branch, release branch and tag travel in ONE pre-push run" {
    _release
    [ "$status" -eq 0 ]
    [ "$(grep -c '^RUN ' "$PREPUSH_LOG")" -eq 1 ]
    grep -q '  refs/heads/master' "$PREPUSH_LOG"
    grep -q '  refs/heads/bleeding-edge' "$PREPUSH_LOG"
    grep -q '  refs/tags/v1.0.1' "$PREPUSH_LOG"
}

@test "remote dev branch holding a commit HEAD lacks -> refuse before VERSION or tag" {
    OTHER="$TEST_TEMP_DIR/other"
    git clone -q -b bleeding-edge "file://$ORIGIN" "$OTHER"
    git -C "$OTHER" -c user.email=o@o.o -c user.name=o commit -q --allow-empty -m foreign
    git -C "$OTHER" push -q origin bleeding-edge
    pre_head="$(git -C "$REPO" rev-parse HEAD)"
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "bleeding-edge" ]]
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$pre_head" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
    ! git -C "$REPO" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null || false
    ! git -C "$ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null || false
}

@test "releasing from the release branch itself pushes only that branch + tag" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" merge -q --ff-only bleeding-edge
    _release
    [ "$status" -eq 0 ]
    [ "$(grep -c '^RUN ' "$PREPUSH_LOG")" -eq 1 ]
    ! grep -q '  refs/heads/bleeding-edge' "$PREPUSH_LOG" || false
}

@test "detached HEAD: no dev branch to push, release still publishes" {
    git -C "$REPO" checkout -q --detach
    _release
    [ "$status" -eq 0 ]
    [ "$(_rsha master)" = "$(git -C "$REPO" rev-parse HEAD)" ]
}
