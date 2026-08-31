#!/usr/bin/env bats
# T-3158 — `fw designer check-currency` / `fw doctor` designer pin CURRENCY check,
# the four control legs named as ACs.
#
# T-3119 pinned the doctor-integration shape (WARN/OK/SKIP via `bin/fw doctor`).
# This suite is the sibling that (a) exercises the STANDALONE verb
# (`agents/designer/designer.sh check-currency`, AC-3's "reachable standalone" half)
# and (b) adds the one control leg T-3119's fixtures do not isolate: the PL-021
# lexical-vs-version trap with 0.9.0 actually present in the tag set (AC-4).
#
# 001-CashWeb's framing, adopted verbatim: a checker with an always-warn bug passes
# "warns on a stale pin" IDENTICALLY to a correct one. Leg 1 (pin == newest -> silent)
# is the only leg that discriminates; leg 4 is the only leg that discriminates a
# lexical-compare regression (PL-021) from a correct integer-tuple compare.
#
# REAL REMOTE, not a mock (same discipline as t3119): a bare git repo in
# $BATS_TEST_TMPDIR carries annotated designer-v* tags; `git ls-remote --tags`
# reads it for real, so the tag-shape parsing (refs/tags/X, the ^{} peeled line)
# is exercised, not assumed.
#
# HERMETIC (T-2547): FW_DESIGNER_PIN_FILE points every verb at a TEMP COPY of the
# pin. The live tracked policy/designer-pin.yaml is never written.

load ../test_helper

setup() {
    [ -f "$FRAMEWORK_ROOT/agents/designer/designer.sh" ] || skip "designer.sh not found"

    ORIGIN="$BATS_TEST_TMPDIR/designer-origin.git"
    WORK="$BATS_TEST_TMPDIR/designer-work"
    git init -q --bare "$ORIGIN"
    git init -q "$WORK"
    (
        cd "$WORK"
        git config user.email t3158@test.local
        git config user.name "T-3158 fixture"
        echo "designer build fixture" > build.txt
        git add build.txt
        git commit -qm "T-3158: fixture commit"
        for v in 0.9.0 0.10.0 0.11.0; do
            git tag -a "designer-v$v" -m "release $v"
        done
        git remote add origin "$ORIGIN"
        git push -q origin HEAD --tags
    )

    PIN_TMP="$BATS_TEST_TMPDIR/designer-pin.yaml"
    export FW_DESIGNER_PIN_FILE="$PIN_TMP"
    # Never inherit an operator opt-out — that would make every case pass vacuously.
    export FW_SKIP_DESIGNER_CURRENCY=0
}

teardown() {
    unset FW_DESIGNER_PIN_FILE FW_SKIP_DESIGNER_CURRENCY
}

# _pin <version> <origin> — write the temp pin: a verbatim copy of the live pin with
# only version:/source_origin: overridden, one variable at a time.
_pin() {
    python3 - "$FRAMEWORK_ROOT/policy/designer-pin.yaml" "$PIN_TMP" "$1" "$2" <<'PY'
import sys, yaml
src, dst, version, origin = sys.argv[1:5]
d = yaml.safe_load(open(src))
d['version'] = version
d['source_origin'] = origin
yaml.safe_dump(d, open(dst, 'w'), sort_keys=False)
PY
}

_line() {
    printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -- "$1" | head -1
}

@test "leg 1 (discriminator): pin forced to newest published tag -> NO warning, standalone verb" {
    _pin 0.11.0 "$ORIGIN"
    run "$FRAMEWORK_ROOT/agents/designer/designer.sh" check-currency
    [ "$status" -eq 0 ]
    local vline
    vline=$(_line "designer pin current with origin")
    [ -n "$vline" ]
    [[ "$vline" == *"OK"* ]]
    [[ "$output" != *"WARN"* ]]
    [[ "$output" != *"behind its origin"* ]]
}

@test "leg 2: pin forced to an older tag -> warns, standalone verb, still exits 0 (advisory only)" {
    _pin 0.9.0 "$ORIGIN"
    run "$FRAMEWORK_ROOT/agents/designer/designer.sh" check-currency
    [ "$status" -eq 0 ]
    local vline
    vline=$(_line "designer pin is behind its origin")
    [ -n "$vline" ]
    [[ "$vline" == *"WARN"* ]]
    [[ "$vline" == *"0.9.0"* ]]
    [[ "$vline" == *"0.11.0"* ]]
    [[ "$output" == *"designer-v0.11.0"* ]]
    [[ "$output" == *"fw designer sync --from-tag"* ]]
}

@test "leg 3: origin unreachable -> SKIP with its own distinct line, never crash, exits 0" {
    _pin 0.9.0 "$BATS_TEST_TMPDIR/no-such-origin.git"
    run "$FRAMEWORK_ROOT/agents/designer/designer.sh" check-currency
    [ "$status" -eq 0 ]
    local vline
    vline=$(_line "could not reach origin")
    [ -n "$vline" ]
    [[ "$vline" == *"SKIP"* ]]
    [[ "$vline" == *"UNKNOWN"* ]]
    [[ "$vline" != *"WARN"* ]]
    # Never silent-OK: could-not-look must not read like current.
    [[ "$output" != *"designer pin current with origin"* ]]
    [[ "$output" != *"designer pin is behind its origin"* ]]
}

@test "leg 4 (PL-021 trap): version-max (0.11.0) != lexical-max (0.9.0) with 0.9.0 actually in the tag set" {
    # Lexically, "0.9.0" > "0.10.0" and "0.9.0" > "0.11.0" (character '9' > '1').
    # A string-compare regression would report the origin's newest as 0.9.0 even
    # though 0.11.0 is a later release and already the pin. Pin at the true newest
    # (0.11.0) and assert OK naming 0.11.0 — a lexical-compare mutant would instead
    # claim 0.9.0 is ahead of the pin and WARN.
    _pin 0.11.0 "$ORIGIN"
    run "$FRAMEWORK_ROOT/agents/designer/designer.sh" check-currency
    [ "$status" -eq 0 ]
    local vline
    vline=$(_line "designer pin current with origin")
    [ -n "$vline" ]
    [[ "$vline" == *"OK"* ]]
    [[ "$vline" == *"0.11.0"* ]]
    [[ "$output" != *"newest released 0.9.0"* ]]
    [[ "$output" != *"WARN"* ]]
}

@test "wired into fw doctor: same WARN line surfaces through a full doctor pass" {
    _pin 0.9.0 "$ORIGIN"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    local vline
    vline=$(_line "designer pin is behind its origin")
    [ -n "$vline" ]
    [[ "$vline" == *"WARN"* ]]
}

@test "pin has no version/source_origin -> SKIP not-checkable, never crash" {
    printf 'notes: "no version or origin here"\n' > "$PIN_TMP"
    run "$FRAMEWORK_ROOT/agents/designer/designer.sh" check-currency
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"not checkable"* ]]
}
