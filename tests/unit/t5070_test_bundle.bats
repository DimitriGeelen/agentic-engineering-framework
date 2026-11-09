#!/usr/bin/env bats
# T-5070 — fw test bundle: the package node1 runs AEF's unit suite from (T-5069 spec).
# A fixture repo stands in for AEF; nothing here touches the real repository.

LIB="${BATS_TEST_DIRNAME}/../../lib/test-bundle.sh"

setup() {
    T="$(mktemp -d)"
    R="$T/repo"
    mkdir -p "$R/lib" "$R/.context/handovers" "$R/.context/message-archive" \
             "$R/.context/reviews/evidence" "$R/tests"
    echo 'echo a' > "$R/lib/a.sh"
    echo 'keep' > "$R/.context/reviews/verdicts.jsonl"
    echo 'old handover' > "$R/.context/handovers/S-1.md"
    echo 'old mail' > "$R/.context/message-archive/m.json"
    echo 'big evidence' > "$R/.context/reviews/evidence/e.txt"
    echo 't' > "$R/tests/t.bats"
    git -C "$R" init -q -b main
    git -C "$R" add -A
    GIT_AUTHOR_DATE="2026-11-09T10:00:00Z" GIT_COMMITTER_DATE="2026-11-09T10:00:00Z" \
        git -C "$R" -c user.email=t@t -c user.name=t commit -qm base
}

teardown() { rm -rf "$T"; }

bundle() { ( source "$LIB"; PROJECT_ROOT="$R" fw_test_bundle "$@" ); }

@test "T-5070: the bundle clones to one commit with the tree, without the three history folders" {
    run bundle --out "$T/b.bundle"
    [ "$status" -eq 0 ]
    git clone -q "$T/b.bundle" "$T/c"
    [ "$(git -C "$T/c" log --oneline | wc -l)" -eq 1 ]
    [ "$(git -C "$T/c" branch --show-current)" = "bleeding-edge" ]
    [ -f "$T/c/lib/a.sh" ]
    [ -f "$T/c/.context/reviews/verdicts.jsonl" ]
    [ ! -e "$T/c/.context/handovers" ]
    [ ! -e "$T/c/.context/message-archive" ]
    [ ! -e "$T/c/.context/reviews/evidence" ]
}

@test "T-5070: it reports source ref, bundle commit, size and sha256" {
    run bundle --out "$T/b.bundle"
    [[ "$output" == *"source_ref:     $(git -C "$R" rev-parse HEAD)"* ]]
    [[ "$output" == *"bundle_commit:  "* ]]
    [[ "$output" == *"size_bytes:"*"cap 64 MB"* ]]
    [[ "$output" == *"sha256:         $(sha256sum "$T/b.bundle" | cut -c1-64)"* ]]
}

@test "T-5070: the same ref gives the same bundle commit id" {
    a=$(bundle --out "$T/1.bundle" | awk '/bundle_commit/{print $2}')
    b=$(bundle --out "$T/2.bundle" | awk '/bundle_commit/{print $2}')
    [ -n "$a" ]
    [ "$a" = "$b" ]
}

@test "T-5070: an uncommitted edit is not in the bundle (built from the commit)" {
    echo 'half-finished' >> "$R/lib/a.sh"
    run bundle --out "$T/b.bundle"
    [ "$status" -eq 0 ]
    git clone -q "$T/b.bundle" "$T/c"
    ! grep -q half-finished "$T/c/lib/a.sh"
}

@test "T-5070: over the cap it refuses and writes nothing" {
    run bundle --out "$T/b.bundle" --max-mb 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"*"over the 0 MB cap"* ]]
    [ ! -e "$T/b.bundle" ]
}

@test "T-5070: a ref that is not a commit is a usage error" {
    run bundle --ref no-such-ref --out "$T/b.bundle"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not a commit"* ]]
}

@test "T-5070: by default the bundle lands in .context/scratch/node1-bundles/ (the folder the relay copies from)" {
    run bundle
    [ "$status" -eq 0 ]
    sha=$(git -C "$R" rev-parse HEAD)
    [ -f "$R/.context/scratch/node1-bundles/aef-unit-suite-${sha:0:12}.bundle" ]
    [ "$(ls "$R/.context/scratch/node1-bundles" | wc -l)" -eq 1 ]
}
