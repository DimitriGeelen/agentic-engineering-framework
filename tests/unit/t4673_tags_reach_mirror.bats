#!/usr/bin/env bats
# T-4673: release tags must reach every consumer-facing remote, github included.
# v1.8.15-be.4 was pushed to origin only (be-tag --push), and `fw mirror status`
# said "github: in sync" because it compared the default-branch head only.
# Two bare remotes in a temp dir — nothing here pushes the framework repo.

ROOT="${BATS_TEST_DIRNAME}/../.."

setup() {
    TMP="$(mktemp -d)"
    export NO_COLOR=1
    REPO="$TMP/work"
    git init -q --bare -b master "$TMP/origin.git"
    git init -q --bare -b master "$TMP/github.git"
    git init -q -b master "$REPO"
    git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
    c base; git -C "$REPO" tag -a v1.8.13 -m r
    git -C "$REPO" remote add origin "$TMP/origin.git"
    git -C "$REPO" remote add github "$TMP/github.git"
    git -C "$REPO" push -q origin master refs/tags/v1.8.13
    git -C "$REPO" push -q github master refs/tags/v1.8.13
    git -C "$REPO" checkout -q -b bleeding-edge
    c work
    export PROJECT_ROOT="$REPO"
    unset FW_DEV_BRANCH FW_RELEASE_BRANCH
}
teardown() { rm -rf "$TMP"; }

c() { echo "$1" >> "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm "$1"; }
rel() { ( cd "$REPO"; source "$ROOT/lib/release.sh"; "$@" ); }
mir() { ( cd "$REPO"; source "$ROOT/lib/mirror.sh"; "$@" ); }
has_tag() { git ls-remote --tags "$1" "refs/tags/$2" | grep -q "refs/tags/$2$"; }

@test "be-tag --push puts the tag on github as well as origin" {
    run rel release_be_tag --push
    [ "$status" -eq 0 ]
    has_tag "$TMP/origin.git" v1.8.14-be.1
    has_tag "$TMP/github.git" v1.8.14-be.1
}

@test "be-tag --push skips a no_push remote and still verifies the rest" {
    git -C "$REPO" remote set-url --push github no_push
    run rel release_be_tag --push
    [ "$status" -eq 0 ]
    has_tag "$TMP/origin.git" v1.8.14-be.1
}

@test "be-tag --push fails loudly, naming the remote, when github refuses the tag" {
    printf '#!/bin/sh\necho refused >&2\nexit 1\n' > "$TMP/github.git/hooks/pre-receive"
    chmod +x "$TMP/github.git/hooks/pre-receive"
    run rel release_be_tag --push
    [ "$status" -ne 0 ]
    [[ "$output" == *"github"* ]]
    [[ "$output" == *"v1.8.14-be.1"* ]]
    has_tag "$TMP/origin.git" v1.8.14-be.1
    ! has_tag "$TMP/github.git" v1.8.14-be.1 || false
}

@test "release_tag_verify_remotes names every remote missing the tag" {
    git -C "$REPO" tag -a v1.8.14 -m r
    git -C "$REPO" push -q origin refs/tags/v1.8.14
    run rel release_tag_verify_remotes "$REPO" v1.8.14
    [ "$status" -ne 0 ]
    [[ "$output" == *"github"* ]]
    [[ "$output" != *"origin: missing"* ]]
    git -C "$REPO" push -q github refs/tags/v1.8.14
    run rel release_tag_verify_remotes "$REPO" v1.8.14
    [ "$status" -eq 0 ]
}

@test "tag-and-release verifies the tag on every remote after publishing" {
    grep -q 'release_tag_verify_remotes "\$root" "\$next"' "$ROOT/lib/release.sh"
}

@test "mirror status reports a v* tag on origin that github lacks (branch in sync)" {
    git -C "$REPO" tag -a v1.8.14-be.1 -m be
    git -C "$REPO" push -q origin refs/tags/v1.8.14-be.1
    run mir mirror_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"github: in sync"* ]]
    [[ "$output" == *"github: 1 release tag(s) missing"*"v1.8.14-be.1"* ]]
}

@test "mirror status says tags are in sync when they are" {
    run mir mirror_status
    [[ "$output" == *"github: release tags in sync"* ]]
    [[ "$output" != *"missing"* ]]
}

@test "mirror sync pushes missing tags (fetching them from origin) as new refs" {
    git -C "$REPO" tag -a v1.8.14-be.1 -m be
    git -C "$REPO" push -q origin refs/tags/v1.8.14-be.1
    git -C "$REPO" tag -d v1.8.14-be.1 >/dev/null   # local lacks it: sync must fetch it
    run mir mirror_sync
    [ "$status" -eq 0 ]
    has_tag "$TMP/github.git" v1.8.14-be.1
    [ "$(git ls-remote "$TMP/github.git" refs/tags/v1.8.14-be.1 | cut -f1)" = \
      "$(git ls-remote "$TMP/origin.git" refs/tags/v1.8.14-be.1 | cut -f1)" ]
    grep -q "github:tags" "$REPO/.context/working/.mirror-sync.log"
}

@test "mirror sync never moves a tag that differs on the mirror" {
    git -C "$REPO" tag -a v1.8.12 -m origin-version
    git -C "$REPO" push -q origin refs/tags/v1.8.12
    git -C "$REPO" tag -d v1.8.12 >/dev/null
    git -C "$REPO" tag -a v1.8.12 -m github-version master
    git -C "$REPO" push -q github refs/tags/v1.8.12
    before="$(git ls-remote "$TMP/github.git" refs/tags/v1.8.12 | cut -f1)"
    run mir mirror_sync
    [ "$(git ls-remote "$TMP/github.git" refs/tags/v1.8.12 | cut -f1)" = "$before" ]
    [[ "$output" == *"v1.8.12"*"differs"* ]]
    run mir mirror_status
    [[ "$output" == *"differ"*"v1.8.12"* ]]
}

@test "mirror sync --dry-run reports the missing tag without pushing it" {
    git -C "$REPO" tag -a v1.8.14-be.1 -m be
    git -C "$REPO" push -q origin refs/tags/v1.8.14-be.1
    run mir mirror_sync --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would push"*"v1.8.14-be.1"* ]]
    ! has_tag "$TMP/github.git" v1.8.14-be.1 || false
}
