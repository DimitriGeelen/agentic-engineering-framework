#!/usr/bin/env bats
# T-2737 — the watch file is the denominator of every fabric coverage check,
# and nothing verified it fits the project `fw context init` stamped it into.
#
# 832 (rail-398) measured the untailored default on their tree: it expands to
# ZERO files, so both coverage checks compared an empty set against the registry
# and printed complete coverage. Their real population was 115 files, 15 carded
# — 13%, reported as 100%. The reassuring "(15 cards)" was the card count being
# read as a count of files checked.
#
# Our shape differs: our watch file is tailored (this repo authored it) and
# expands to 339 files. But 600+ cards point at files no pattern covers — the
# registry has already decided those are components and the drift check cannot
# see any of them.
#
# Both signals here are DERIVED. Neither claims which files *should* be watched
# — that is a judgment call. They report contradictions the project has already
# resolved in one direction: a card exists, therefore that file is a component.

load ../test_helper

_project() {
    local d="$1"
    mkdir -p "$d/src/a" "$d/.fabric/components" \
             "$d/.tasks/active" "$d/.tasks/completed" "$d/.tasks/templates"
    touch "$d/.tasks/templates/default.md"
    : > "$d/src/a/watched.py"
    printf 'patterns:\n  - glob: "src/**/*.py"\n    expected_type: script\n' \
        > "$d/.fabric/watch-patterns.yaml"
    printf 'id: c1\nname: watched\nlocation: src/a/watched.py\ntype: script\n' \
        > "$d/.fabric/components/c1.yaml"
}

_audit() {
    (cd "$FRAMEWORK_ROOT" && PROJECT_ROOT="$1" \
        bash agents/audit/audit.sh --sections structure 2>&1 || true)
}

_require_audit_ran() {
    # audit.sh takes a lock; under a concurrent cron run it prints only
    # "Another audit is already running — exiting". Every `! grep` assertion
    # in this file would then pass on output containing no fabric section at
    # all — a vacuous green of exactly the kind this suite exists to catch.
    if echo "$1" | grep -q "Another audit is already running"; then
        skip "audit lock held by a concurrent run"
    fi
    echo "$1" | grep -q "Fabric" || {
        echo "audit produced no Fabric section:" >&2
        echo "$1" >&2
        false
    }
}

@test "T-2737 control: a fitting watch file raises neither new signal" {
    # The silent case. Without this, a guard that never fires and a guard that
    # fires correctly are indistinguishable.
    _project "$TEST_TEMP_DIR/p"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    [[ "$out" != *"point at files no watch pattern covers"* ]]
    [[ "$out" != *"matches 0 files while"* ]]
    # and the fitting case must actually reach the PASS, not fall out earlier
    echo "$out" | grep -q "Fabric drift: all 1 watched file(s) registered"
}

@test "T-2737: a card outside every pattern raises the coverage-denominator WARN" {
    _project "$TEST_TEMP_DIR/p"
    # A real file, carded, that no pattern covers — the 600-card shape.
    mkdir -p "$TEST_TEMP_DIR/p/web"
    : > "$TEST_TEMP_DIR/p/web/ask.py"
    printf 'id: c2\nname: ask\nlocation: web/ask.py\ntype: script\n' \
        > "$TEST_TEMP_DIR/p/.fabric/components/c2.yaml"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    echo "$out" | grep -q "WARN. Fabric: 1 card(s) point at files no watch pattern covers"
}

@test "T-2737: patterns matching nothing while cards exist raises the vacuity WARN" {
    # The degenerate 832 case: every coverage verdict above it is vacuous.
    _project "$TEST_TEMP_DIR/p"
    printf 'patterns:\n  - glob: "nonexistent/**/*.rs"\n    expected_type: script\n' \
        > "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    echo "$out" | grep -q "matches 0 files while 1 card(s) exist"
    echo "$out" | grep -q "vacuous"
}

@test "T-2737: the drift PASS names the size of the set it measured" {
    # Was: "All watched source files registered ($drift_total cards)" where
    # drift_total is the REGISTRY size — so it read as "N files were checked"
    # while N was the card count. That is what made 832's "(15 cards)" look
    # like coverage over 15 files when it was coverage over zero.
    _project "$TEST_TEMP_DIR/p"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    echo "$out" | grep -q "all 1 watched file(s) registered"
    ! echo "$out" | grep -q "All watched source files registered"
}

@test "T-2737: both new signals are WARN, never FAIL" {
    _project "$TEST_TEMP_DIR/p"
    mkdir -p "$TEST_TEMP_DIR/p/web"
    : > "$TEST_TEMP_DIR/p/web/ask.py"
    printf 'id: c2\nname: ask\nlocation: web/ask.py\ntype: script\n' \
        > "$TEST_TEMP_DIR/p/.fabric/components/c2.yaml"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    echo "$out" | grep -q "WARN. Fabric: 1 card(s) point at files"
    ! echo "$out" | grep -q "FAIL. Fabric: 1 card(s) point at files"
}

@test "T-2737: an orphaned card does not count as carded-unwatched" {
    # Discrimination. A card whose file was deleted is the ORPHAN signal's
    # subject, not this one's. Without the isfile() test both would fire on the
    # same card and the operator would get two contradictory instructions
    # ("widen your patterns" / "the file is gone").
    #
    # Both cards below are unwatched. Only the one whose file EXISTS may count.
    # Asserting the orphan's absence alone would pass just as well if the signal
    # had been deleted outright — so the live card is present in the same run to
    # prove the signal is firing while the orphan is excluded from it.
    _project "$TEST_TEMP_DIR/p"
    mkdir -p "$TEST_TEMP_DIR/p/web"
    : > "$TEST_TEMP_DIR/p/web/live.py"
    printf 'id: c2\nname: live\nlocation: web/live.py\ntype: script\n' \
        > "$TEST_TEMP_DIR/p/.fabric/components/c2.yaml"
    printf 'id: c3\nname: gone\nlocation: web/deleted.py\ntype: script\n' \
        > "$TEST_TEMP_DIR/p/.fabric/components/c3.yaml"
    local out; out="$(_audit "$TEST_TEMP_DIR/p")"; _require_audit_ran "$out"
    # exactly one — the orphan must not be counted alongside the live card
    echo "$out" | grep -q "Fabric: 1 card(s) point at files no watch pattern covers"
    echo "$out" | grep -q "orphaned card"
}

@test "T-2737: the signals are derived, not allowlisted" {
    # Source-derived guard (L-533). The carded-unwatched computation must come
    # from the registry and the expander output, not from a literal list of
    # directories someone expected to see.
    local blk
    blk="$(sed -n '/T-2737: the registry.s own contents are evidence/,/^print(f/p' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh")"
    [ -n "$blk" ]
    echo "$blk" | grep -q "registered"
    echo "$blk" | grep -q "watched_set"
    for smell in '"web"' '"agents"' '"src"' '"lib"'; do
        if echo "$blk" | grep -q "$smell"; then false; fi
    done
}
