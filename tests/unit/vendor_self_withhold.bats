#!/usr/bin/env bats
# T-3165 (arc-012): `fw vendor self` must not sweep a concurrent task's
# uncommitted files into the vendored tree.
#
# WHY THESE TESTS LIFT THE REAL FUNCTIONS RATHER THAN RESTATING THEM.
# The guard is three shell functions in lib/upgrade.sh. A test that reimplements
# their logic passes forever while the source rots. Each test below sources the
# real lib/upgrade.sh and calls the real `_sv_is_withheld`, so editing the source
# moves these assertions.
#
# WHY THERE IS A CONTROL LEG (test: "syncs a clean file").
# A withholding guard that withheld EVERYTHING would pass every "was it withheld?"
# assertion — and would also break the push-gate remedy for every caller. An
# always-positive check is indistinguishable from a correct one without a case
# that must come back negative. That is the same discriminator T-3163 needed for
# the Stop hook and T-3099 needed for the GO-scope detector.

setup() {
    FRAMEWORK_SRC="${BATS_TEST_DIRNAME}/../.."
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/lib" "$REPO/bin"
    git -C "$REPO" init -q 2>/dev/null || (cd "$REPO" && git init -q)
    git -C "$REPO" config user.email t@t.local
    git -C "$REPO" config user.name  t
    echo "clean content"  > "$REPO/lib/clean.sh"
    echo "origin content" > "$REPO/lib/theirs.sh"
    echo "origin shim"    > "$REPO/bin/fw"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm init

    # A concurrent task's uncommitted edits: one modified, one untracked.
    echo "their in-flight edit" >> "$REPO/lib/theirs.sh"
    echo "their new module"      > "$REPO/lib/untracked.py"

    # Load the real guard against the scratch repo.
    FRAMEWORK_ROOT="$REPO"
    export FRAMEWORK_ROOT
    YELLOW=''; NC=''
    # shellcheck disable=SC1090
    source "$FRAMEWORK_SRC/lib/upgrade.sh" 2>/dev/null || true
    unset FW_VENDOR_ALL FW_VENDOR_ONLY
    _SV_GUARD_READY=false; _SV_DIRTY_SET=""; _SV_WITHHELD=""; _SV_GUARD_BANNER=0
}

@test "the guard functions exist in lib/upgrade.sh" {
    run type -t _sv_is_withheld
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

# --- the control leg: this MUST come back negative -------------------------
@test "control: a clean file is NOT withheld (guard is not always-positive)" {
    run _sv_is_withheld "$REPO/lib/clean.sh"
    [ "$status" -ne 0 ]
}

@test "a concurrent task's MODIFIED file is withheld" {
    run _sv_is_withheld "$REPO/lib/theirs.sh"
    [ "$status" -eq 0 ]
}

@test "a concurrent task's UNTRACKED file is withheld" {
    run _sv_is_withheld "$REPO/lib/untracked.py"
    [ "$status" -eq 0 ]
}

@test "the withheld file is named, with the reason and both overrides" {
    run _sv_is_withheld "$REPO/lib/theirs.sh"
    [[ "$output" == *"lib/theirs.sh"* ]]
    [[ "$output" == *"FW_VENDOR_ONLY"* ]]
    [[ "$output" == *"FW_VENDOR_ALL"* ]]
}

@test "FW_VENDOR_ONLY lets the caller sync their OWN in-flight file" {
    FW_VENDOR_ONLY="lib/theirs.sh"
    run _sv_is_withheld "$REPO/lib/theirs.sh"
    [ "$status" -ne 0 ]
}

@test "FW_VENDOR_ONLY does not widen to a file it does not name" {
    FW_VENDOR_ONLY="lib/theirs.sh"
    run _sv_is_withheld "$REPO/lib/untracked.py"
    [ "$status" -eq 0 ]
}

@test "FW_VENDOR_ALL=1 restores the old sweep" {
    FW_VENDOR_ALL=1
    run _sv_is_withheld "$REPO/lib/theirs.sh"
    [ "$status" -ne 0 ]
}

@test "guard fails OPEN outside a git repo — the push-gate remedy must not break" {
    FRAMEWORK_ROOT="$BATS_TEST_TMPDIR/not-a-repo"
    mkdir -p "$FRAMEWORK_ROOT/lib"
    echo x > "$FRAMEWORK_ROOT/lib/a.sh"
    _SV_GUARD_READY=false; _SV_DIRTY_SET=""
    run _sv_is_withheld "$FRAMEWORK_ROOT/lib/a.sh"
    [ "$status" -ne 0 ]
}

@test "every file-loop helper consults the guard, and exempts the detectors" {
    # Parity check: it is the per-helper call sites that make the guard real.
    # Counted from source so adding a seventh helper without the guard fails here
    # rather than silently re-opening the hole (the T-2711/T-2793 naming lesson).
    run grep -c '_sv_is_withheld "\$' "$FRAMEWORK_SRC/lib/upgrade.sh"
    [ "$output" -eq 6 ]
    # Each call site must be dry-run-exempt: detectors report drift, they do not hide it.
    run grep -c '\[ "\$dry_run" = true \] || ! _sv_is_withheld' "$FRAMEWORK_SRC/lib/upgrade.sh"
    [ "$output" -eq 6 ]
}
