#!/usr/bin/env bats
# T-2726 — the #@init: manifest and the validator's evaluator `case` are two
# representations of one rule set. Nothing joined them.
#
# Origin: a correct fresh `fw init` printed
#   ? md-3bv  Unknown check type            (to stderr)
#   Validation passed: 40/42 checks OK (2 skipped)
# and returned success. `md-3bv policy/bvp-scoring-rubric.md` is declared in
# lib/init.sh but no `md)` branch exists, so it fell to `*)` → skipped. `total`
# is incremented before the case, so it inflated the denominator while never
# being evaluated. The artifact happened to exist; the check was lucky, not right.
#
# This is the *vacuous* dual of T-2724's *unreachable* one (832 rail 381):
#   unreachable PASS   check always fails,    reads as decoration
#   vacuous PASS       check never evaluates, reads as confirmation
#
# Both type sets below are derived from source in both directions. There is no
# hand-maintained list of check types in this file — a re-typed list is the same
# defect one level up.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    INIT_SH="$FRAMEWORK_ROOT/lib/init.sh"
    VALIDATE_SH="$FRAMEWORK_ROOT/lib/validate-init.sh"
    TEST_TEMP_DIR="$(mktemp -d -t fw-typejoin-XXXXXX)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── extraction, from the real sources ───────────────────────────────────────────

# Types the manifest declares: the prefix of each `#@init: <type>-<key> <path>`.
_declared_types() {
    grep -o '#@init:[[:space:]]*[a-z][a-z]*-' "$INIT_SH" \
        | sed 's/#@init:[[:space:]]*//; s/-$//' | sort -u
}

# Types the evaluator serves: the labels of `case "$check_type" in`, minus the
# `*)` fallthrough. Alternation labels (`a|b)`) count as both.
_handled_types() {
    sed -n '/case "\$check_type" in/,/^        esac/p' "$VALIDATE_SH" \
        | grep -E '^[[:space:]]+[a-z|]+\)' \
        | tr -d ' )' | tr '|' '\n' | grep -v '^$' | sort -u
}

@test "T-2726: extraction finds a non-trivial set on both sides" {
    # A join test that silently compares two empty sets passes for the wrong
    # reason — the exact failure mode this whole task is about.
    run bash -c "$(declare -f _declared_types); INIT_SH='$INIT_SH'; _declared_types | wc -l"
    [ "$status" -eq 0 ]
    [ "$output" -ge 4 ]

    run bash -c "$(declare -f _handled_types); VALIDATE_SH='$VALIDATE_SH'; _handled_types | wc -l"
    [ "$status" -eq 0 ]
    [ "$output" -ge 4 ]
}

@test "T-2726: every declared check type has an evaluator" {
    local orphans
    orphans=$(comm -23 <(_declared_types) <(_handled_types))
    if [ -n "$orphans" ]; then
        echo "Declared in lib/init.sh with no evaluator in lib/validate-init.sh:"
        echo "$orphans" | sed 's/^/  /'
        echo ""
        echo "Such a check is counted in the validation total and never evaluated;"
        echo "the run reports success about a check it did not run."
        false
    fi
}

@test "T-2726: evaluators with no declared carrier are a pinned, named set" {
    # NOT an error. An evaluator with zero carriers is capability without
    # occupancy — deleting it would manufacture a capability zero out of an
    # occupancy zero (832 rail 378, same discipline as T-2725's shape D).
    # But it must not drift silently: this pins the set so a new unoccupied
    # evaluator has to be declared deliberately.
    local unoccupied
    unoccupied=$(comm -13 <(_declared_types) <(_handled_types) | tr '\n' ' ' | sed 's/ $//')
    [ "$unoccupied" = "exec" ]
}

# ── runtime disposition ─────────────────────────────────────────────────────────

# Build a framework root whose lib/init.sh declares exactly one check of the
# given type, so do_validate_init runs against a manifest we control.
_fake_root_with_check() {
    local annotation="$1"
    local root="$TEST_TEMP_DIR/fakeroot"
    rm -rf "$root"; mkdir -p "$root/lib"
    cp "$VALIDATE_SH" "$root/lib/validate-init.sh"
    # The scraper matches the literal '#@init:' with no space — emitting
    # '# @init:' produces a fixture that is silently never read.
    {
        printf '#!/usr/bin/env bash\n'
        printf '#@init: %s\n' "$annotation"
        printf '# A seeded check for the join guard\n'
    } > "$root/lib/init.sh"
    printf '%s' "$root"
}

# do_validate_init resolves the manifest from FRAMEWORK_ROOT at CALL time, and
# falls back to the real lib/init.sh when it is unset. A `VAR=x source ...`
# prefix does not survive to the call — the fixture is then ignored in silence
# and every seeded case reads as the real tree.
_validate_with_root() {
    local root="$1" target="$2"
    ( set +e
      export FRAMEWORK_ROOT="$root"
      source "$VALIDATE_SH" >/dev/null 2>&1
      do_validate_init "$target" 2>&1 )
}

