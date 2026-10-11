#!/usr/bin/env bats
# T-3886 (GitHub #87): bare `fw upgrade` from a consumer auto-clones the framework.
# The clone used --depth=1, so the origin guard could not see the consumer's
# recorded version_sha and refused its own clone as foreign-source. The remedy
# then named the temp dir the EXIT trap deletes.
#
# Fixture: the upstream is the framework's working tree (via `git stash create`,
# so the code under test is what the child process runs) on top of committed
# history. The consumer pins an OLDER commit, which is what a behind consumer has.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3886-XXXXXX)"
    export FRAMEWORK_ROOT
    local g=(git -c user.name=t3886 -c user.email=t3886@example.invalid)
    # Runtime snapshot of the working tree (tracked files, incl. uncommitted edits
    # to lib/), so the child runs the code under test. Only the runtime dirs: a
    # full-history local clone of this repo takes minutes under file://.
    local wt snap="$TEST_TEMP_DIR/snap"
    wt="$(git -C "$FRAMEWORK_ROOT" stash create 2>/dev/null || true)"
    [ -n "$wt" ] || wt="HEAD"
    mkdir -p "$snap"
    git -C "$FRAMEWORK_ROOT" archive "$wt" bin lib agents policy web templates VERSION FRAMEWORK.md \
        | tar -x -C "$snap"
    # Three commits; the consumer pins the first (an older upstream commit).
    git init -q "$TEST_TEMP_DIR/src"
    cp -a "$snap/." "$TEST_TEMP_DIR/src/"
    "${g[@]}" -C "$TEST_TEMP_DIR/src" add -A
    "${g[@]}" -C "$TEST_TEMP_DIR/src" commit -q -m "release 1"
    PIN="$(git -C "$TEST_TEMP_DIR/src" rev-parse HEAD)"
    echo 2 > "$TEST_TEMP_DIR/src/.t3886-marker"
    "${g[@]}" -C "$TEST_TEMP_DIR/src" add -A
    "${g[@]}" -C "$TEST_TEMP_DIR/src" commit -q -m "release 2"
    echo 3 > "$TEST_TEMP_DIR/src/.t3886-marker"
    "${g[@]}" -C "$TEST_TEMP_DIR/src" add -A
    "${g[@]}" -C "$TEST_TEMP_DIR/src" commit -q -m "release 3"
    git clone -q --bare "$TEST_TEMP_DIR/src" "$TEST_TEMP_DIR/up.git"
    UPSTREAM="$TEST_TEMP_DIR/up.git"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Scrubbed-env run of the consumer's vendored bin/fw, as a fresh machine would
# (same shape as fresh_run in tests/fresh_machine_helper.bash, which we do not
# load because its setup/teardown would replace ours).
fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

# Consumer = vendored shallow copy of UPSTREAM + .framework.yaml pinning PIN.
make_behind_consumer() {
    local upstream="$1" proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"
    git clone -q --depth=1 "file://$upstream" "$proj/.agentic-framework"
    cat > "$proj/.framework.yaml" <<YAML
project_name: proj
version: 1.8.0
version_sha: $PIN
provider: claude
upstream_repo: file://$upstream
YAML
    echo "$proj"
}

@test "t3886: upstream fixture has several commits and the pin is an older ancestor" {
    run git -C "$UPSTREAM" rev-list --count HEAD
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
    git -C "$UPSTREAM" merge-base --is-ancestor "$PIN" HEAD
}

@test "t3886: bare consumer upgrade auto-clones with history and is NOT refused as foreign-source" {
    local proj
    proj="$(make_behind_consumer "$UPSTREAM")"

    run fresh_run "$proj" upgrade "$proj"
    [[ "$output" == *"Bare-from-consumer detected"* ]]
    [[ "$output" != *"REFUSED"* ]]
    [[ "$output" != *"foreign-source"* ]]
    [ "$status" -eq 0 ]
}

@test "t3886: when the auto-clone is shallow and refuses, the remedy never names the temp dir" {
    # Shallow upstream: the auto-clone inherits the truncation, so the guard refuses.
    git clone -q --bare --depth=1 "file://$UPSTREAM" "$TEST_TEMP_DIR/shallow.git"
    local proj
    proj="$(make_behind_consumer "$TEST_TEMP_DIR/shallow.git")"

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    # Names the recorded SHA and a runnable alternative.
    [[ "$output" == *"${PIN:0:12}"* ]]
    [[ "$output" == *"git clone"* ]]
    [[ "$output" == *"framework-full/bin/fw upgrade"* ]]
    # The REFUSED block (reason + remedy) never names the temp dir (deleted on
    # exit) and never offers the unshallow hint on it. The header's "Framework:"
    # line above it is informational (what actually ran), so it is out of scope.
    local refusal="${output#*REFUSED}"
    [[ "$refusal" != *"fw-upstream-"* ]]
    [[ "$refusal" != *"fetch --unshallow"* ]]
}
