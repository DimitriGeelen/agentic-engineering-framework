#!/usr/bin/env bats
# T-5105 — `_all_wdirs` (agents/termlink/termlink.sh) listed worker dirs with a quadratic
# de-duplication (one growing string matched per dir) and two `basename` forks per dir. With
# ~6,800 old worker dirs a dispatch's worker-cap check took minutes, so review seats timed out
# before registering (055's report; reproduced on AEF for T-5106). It is now linear and fork-free.
#
# The function is extracted from the script and run on its own, over generated dirs.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    T="$(mktemp -d)"
    FN="$T/fn.sh"
    sed -n '/^_all_wdirs() {/,/^}/p' "$ROOT/agents/termlink/termlink.sh" > "$FN"
    [ -s "$FN" ]
}

teardown() { rm -rf "$T"; }

run_fn() {
    bash -c 'source "$1"; shift; DISPATCH_ROOTS=("$@"); _all_wdirs' _ "$FN" "$@"
}

@test "T-5105: lists every dir, earlier root first, a name in an earlier root shadows a later one" {
    mkdir -p "$T/a/w1" "$T/a/w2" "$T/b/w2" "$T/b/w3"
    out=$(run_fn "$T/a" "$T/b")
    [ "$out" = "$(printf '%s\n' "$T/a/w1/" "$T/a/w2/" "$T/b/w3/")" ]
}

@test "T-5105: a missing root is skipped" {
    mkdir -p "$T/a/w1"
    out=$(run_fn "$T/nope" "$T/a")
    [ "$out" = "$T/a/w1/" ]
}

@test "T-5105: 7,000 worker dirs are listed in under 2 seconds" {
    mkdir -p "$T/a" "$T/b"
    ( cd "$T/a" && seq -f "worker-%05g" 1 3500 | xargs mkdir )
    ( cd "$T/b" && seq -f "worker-%05g" 3000 7000 | xargs mkdir )
    start=$(date +%s%N)
    n=$(run_fn "$T/a" "$T/b" | wc -l)
    ms=$(( ($(date +%s%N) - start) / 1000000 ))
    echo "listed $n in ${ms} ms" >&3
    [ "$n" -eq 7000 ]
    [ "$ms" -lt 2000 ]
}

@test "T-5105: the function forks no basename" {
    ! grep -q 'basename' "$FN"
}
