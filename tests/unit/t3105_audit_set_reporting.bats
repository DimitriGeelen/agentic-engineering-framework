#!/usr/bin/env bats
# T-3105 (slice 3 of 3): audit checks must report the set they evaluated.
#
# The rule under test:
#   A check may only PASS over the set it actually evaluated, and must report
#   that set's size. An empty or unenumerable candidate set is a WARN, not a
#   PASS.
#
# The functions are EXTRACTED from the shipped agents/audit/audit.sh by
# tests/helpers/audit-set-reporting-block.sh, not copied here — see that file.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/tests/helpers/audit-set-reporting-block.sh"
}

_run_fn() { run "$RUNNER" "$REPO_ROOT" "$@"; }

# ── 1. count > 0 -> PASS, and the count appears in the emitted text ──────────

@test "count > 0 emits PASS and renders the count into the message" {
    _run_fn pass_over 3124 "task file(s)" "No duplicate task IDs"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No duplicate task IDs — examined 3124 task file(s)$'
    ! echo "$output" | grep -q '^WARN|'
}

@test "count > 0 with count 1 still renders the count (no plural special-casing)" {
    _run_fn pass_over 1 "arc(s)" "All arcs resolve"
    echo "$output" | grep -q '^PASS|All arcs resolve — examined 1 arc(s)$'
}

# ── 2. count == 0 -> WARN, text says it did not evaluate ─────────────────────

@test "count == 0 emits WARN, not PASS" {
    _run_fn pass_over 0 "completed inception(s)" "No GO-scope-not-propagated inceptions"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|'
    ! echo "$output" | grep -q '^PASS|'
}

@test "count == 0 WARN text says NOT EVALUATED and names the empty set" {
    _run_fn pass_over 0 "completed inception(s)" "No GO-scope-not-propagated inceptions"
    echo "$output" | grep -q 'NOT EVALUATED: candidate set empty (0 completed inception(s))'
}

@test "count == 0 carries caller-supplied evidence and mitigation when given" {
    _run_fn pass_over 0 "widget(s)" "All widgets fine" "the widget list was empty" "Check the widget enumerator"
    echo "$output" | grep -q '^EVIDENCE|the widget list was empty$'
    echo "$output" | grep -q '^MITIGATION|Check the widget enumerator$'
}

@test "count == 0 falls back to a default mitigation naming the set" {
    _run_fn pass_over 0 "widget(s)" "All widgets fine"
    echo "$output" | grep -q '^MITIGATION|.*0 widget(s).*'
}

# ── 3. unenumerable -> WARN, text names what could not be read ───────────────

@test "warn_unenumerable emits WARN naming the unreadable source" {
    _run_fn warn_unenumerable ".context/designer/projects/" "Corpus maps lint clean"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Corpus maps lint clean — NOT EVALUATED: could not read .context/designer/projects/$'
    ! echo "$output" | grep -q '^PASS|'
}

@test "pass_over routes an empty count to the unenumerable branch" {
    # A caller whose $(...) collapsed to "" must NOT be reported as a measured
    # set of size 0 — it never measured anything. This is the T-3099 shape.
    _run_fn pass_over "" "python3 pre-scan over .tasks" "No GO-scope-not-propagated inceptions"
    echo "$output" | grep -q 'NOT EVALUATED: could not read python3 pre-scan over .tasks'
    ! echo "$output" | grep -q 'candidate set empty'
    ! echo "$output" | grep -q '^PASS|'
}

@test "pass_over routes a non-numeric count to the unenumerable branch" {
    _run_fn pass_over "timeout" "corpus store" "Corpus clean"
    echo "$output" | grep -q 'NOT EVALUATED: could not read corpus store'
    ! echo "$output" | grep -q '^PASS|'
}

@test "pass_over tolerates surrounding whitespace on a real count" {
    # `wc -l` on some platforms pads its output; that must not be mistaken for
    # an unenumerable set.
    _run_fn pass_over "   42 " "file(s)" "All files clean"
    echo "$output" | grep -q '^PASS|All files clean — examined 42 file(s)$'
}

# ── 4. the rendered count equals the real set size (assert the number) ───────

