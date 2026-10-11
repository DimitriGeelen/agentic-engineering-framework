#!/usr/bin/env bats
# T-4055: version derivation must keep the tag's patch (X.Y.Z+N.gSHA), and the
# comparison helpers must order it between X.Y.Z and the next release.

ROOT="${BATS_TEST_DIRNAME}/../.."

setup() {
    FIX="$(mktemp -d)"
    mkdir -p "$FIX/bin"
    cp "$ROOT/bin/fw" "$FIX/bin/fw"
    git -C "$FIX" init -q
    git -C "$FIX" config user.email t@t; git -C "$FIX" config user.name t
    git -C "$FIX" add -A; git -C "$FIX" commit -qm base
    git -C "$FIX" tag v1.8.9
}
teardown() { rm -rf "$FIX"; }

# Run _derive_version from the fixture's own bin/fw copy (fixture has its own .git).
derive_in_place() {
    bash -c 'BASH_SOURCE_OVERRIDE=1; source /dev/stdin; _derive_version' \
      < <(sed -n '/^_derive_version() {/,/^}/p' "$FIX/bin/fw" | sed "s#\${BASH_SOURCE\[0\]}#$FIX/bin/fw#")
}

@test "on the tag derives X.Y.Z" {
    [ "$(derive_in_place)" = "1.8.9" ]
}

@test "N commits past the tag derives X.Y.Z+N.gSHA" {
    for i in 1 2 3; do git -C "$FIX" commit -q --allow-empty -m "c$i"; done
    sha=$(git -C "$FIX" rev-parse --short HEAD)
    got="$(derive_in_place)"
    [[ "$got" == 1.8.9+3.g* ]]
    [[ "$got" == "1.8.9+3.g$sha"* ]]
}

@test "comparison orders 1.8.9 < 1.8.9+92.gx < 1.8.10 (release_version_lt)" {
    source "$ROOT/lib/release.sh"
    # build metadata has no release precedence: equal to 1.8.9, below 1.8.10
    # `! cmd` mid-block is inert under bats (L-628): assert with if/false.
    if release_version_lt 1.8.9+92.gabc 1.8.9; then false; fi
    if release_version_lt 1.8.9 1.8.9+92.gabc; then false; fi
    release_version_lt 1.8.9+92.gabc 1.8.10
    if release_version_lt 1.8.10 1.8.9+92.gabc; then false; fi
}

@test "comparison orders the same way (_version_lt)" {
    source "$ROOT/lib/version.sh"
    release_version_lt() { :; }
    if _version_lt 1.8.9+92.gabc 1.8.9; then false; fi
    _version_lt 1.8.9+92.gabc 1.8.10
    if _version_lt 1.8.10 1.8.9+92.gabc; then false; fi
}

@test "legacy pin 1.8.92 (no sha, no such tag) is undecidable, never ahead" {
    source "$ROOT/lib/version-relation.sh"
    fw_version_relation 1.8.92 1.8.10 "" "$FIX" >/dev/null
    [ "$FW_VERSION_RELATION" = "undecidable" ]
}

@test "new-form pin with a recorded sha resolves by ancestry" {
    source "$ROOT/lib/version-relation.sh"
    old=$(git -C "$FIX" rev-parse HEAD)
    git -C "$FIX" commit -q --allow-empty -m next
    fw_version_relation 1.8.9+0.gold 1.8.9+1.gnew "$old" "$FIX" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
}
