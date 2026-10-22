#!/usr/bin/env bats
# T-2436 (OBS-076): `fw vendor self --check` is a READ-ONLY drift verifier.
#
# Before T-2436 the `--check` flag was silently accepted by the `vendor self`
# routing in bin/fw but matched neither `--dry-run` nor a real flag, so it fell
# through to a REAL mutating sync that exited 0. A caller running
# `fw vendor self --check` expecting verification actually MUTATED the vendored
# .agentic-framework/ tree and saw a misleading "clean" (exit 0) — the drift was
# just made clean, never committed. That silent-mutation trap is the OBS-076
# "audit and `vendor self --check` disagree".
#
# Fix: `--check` runs every helper in dry-run mode (never mutates) and EXITS
# NON-ZERO when any class is out of sync — the form that AGREES with audit's
# check_self_vendor_drift and with the pre-push gate's `--dry-run` grep.
#
# Surfaces under test: bin/fw `vendor self` routing block.
#   --check maps to dry-run+check, not a real sync   — t1 (static)
#   --check exits 1 on drift / 0 in sync (logic)     — t2 (static)
#   --check NEVER mutates the vendored tree           — t3 (behavioral)
#   --check exit code agrees with --dry-run state     — t4 (behavioral)
#   --help documents --check                          — t5
#   in-sync leg survives unrelated drift at HEAD      — t6 (T-4585)

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

# ─────────────────────────────────────────────────────────────────────────
# Static — routing wires --check to dry-run+check, not a mutating sync
# ─────────────────────────────────────────────────────────────────────────

@test "t2436 t1: bin/fw maps --check to dry-run + check (not a real sync)" {
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw missing"
    # The case branch must set BOTH _vs_dry=true (read-only) AND _vs_check=true.
    grep -qE -- '--check\)[[:space:]]*_vs_dry=true;[[:space:]]*_vs_check=true' "$FRAMEWORK_ROOT/bin/fw"
}

@test "t2436 t2: bin/fw --check exits non-zero on drift, zero in sync" {
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw missing"
    # Slice the vendor-self check block and assert the exit-code logic.
    out=$(awk '/_vs_check=false/,/exit 0$/' "$FRAMEWORK_ROOT/bin/fw")
    [ -n "$out" ] || { echo "vendor self check block not found"; return 1; }
    # Drift path: grep "would sync" → exit 1.
    echo "$out" | grep -q 'would sync' || { echo "$out"; return 1; }
    echo "$out" | grep -qE 'exit 1' || { echo "$out"; return 1; }
    # In-sync path: emit "in sync" and exit 0.
    echo "$out" | grep -q 'in sync with source' || { echo "$out"; return 1; }
}

# ─────────────────────────────────────────────────────────────────────────
# Behavioral — read-only contract holds against the live tree
# ─────────────────────────────────────────────────────────────────────────

# T-3972: t3/t4 used to run on the LIVE repo and compare its git status. A concurrent
# `fw vendor self` (an agent at work during the nightly) turned t3 red with no defect, and
# on a clean live tree t3 could not see a mutation at all — nothing was there to sync.
# They now run on a throwaway clone of HEAD with drift planted on purpose.
# T-4585: the clone starts from a SYNCED baseline. HEAD can itself carry committed
# drift (another worker mid-sync); without this, t4's "drift removed → in sync" leg
# asserted the whole tree and went red on drift the test never planted.
# Optional $1: repo to clone (default the live framework) — the regression test passes
# a repo with unrelated drift committed at its HEAD.
_clone_with_drift() {
    CL="$BATS_TEST_TMPDIR/fw"
    git clone -q --shared "${1:-$FRAMEWORK_ROOT}" "$CL"
    _cfw vendor self >/dev/null 2>&1 || { echo "baseline vendor self failed"; return 1; }
    git -C "$CL" add -A .agentic-framework
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qm "T-4585: synced baseline" --allow-empty
    _cfw vendor self --check >/dev/null 2>&1 || { echo "baseline not in sync after vendor self"; return 1; }
    printf '# t2436 planted drift\n' >> "$CL/lib/colors.sh"   # source changed, vendored copy not
    # Committed: a REAL sync withholds uncommitted source (T-3165), so with the drift left
    # uncommitted a --check that wrongly synced would copy nothing and t3 could not see it.
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qam "T-3972: planted drift"
    VENDORED="$CL/.agentic-framework/lib/colors.sh"
    VSUM=$(sha256sum "$VENDORED" | cut -d' ' -f1)
}

_cfw() {   # the clone's fw, rooted in the clone (no inherited live PROJECT_ROOT)
    ( cd "$CL" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u CLAUDE_PROJECT_DIR "$CL/bin/fw" "$@" )
}

@test "t2436 t3: --check reports planted drift (1) and never mutates the vendored copy" {
    _clone_with_drift
    run _cfw vendor self --check
    [ "$status" -eq 1 ]
    [ "$(sha256sum "$VENDORED" | cut -d' ' -f1)" = "$VSUM" ] \
        || { echo "MUTATION: --check synced the vendored copy"; return 1; }
    ! grep -q 't2436 planted drift' "$VENDORED"
}

@test "t2436 t4: --check exit code agrees with --dry-run, with and without drift" {
    _clone_with_drift
    run _cfw vendor self --check;   [ "$status" -eq 1 ]
    run _cfw vendor self --dry-run; [[ "$output" == *"would sync"* ]]
    git -C "$CL" show HEAD~1:lib/colors.sh > "$CL/lib/colors.sh"
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qam "T-3972: drift removed"
    run _cfw vendor self --dry-run; [[ "$output" != *"would sync"* ]]
    run _cfw vendor self --check;   [ "$status" -eq 0 ]
}

@test "t2436 t6 (T-4585): t4's in-sync leg holds when HEAD already carries unrelated drift" {
    SRC="$BATS_TEST_TMPDIR/src"
    git clone -q --shared "$FRAMEWORK_ROOT" "$SRC"
    printf '# t4585 unrelated drift at HEAD\n' >> "$SRC/lib/paths.sh"
    git -C "$SRC" -c user.email=t@t -c user.name=t commit -qam "T-4585: unrelated drift"
    _clone_with_drift "$SRC"
    run _cfw vendor self --check;   [ "$status" -eq 1 ]
    git -C "$CL" show HEAD~1:lib/colors.sh > "$CL/lib/colors.sh"
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qam "T-4585: drift removed"
    run _cfw vendor self --dry-run; [[ "$output" != *"would sync"* ]] || { echo "$output" | grep "would sync"; return 1; }
    run _cfw vendor self --check;   [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────────
# Discoverability
# ─────────────────────────────────────────────────────────────────────────

@test "t2436 t5: fw vendor self --help documents the --check verifier" {
    run "$FW" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"read-only"* ]]
    [[ "$output" == *"T-2436"* ]]
}