@test "rendered count equals the real set size — measured, not hard-coded" {
    # Build a real directory, count it with the same idiom audit.sh uses, and
    # assert the EXACT integer appears. Asserting a regex like [0-9]+ would pass
    # against any number, including a wrong one.
    d="$BATS_TEST_TMPDIR/corpus"
    mkdir -p "$d"
    for i in 1 2 3 4 5 6 7; do : > "$d/T-$i.md"; done
    n=$(find "$d" -maxdepth 1 -name '*.md' -type f | wc -l)
    [ "$n" -eq 7 ]
    _run_fn pass_over "$n" "task file(s)" "All task files parse"
    rendered=$(echo "$output" | sed -n 's/^PASS|All task files parse — examined \([0-9]*\) task file(s)$/\1/p')
    [ "$rendered" = "7" ]
    [ "$rendered" -eq "$n" ]
}

@test "rendered count tracks the set size when the set changes" {
    d="$BATS_TEST_TMPDIR/corpus2"
    mkdir -p "$d"
    for i in 1 2 3; do : > "$d/T-$i.md"; done
    n=$(find "$d" -maxdepth 1 -name '*.md' -type f | wc -l)
    _run_fn pass_over "$n" "task file(s)" "All task files parse"
    rendered=$(echo "$output" | sed -n 's/^PASS|All task files parse — examined \([0-9]*\) task file(s)$/\1/p')
    [ "$rendered" -eq 3 ]
    # ...and the empty directory must not render "examined 0", it must WARN.
    rm -f "$d"/*.md
    n2=$(find "$d" -maxdepth 1 -name '*.md' -type f | wc -l)
    [ "$n2" -eq 0 ]
    _run_fn pass_over "$n2" "task file(s)" "All task files parse"
    ! echo "$output" | grep -q 'examined 0'
    echo "$output" | grep -q 'candidate set empty (0 task file(s))'
}

# ── 5. PASS/WARN/FAIL tallies increment correctly for each path ──────────────

@test "tallies: count > 0 increments pass only" {
    _run_fn pass_over 5 "thing(s)" "All things fine"
    echo "$output" | grep -q '^COUNTS|pass=1|warn=0|fail=0$'
}

@test "tallies: count == 0 increments warn only" {
    _run_fn pass_over 0 "thing(s)" "All things fine"
    echo "$output" | grep -q '^COUNTS|pass=0|warn=1|fail=0$'
}

@test "tallies: unenumerable increments warn only" {
    _run_fn warn_unenumerable "the store" "All things fine"
    echo "$output" | grep -q '^COUNTS|pass=0|warn=1|fail=0$'
}

@test "tallies: no path ever reaches fail()" {
    # The rule downgrades an unevaluated check to WARN, never FAIL — audit's
    # exit code 2 is reserved for real failures, and an unevaluated check is an
    # unknown, not a failure.
    for a in "pass_over 5 s m" "pass_over 0 s m" "warn_unenumerable s m"; do
        # shellcheck disable=SC2086
        run "$RUNNER" "$REPO_ROOT" $a
        echo "$output" | grep -q '|fail=0$'
    done
    run bash -c "sed -n '/^pass_over() {/,/^}/p;/^warn_unenumerable() {/,/^}/p' '$REPO_ROOT/agents/audit/audit.sh' | grep -E '^[[:space:]]*fail '"
    [ "$status" -ne 0 ]
}

# ── the shipped source actually defines both verbs ───────────────────────────

@test "audit.sh defines pass_over and warn_unenumerable at top level" {
    grep -q '^pass_over() {' "$REPO_ROOT/agents/audit/audit.sh"
    grep -q '^warn_unenumerable() {' "$REPO_ROOT/agents/audit/audit.sh"
}

@test "the GO-scope check uses the shared helper, not a hand implementation" {
    # T-3105 scope item 3: T-3099's hand-rolled empty-set WARN is exactly what
    # the helper generalises. Two implementations of one rule is the drift risk.
    block=$(sed -n '/^if \[ -z "\$go_scope_summary" \]; then/,/^# end GO-scope-not-propagated scan/p' \
            "$REPO_ROOT/agents/audit/audit.sh")
    [ -n "$block" ]
    echo "$block" | grep -q 'pass_over'
    echo "$block" | grep -q 'warn_unenumerable'
    # and no bare pass "..." survives in it
    ! echo "$block" | grep -qE '^[[:space:]]*pass "'
}
