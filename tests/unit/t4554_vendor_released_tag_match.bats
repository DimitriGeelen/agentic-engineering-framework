#!/usr/bin/env bats
#
# T-4554 — fw upgrade/vendor pre-flight called a vendored file "edited locally"
# when its bytes matched a RELEASED framework version but not the vendor stamp
# (the installed-files record). ring20 copied two files from the v1.8.12 tag
# during the hotfix; the stamp still held pre-hotfix hashes; pre-flight refused.
#
# FIXTURES ONLY: a tiny git source at v1.0.0, vendored; a hotfix tagged v1.0.1
# that the consumer copies by hand (stamp stays at v1.0.0); then the source
# moves on past both tags. The vendor runs again.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMP="$(mktemp -d)"
    SRC="$TMP/src"
    PROJ="$TMP/proj"
    AF="$PROJ/.agentic-framework"
    GIT=(git -C "$SRC" -c user.email=t@example.invalid -c user.name=t)

    mkdir -p "$SRC/bin" "$SRC/lib"
    printf '#!/bin/sh\necho stub\n' > "$SRC/bin/fw"; chmod +x "$SRC/bin/fw"
    echo "# framework" > "$SRC/FRAMEWORK.md"
    echo "a v1" > "$SRC/lib/a.sh"
    echo "b v1" > "$SRC/lib/b.sh"
    git -C "$SRC" init -q
    "${GIT[@]}" add -A
    "${GIT[@]}" commit -qm v1
    "${GIT[@]}" tag v1.0.0

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    _vendor >/dev/null
    [ -f "$AF/.fw-vendor-stamp.json" ]

    # Hotfix release; the consumer copies the file straight from the tag.
    echo "a hotfix" > "$SRC/lib/a.sh"
    "${GIT[@]}" commit -qam hotfix
    "${GIT[@]}" tag v1.0.1
    git -C "$SRC" show v1.0.1:lib/a.sh > "$AF/lib/a.sh"

    # Upstream moves on past both releases.
    echo "a v2" > "$SRC/lib/a.sh"
    echo "b v2" > "$SRC/lib/b.sh"
    "${GIT[@]}" commit -qam v2
}

teardown() { rm -rf "$TMP"; }

_vendor() {
    ( cd "$PROJ" && env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" "$@" 2>&1 )
}

@test "stale stamp + file equal to a release tag: framework-owned, vendor proceeds and says so" {
    run _vendor
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "RELEASED  lib/a.sh  — matches v1.0.1"
    [[ "$output" != *'LOCAL  lib/a.sh'* ]]
    [[ "$output" != *'REFUSED'* ]]
    grep -qx "a v2" "$AF/lib/a.sh"
}

@test "genuinely edited file is still flagged and the vendor refuses" {
    echo "b v1 + consumer edit" > "$AF/lib/b.sh"
    run _vendor
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "LOCAL  lib/b.sh  — edited locally — would be OVERWRITTEN"
    echo "$output" | grep -q "RELEASED  lib/a.sh  — matches v1.0.1"
    grep -qx "b v1 + consumer edit" "$AF/lib/b.sh"
}

@test "no release tags in the source: tag-equal check degrades to the old verdict" {
    git -C "$SRC" tag -d v1.0.0 v1.0.1 >/dev/null
    run _vendor
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "LOCAL  lib/a.sh  — edited locally — would be OVERWRITTEN"
}
