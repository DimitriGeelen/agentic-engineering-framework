#!/usr/bin/env bats
#
# T-3144 — `fw vendor` writes executable code into a consumer tree and never
# checked that the consumer's git could see it. Reported by 010-termlink for
# `tools/`; the measured set is wider.
#
# ON "FAILS AGAINST PRE-CHANGE CODE" (AC6). It does, and that measurement is
# worth almost nothing: before this task `fw_vendor_check_visibility` did not
# exist, so every test below fails by NameError rather than by disagreeing with
# a behaviour. Same degenerate control as T-3138's lint.
#
# The tests that carry real weight are the three marked [instrument]. Each one
# is a false positive this check ACTUALLY SHIPPED WITH during T-3144, caught by
# running it against real trees rather than by reading it:
#
#   1. `git check-ignore -v` prints negation matches too, so a file re-included
#      by `!...` looked identical to a hidden one. FRAMEWORK.md and metrics.sh
#      were reported invisible while git saw them fine.
#   2. `find` under the destination sees `__pycache__/` that PYTHON wrote at
#      runtime, not the vendor. 10 of a reported 87 were runtime droppings.
#   3. The per-directory rule column showed whichever rule awk saw first, so
#      `web 55 file(s) *.png` was printed when 54 of the 55 were hidden by a
#      different rule.
#
# All three read as findings about the repo and were findings about the check.
# FIXTURES ONLY (L-599): no assertion is pinned to a live consumer project,
# because consumer .gitignore files are edited outside this repo.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/vendor-visibility.sh"
    C="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$C/.agentic-framework/tools" "$C/.agentic-framework/bin"
    git -C "$C" init -q .
    git -C "$C" config user.email t@t
    git -C "$C" config user.name t
    echo 'print(1)' > "$C/.agentic-framework/tools/corpus_explain.py"
    echo 'echo hi'  > "$C/.agentic-framework/bin/fw"
}

# The shape 010-termlink reported: deny-all plus ! re-includes for the
# directories that existed when the snapshot was taken. tools/ post-dates it.
_stale_allowlist() {
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' > "$C/.gitignore"
}

@test "T-3144/AC1: a directory outside the allowlist is reported invisible" {
    _stale_allowlist
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'tools'
}

@test "T-3144/AC3: the FAIL names the ignore rule responsible, not just the file" {
    _stale_allowlist
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 1 ]
    # file:line:pattern — everything needed to go and edit the right line.
    echo "$output" | grep -q '\.gitignore:1:\.agentic-framework/\*'
    echo "$output" | grep -q 'FAIL:'
}

@test "T-3144/AC3: it prints a re-include line that actually fixes it" {
    _stale_allowlist
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    echo "$output" | grep -q '!\.agentic-framework/tools'
    # Apply what it printed, and the same call must now pass. A remedy nobody
    # re-ran is a suggestion, not a fix.
    echo '!.agentic-framework/tools' >> "$C/.gitignore"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 0 ]
}

@test "T-3144/AC4: enumerating zero files REFUSES rather than reporting success" {
    _stale_allowlist
    mkdir -p "$C/empty-dest"
    run fw_vendor_check_visibility "$C/empty-dest" "$C"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q 'nothing was looked at'
}

@test "T-3144 [regression guard]: a non-git target cannot hide anything" {
    NG="$BATS_TEST_TMPDIR/nogit"
    mkdir -p "$NG/.agentic-framework/tools"
    echo x > "$NG/.agentic-framework/tools/a.py"
    run fw_vendor_check_visibility "$NG/.agentic-framework" "$NG"
    [ "$status" -eq 0 ]
}

@test "T-3144 [instrument]: a file re-included by a ! rule is NOT called invisible" {
    # check-ignore -v prints negation matches identically to positive ones.
    # Counting its lines reported bin/fw as hidden when git could see it.
    _stale_allowlist
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 1 ]
    # Scoped to the REPORTED ROWS, not to $output. The first version of this
    # assertion was `[[ "$output" != *'bin/fw'* ]]` and it failed against
    # correct code, because the FAIL message's own explanatory prose contains
    # the words "bin/fw execs several of them by absolute path". An assertion
    # over a whole message body matches the message, not the finding.
    [[ "$(echo "$output" | grep -cE '^ *bin +[0-9]+ file')" == "0" ]]
    [[ "$output" != *'!.agentic-framework/bin'* ]]
    # and the real finding is still present, so this is not passing by silence
    echo "$output" | grep -qE '^ *tools +[0-9]+ file'
}

@test "T-3144 [instrument]: runtime __pycache__ is not counted as a vendor failure" {
    # Python writes these beside vendored modules AFTER the vendor ran. They are
    # correctly ignored and were never vendored; counting them reports a
    # correctly-configured repo as broken.
    printf '%s\n' '__pycache__/' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/lib/__pycache__"
    echo x > "$C/.agentic-framework/lib/__pycache__/mod.cpython-311.pyc"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 0 ]
}

@test "T-3144 [instrument]: each reported row names the rule true for THAT row" {
    # Two rules hiding files under one directory. A per-directory column that
    # keeps the first rule it saw would print one row attributing all of them to
    # one cause.
    mkdir -p "$C/.agentic-framework/docs"
    echo x > "$C/.agentic-framework/docs/a.png"
    echo x > "$C/.agentic-framework/docs/b.secret"
    printf '%s\n' '*.png' '*.secret' > "$C/.gitignore"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qE '^ *docs +1 file\(s\) +.*\*\.png'
    echo "$output" | grep -qE '^ *docs +1 file\(s\) +.*\*\.secret'
}
