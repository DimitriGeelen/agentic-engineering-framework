#!/usr/bin/env bats
# T-2714 (OBS-110): every hook counter in `fw doctor` must state its denominator.
#
# One doctor run printed four numbers for one settings.json — 25, 21, 19, 23 —
# three of them under the bare word "hooks". The 19 was wrong outright:
# sum(len(v) for v in hooks.values()) sums each event's list of MATCHER ENTRIES,
# and every entry carries a `hooks:` array of 1..n commands. So it counted matchers
# and called them hooks, and disagreed with the line three rows above it that counts
# commands correctly — leaving an operator checking a post-regenerate config (the
# T-2710 class) no way to tell which number was lying.
#
# TEST DESIGN — the fixture is the whole point.
#
# A test written against this repo's live settings.json cannot tell the fix from the
# defect in the general case, and asserting on a hand-built copy of the arithmetic
# would pass while the real doctor stayed broken (the T-2711 lesson: a test that
# compares two things the test itself controls is decorative).
#
# So: build a project whose entry count and command count DIFFER (one PreToolUse
# matcher gets two extra commands → 19 entries, 27 commands), point the REAL
# `fw doctor` at it, and read the line it actually prints. Falsified before being
# trusted — with the pre-fix expression restored, this fixture prints 19 and every
# count assertion below goes red.
#
# The asymmetry also kills the cheap fix: relabelling 19 as "19 matchers" without
# changing the arithmetic still fails, because these tests demand 27.

load ../test_helper

# Project whose entry count != command count, so the two can never be confused.
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FIXTURE="$TEST_TEMP_DIR/proj"
    export FIXTURE
    mkdir -p "$FIXTURE/.claude"
    # Symlink the real bin/ so ${CLAUDE_PROJECT_DIR}/bin/fw hook <name> resolves —
    # otherwise every hook reports as a missing binary, doctor emits FAIL, and the
    # OK line carrying the counts is never printed at all.
    ln -s "$FRAMEWORK_ROOT/bin" "$FIXTURE/bin"
    [ -f "$FRAMEWORK_ROOT/.framework.yaml" ] && cp "$FRAMEWORK_ROOT/.framework.yaml" "$FIXTURE/"

    python3 - "$FRAMEWORK_ROOT/.claude/settings.json" "$FIXTURE/.claude/settings.json" <<'PY'
import copy, json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
# Duplicate one command twice inside a single existing matcher. Entry count is
# unchanged; command count rises by 2. Every hook NAME still appears, so the
# expected-hooks check stays quiet and doctor reaches the OK branch.
entry = d['hooks']['PreToolUse'][0]
entry['hooks'].extend([copy.deepcopy(entry['hooks'][0]) for _ in range(2)])
json.dump(d, open(dst, 'w'), indent=2)
PY
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Counts straight from the fixture, so the expected numbers are derived, never typed.
fixture_counts() {   # -> "<events> <entries> <commands>"
    python3 - "$FIXTURE/.claude/settings.json" <<'PY'
import json, sys
h = json.load(open(sys.argv[1])).get('hooks', {})
print(len(h),
      sum(len(v) for v in h.values()),
      sum(len(e.get('hooks') or []) for v in h.values() for e in v))
PY
}

run_doctor() {
    # `|| true`: doctor exits non-zero on any WARN, and the fixture legitimately
    # warns about things this suite does not care about. Under bats' set -e a bare
    # `out=$(run_doctor)` would abort the test on the exit code rather than let it
    # read the output — which is the only thing being asserted here.
    ( cd "$FIXTURE" && PROJECT_ROOT="$FIXTURE" CLAUDE_PROJECT_DIR="$FIXTURE" \
        "$FRAMEWORK_ROOT/bin/fw" doctor --quick 2>&1 ) || true
}

@test "T-2714: fixture genuinely separates matcher entries from hook commands" {
    # The premise. If these ever converge, every test below passes for free and
    # proves nothing — a broken doctor and a fixed one would print the same number.
    read -r events entries commands <<< "$(fixture_counts)"
    [ "$entries" -gt 0 ]
    [ "$commands" -gt "$entries" ]
    [ "$events" -gt 0 ]
}

@test "T-2714: 'Hook configuration valid' reports COMMANDS, not matcher entries" {
    # The defect, stated as an assertion. Pre-fix this line printed the entry count.
    read -r events entries commands <<< "$(fixture_counts)"
    out=$(run_doctor)
    line=$(echo "$out" | grep 'Hook configuration valid')
    [ -n "$line" ]
    echo "$line" | grep -q "${commands} hooks"
    # ...and specifically NOT the entry count in the "hooks" slot.
    if echo "$line" | grep -q "${entries} hooks "; then
        echo "still counting matcher entries as hooks: $line"
        false
    fi
}

@test "T-2714: the message states all three denominators" {
    read -r events entries commands <<< "$(fixture_counts)"
    line=$(run_doctor | grep 'Hook configuration valid')
    echo "$line" | grep -q "${commands} hooks"
    echo "$line" | grep -q "${entries} matchers"
    echo "$line" | grep -q "${events} events"
}

@test "T-2714: the two whole-file counters agree with each other" {
    # 'Hook path validation' and 'Hook configuration valid' scan the same file for
    # the same thing. Disagreeing numbers are what made the output unreadable —
    # the operator could see they conflicted but not which one to believe.
    out=$(run_doctor)
    a=$(echo "$out" | grep 'Hook path validation' | grep -oE '[0-9]+ hooks' | grep -oE '[0-9]+' | head -1)
    b=$(echo "$out" | grep 'Hook configuration valid' | grep -oE '[0-9]+ hooks' | grep -oE '[0-9]+' | head -1)
    [ -n "$a" ]
    [ -n "$b" ]
    [ "$a" = "$b" ] || { echo "whole-file counters disagree: path-validation=$a config-valid=$b"; false; }
}

@test "T-2714: the /tmp exercise names the event scope it probes" {
    # It deliberately covers PreToolUse+PostToolUse only (PreCompact/SessionStart run
    # heavy work past the 5s budget). Legitimate — but unlabelled, its lower total
    # reads as hooks that silently went untested.
    line=$(run_doctor | grep 'Hook exercise from /tmp')
    [ -n "$line" ]
    echo "$line" | grep -q 'PreToolUse/PostToolUse'
}

@test "T-2714: NEGATIVE CONTROL — the pre-fix expression mis-reads this fixture" {
    # Runs the OLD arithmetic verbatim against the fixture. It must produce a number
    # that differs from the command count, which is what makes the assertions above
    # meaningful rather than tautological. If this ever stops differing, the fixture
    # has quietly stopped reproducing OBS-110.
    read -r events entries commands <<< "$(fixture_counts)"
    old=$(python3 - "$FIXTURE/.claude/settings.json" <<'PY'
import json, sys
hooks = json.load(open(sys.argv[1])).get('hooks', {})
print(sum(len(v) for v in hooks.values()))
PY
)
    [ "$old" = "$entries" ]
    [ "$old" != "$commands" ]
}

@test "T-2714: the print statement uses the command count variable" {
    # Source-level pin. Comments stripped (L-519): the fix's own comment explains the
    # entry-vs-command distinction at length, and entry_count is still computed
    # legitimately for the "N matchers" clause — so an unstripped grep matches prose
    # and a naive absence-check would fail on correct code.
    body=$(sed 's/[[:space:]]*#.*//' "$FRAMEWORK_ROOT/bin/fw")
    echo "$body" | grep -q "cmd_count} hooks in {entry_count} matchers"
}
