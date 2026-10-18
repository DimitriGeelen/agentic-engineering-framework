#!/usr/bin/env bats
# T-4340: lib/release.sh runs the GitHub issue leg (lifecycle stages 8-9) for the release range.
#   - --dry-run lists what would be posted and writes nothing (no tag, no ledger, no GitHub write);
#   - a real release runs the leg after publish, and a GitHub failure never fails the release:
#     it is reported and recorded in .context/issues/release-pending.jsonl for retry.

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
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    mkdir -p "$REPO/.tasks/completed"
    printf -- '---\nid: T-100\nstatus: work-completed\ngithub_issue: 7\n---\n# T-100\n' \
        > "$REPO/.tasks/completed/T-100-fix.md"
    echo dev > "$REPO/f2"; git -C "$REPO" add f2 .tasks; git -C "$REPO" commit -qm "T-100: fix"

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    GH_LOG="$TEST_TEMP_DIR/gh.log"
    # gh release works; every `gh issue …` and `gh api …` fails, as a GitHub outage would.
    cat > "$STUB_BIN/gh" <<EOS
#!/bin/sh
echo "\$*" >> "$GH_LOG"
[ "\$1" = release ] && [ "\$2" = create ] && exit 0
exit 1
EOS
    chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_has_tag() { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }

@test "dry-run lists the Released post for T-100's issue and changes nothing" {
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would post released on #7"* ]]
    [[ "$output" == *"dry-run: nothing posted or closed"* ]]
    ! _has_tag "$REPO" v1.0.1
    ! _has_tag "$ORIGIN" v1.0.1
    [ ! -e "$REPO/.context/issues" ]
    [ ! -s "$GH_LOG" ] || ! grep -q "^issue" "$GH_LOG"
}

@test "a real release runs the issue leg after publish; GitHub failure does not fail it" {
    _release
    [ "$status" -eq 0 ]
    _has_tag "$ORIGIN" v1.0.1
    [[ "$output" == *"GitHub issues (stages 8-9)"* ]]
    [[ "$output" == *"WARN"* ]]
    grep -q '"issue": 7' "$REPO/.context/issues/release-pending.jsonl"
    grep -q '"stage": "released"' "$REPO/.context/issues/release-pending.jsonl"
}

@test "a task without github_issue is never touched by the issue leg" {
    sed -i '/github_issue/d' "$REPO/.tasks/completed/T-100-fix.md"
    git -C "$REPO" commit -qam "T-100: drop the issue link"
    _release
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/.context/issues/release-pending.jsonl" ]
    ! grep -q "^issue" "$GH_LOG" 2>/dev/null
}