# A minimal fixture necessarily fails unrelated func-*/sem-* checks, so the
# overall exit status cannot isolate how one manifest entry was dispositioned —
# an assertion on RC alone is green about the wrong object. Measure the seeded
# check's *contribution to the failed count* differentially against a control
# that differs only in that entry (832: measure the control before the case).
_failed_count() {
    local annotation="$1" target="$2"
    local root; root=$(_fake_root_with_check "$annotation")
    local out
    out=$(_validate_with_root "$root" "$target")
    out=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')
    # 'Validation passed: …' and 'Validation: N error(s) …' — an anchored
    # alternation with a space matches only the first, which would make every
    # failing run parse as empty and silently skip the comparison.
    local line; line=$(printf '%s\n' "$out" | grep -E "Validation" | head -1)
    if printf '%s' "$line" | grep -q "Validation passed"; then
        echo 0
    else
        printf '%s' "$line" | sed -n 's/.*Validation: \([0-9]*\) error(s).*/\1/p'
    fi
}

@test "T-2726: an unknown check type raises the failed count, it is not absorbed as a skip" {
    mkdir -p "$TEST_TEMP_DIR/proj/.context"
    local base unknown
    base=$(_failed_count 'dir-001 .context' "$TEST_TEMP_DIR/proj")
    unknown=$(_failed_count 'zzzz-001 .context' "$TEST_TEMP_DIR/proj")
    echo "base=$base unknown=$unknown"
    [ -n "$base" ] && [ -n "$unknown" ]
    # Same target, same path, ONLY the type differs — so the delta is the
    # disposition of an unservable check and nothing else.
    [ "$unknown" -eq "$((base + 1))" ]
}

@test "T-2726 control: the failed count does move for an ordinary failure" {
    # Proves the differential above can detect a +1 at all. Without this, a
    # counter that never moves would make the previous test unfalsifiable.
    mkdir -p "$TEST_TEMP_DIR/proj/.context"
    local base missing
    base=$(_failed_count 'dir-001 .context' "$TEST_TEMP_DIR/proj")
    missing=$(_failed_count 'dir-001 no-such-dir' "$TEST_TEMP_DIR/proj")
    echo "base=$base missing=$missing"
    [ "$missing" -eq "$((base + 1))" ]
}

@test "T-2726 control: two servable checks on a good tree add nothing" {
    # The delta is attributable to servability, not to manifest length.
    mkdir -p "$TEST_TEMP_DIR/proj/.context"
    local base second
    base=$(_failed_count 'dir-001 .context' "$TEST_TEMP_DIR/proj")
    second=$(_failed_count 'dir-002 .context' "$TEST_TEMP_DIR/proj")
    echo "base=$base second=$second"
    [ "$second" -eq "$base" ]
}

@test "T-2726: the unknown-type message is visible on stdout, not only stderr" {
    local root; root=$(_fake_root_with_check 'zzzz-001 some/path')
    mkdir -p "$TEST_TEMP_DIR/proj"
    local out
    out=$( set +e
           export FRAMEWORK_ROOT="$root"
           source "$VALIDATE_SH" >/dev/null 2>&1
           do_validate_init "$TEST_TEMP_DIR/proj" 2>/dev/null )
    echo "$out"
    [[ "$out" == *"zzzz-001"* ]]
}

# ── end-to-end: the shape the operator actually sees ────────────────────────────

@test "T-2726: a fresh fw init reports no unknown check types" {
    local proj="$TEST_TEMP_DIR/fresh"
    mkdir -p "$proj"
    local out
    out=$("$FRAMEWORK_ROOT/bin/fw" init "$proj" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    echo "$out"
    [[ "$out" != *"Unknown check type"* ]]
}

@test "T-2726: a fresh fw init's validation count reconciles" {
    # passed + skipped == total on a clean install. Before the fix this held
    # numerically while one of the skips was an unservable check rather than a
    # deliberately conditional one — so the count is necessary, not sufficient,
    # and the unknown-type test above is what carries the real claim.
    local proj="$TEST_TEMP_DIR/fresh2"
    mkdir -p "$proj"
    local line
    line=$("$FRAMEWORK_ROOT/bin/fw" init "$proj" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' \
           | grep -E "Validation (passed|:)" | head -1)
    echo "$line"
    [ -n "$line" ]
    local passed total skipped
    passed=$(echo "$line" | sed -n 's/.*: \([0-9]*\)\/[0-9]* checks OK.*/\1/p')
    total=$(echo "$line" | sed -n 's/.*: [0-9]*\/\([0-9]*\) checks OK.*/\1/p')
    skipped=$(echo "$line" | sed -n 's/.*(\([0-9]*\) skipped).*/\1/p')
    skipped="${skipped:-0}"
    [ -n "$passed" ] && [ -n "$total" ]
    [ "$((passed + skipped))" -eq "$total" ]
}
