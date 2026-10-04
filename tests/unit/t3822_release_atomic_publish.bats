#!/usr/bin/env bats
# T-3822: v1.8.0 attempt 3 pushed `master`, then pushed the tag through a
# second full pre-push audit minutes later. Consumers ran `fw upgrade` from
# master in that window and installed a "1.8.0" that no tag named yet.
#
# Fix: ONE `git push --atomic <remote> <branch> <tag>` per remote. Pinned here:
#   - a remote that refuses only the tag ends with NEITHER ref (atomic);
#   - the pre-push hook runs ONCE per remote per release, with both refs;
#   - multi-remote partial success is reported, not rolled back;
#   - control: a healthy remote receives both refs in the same push.

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
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm c2

    # Count pre-push invocations and record the refs each one carried.
    PREPUSH_LOG="$TEST_TEMP_DIR/prepush.log"
    cat > "$REPO/.git/hooks/pre-push" <<H
#!/bin/sh
echo "RUN \$1" >> "$PREPUSH_LOG"
while read -r lref lsha rref rsha; do echo "  \$rref" >> "$PREPUSH_LOG"; done
exit 0
H
    chmod +x "$REPO/.git/hooks/pre-push"

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    GH_MARKER="$TEST_TEMP_DIR/gh-release-created"
    cat > "$STUB_BIN/gh" <<EOS
#!/bin/sh
[ "\$1" = release ] && [ "\$2" = create ] && echo "\$3" > "$GH_MARKER"
exit 0
EOS
    chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_sha()          { git -C "$REPO" rev-parse "$1" 2>/dev/null; }
_rsha()         { git -C "$1" rev-parse "$2" 2>/dev/null; }
_r_no_tag()     { ! git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }
_r_has_tag()    { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }
_gh_not_called(){ [ ! -f "$GH_MARKER" ]; }

_reject_tags_on() {
    cat > "$1/hooks/update" <<'H'
#!/bin/sh
case "$1" in refs/tags/*) echo "remote: tag refused" >&2; exit 1 ;; esac
exit 0
H
    chmod +x "$1/hooks/update"
}

@test "CONTROL: both refs land on origin, GitHub Release created" {
    _release
    [ "$status" -eq 0 ]
    [ "$(_rsha "$ORIGIN" master)" = "$(_sha HEAD)" ]
    _r_has_tag "$ORIGIN" v1.0.1
    [ "$(cat "$GH_MARKER")" = "v1.0.1" ]
}

@test "the pre-push hook runs ONCE for the release, carrying branch and tag together" {
    _release
    [ "$status" -eq 0 ]
    [ "$(grep -c '^RUN ' "$PREPUSH_LOG")" -eq 1 ]
    grep -q '  refs/heads/master' "$PREPUSH_LOG"
    grep -q '  refs/tags/v1.0.1' "$PREPUSH_LOG"
}

@test "the push uses --atomic (source pin)" {
    grep -q 'git -C "$root" push --atomic "$remote" "${refspecs\[@\]}"' "$LIB"
}

@test "remote refuses only the tag -> NEITHER ref lands (no master-without-tag window)" {
    _reject_tags_on "$ORIGIN"
    before="$(_rsha "$ORIGIN" master)"
    _release
    [ "$status" -eq 1 ]
    [ "$(_rsha "$ORIGIN" master)" = "$before" ]
    _r_no_tag "$ORIGIN" v1.0.1
    _gh_not_called
}

@test "remote refuses the tag -> full rollback: HEAD, VERSION, master, tag" {
    pre_head="$(_sha HEAD)"; pre_master="$(_sha master)"
    _reject_tags_on "$ORIGIN"
    _release
    [ "$(_sha HEAD)" = "$pre_head" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
    [ "$(_sha master)" = "$pre_master" ]
    [[ "$output" =~ "reached no remote" ]]
}

@test "two remotes, one refuses: release published on the other, failure reported, nothing retracted" {
    MIRROR="$TEST_TEMP_DIR/mirror.git"
    git init -q --bare -b master "$MIRROR"
    git -C "$REPO" push -q "$MIRROR" master v1.0.0
    git -C "$REPO" remote add mirror "$MIRROR"
    _reject_tags_on "$MIRROR"
    _release
    [ "$status" -eq 1 ]
    [ "$(_rsha "$ORIGIN" master)" = "$(_sha HEAD)" ]
    _r_has_tag "$ORIGIN" v1.0.1
    _r_no_tag "$MIRROR" v1.0.1
    [ "$(_rsha "$MIRROR" master)" != "$(_sha HEAD)" ]
    [[ "$output" =~ "neither ref landed there" ]]
}

@test "no local release branch: the tag alone is pushed, still in one push" {
    git -C "$REPO" branch -q -D master
    _release
    [ "$status" -eq 0 ]
    _r_has_tag "$ORIGIN" v1.0.1
    [ "$(grep -c '^RUN ' "$PREPUSH_LOG")" -eq 1 ]
}

@test "local master already at HEAD but origin behind: the branch is still published" {
    # A local-only fast-forward from an earlier, half-finished attempt.
    echo 1.0.1 > "$REPO/VERSION"; git -C "$REPO" commit -qam "pre-reconciled"
    git -C "$REPO" branch -f master HEAD
    _release
    [ "$status" -eq 0 ]
    [ "$(_rsha "$ORIGIN" master)" = "$(_sha HEAD)" ]
    _r_has_tag "$ORIGIN" v1.0.1
}
