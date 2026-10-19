#!/usr/bin/env bats
# T-4431: vX.Y.Z-be.N bleeding-edge pre-release tags are never "the latest
# release". Fixture tags v1.8.12, v1.8.13 and v1.8.14-be.1 (newest, nearest):
# every lookup must answer v1.8.13 and the next version must be 1.8.14.
# Temp repos only — nothing here tags or pushes the framework repo.

ROOT="${BATS_TEST_DIRNAME}/../.."

setup() {
    TMP="$(mktemp -d)"
    REPO="$TMP/repo"
    mkdir -p "$REPO/bin"
    cp "$ROOT/bin/fw" "$REPO/bin/fw"
    git -C "$REPO" init -q -b bleeding-edge
    git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
    git -C "$REPO" add -A; git -C "$REPO" commit -qm base; git -C "$REPO" tag -a v1.8.12 -m r
    c a; git -C "$REPO" tag -a v1.8.13 -m r
    c b; git -C "$REPO" tag -a v1.8.14-be.1 -m be
    c d
    export PROJECT_ROOT="$REPO"
    unset FW_DEV_BRANCH FW_RELEASE_BRANCH FW_RELEASE_TAG_PATTERN
}
teardown() { rm -rf "$TMP"; }

c() { echo "$1" >> "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm "$1"; }
rel() { ( cd "$REPO"; source "$ROOT/lib/release.sh"; "$@" ); }

@test "release_latest_tag skips the -be tag and the patch bump gives 1.8.14" {
    [ "$(rel release_latest_tag "$REPO")" = "v1.8.13" ]
    [ "$(rel release_bump_version "$(rel release_latest_tag "$REPO")" patch)" = "v1.8.14" ]
    # control: plain describe really does see the -be tag (the bug's precondition)
    [ "$(git -C "$REPO" describe --tags --abbrev=0)" = "v1.8.14-be.1" ]
}

@test "release_tags_latest with no pattern (consumer form) also skips -be" {
    [ "$(rel release_tags_latest "$REPO" "")" = "v1.8.13" ]
}

@test "release_version_tag_parity: VERSION 1.8.13 is ok, not behind a -be tag" {
    echo 1.8.13 > "$REPO/VERSION"
    [ "$(rel release_version_tag_parity "$REPO")" = "ok 1.8.13 1.8.13" ]
}

@test "bin/fw _derive_version reads v1.8.13+N, never the -be tag" {
    got="$(bash -c 'source /dev/stdin; _derive_version' \
        < <(sed -n '/^_derive_version() {/,/^}/p' "$REPO/bin/fw" | sed "s#\${BASH_SOURCE\[0\]}#$REPO/bin/fw#"))"
    [[ "$got" == 1.8.13+2.g* ]]
}

@test "fw version sync tag floor ignores the -be tag" {
    run bash -c 'RED= GREEN= YELLOW= CYAN= BOLD= NC=; FRAMEWORK_ROOT="$1"; PROJECT_ROOT="$1"; FW_VERSION=1.8.13
        cd "$1"; echo 1.8.13 > VERSION; source "$2/lib/version.sh"; do_version_sync --dry-run' _ "$REPO" "$ROOT"
    [[ "$output" != *REFUSING* ]]
    [ "$status" -eq 0 ]
}

@test "fw version check names v1.8.13 as the latest tag" {
    run bash -c 'RED= GREEN= YELLOW= CYAN= BOLD= NC=; FRAMEWORK_ROOT="$1"; PROJECT_ROOT="$1"; FW_VERSION=1.8.13
        cd "$1"; source "$2/lib/version.sh"; do_version_check' _ "$REPO" "$ROOT"
    [[ "$output" == *"Latest tag:"*"v1.8.13"* ]]
    [[ "$output" != *"be.1"* ]]
}

@test "be-tag on bleeding-edge creates annotated v1.8.14-be.2, then be.3" {
    run rel release_be_tag
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" cat-file -t v1.8.14-be.2)" = "tag" ]
    [ "$(git -C "$REPO" rev-list -n1 v1.8.14-be.2)" = "$(git -C "$REPO" rev-parse HEAD)" ]
    # same HEAD again: idempotent, no new tag
    run rel release_be_tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"already tagged v1.8.14-be.2"* ]]
    c e
    run rel release_be_tag
    [ "$status" -eq 0 ]
    git -C "$REPO" rev-parse -q --verify refs/tags/v1.8.14-be.3 >/dev/null
    # the new -be tags still do not move the latest release
    [ "$(rel release_latest_tag "$REPO")" = "v1.8.13" ]
}

@test "be-tag refuses on master and on a detached HEAD, creating nothing" {
    git -C "$REPO" checkout -q -b master
    run rel release_be_tag
    [ "$status" -eq 1 ]
    [[ "$output" == *"not 'bleeding-edge'"* ]]
    git -C "$REPO" checkout -q --detach
    run rel release_be_tag
    [ "$status" -eq 1 ]
    [[ "$output" == *"detached HEAD"* ]]
    [ "$(git -C "$REPO" tag -l '*-be.*' | wc -l)" -eq 1 ]
}

@test "be-tag refuses a version not above the latest release; dry-run tags nothing" {
    run rel release_be_tag --version 1.8.13
    [ "$status" -eq 1 ]
    run rel release_be_tag --version 1.9.0 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would tag: v1.9.0-be.1"* ]]
    [ "$(git -C "$REPO" tag -l '*-be.*' | wc -l)" -eq 1 ]
}

@test "fw release be-tag is routed by release_main" {
    run rel release_main be-tag --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would tag: v1.8.14-be.2"* ]]
}

@test "every describe --tags in lib/, bin/fw, agents/ excludes -be tags" {
    bad="$(grep -rnE 'describe[^|;]*--tags' "$ROOT/lib" "$ROOT/bin/fw" "$ROOT/agents" \
        --include='*.sh' --include='*.py' --include=fw 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
        | grep -v "release-tags.sh" | grep -v -- "--exclude '\*-be\.\*'" || true)"
    [ -z "$bad" ] || { echo "$bad"; false; }
}
