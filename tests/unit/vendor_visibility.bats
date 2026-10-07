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

@test "T-3677: pre-T-3671 runtime leftovers are not judged and never advised for un-ignoring" {
    # 832 shape: .pytest_cache + .context/working/.fw-secret-key under the
    # vendored dir, ignored by the consumer's deny-all rule.
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' '!.agentic-framework/tools' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/.pytest_cache" "$C/.agentic-framework/.context/working"
    echo x > "$C/.agentic-framework/.pytest_cache/README.md"
    echo secret > "$C/.agentic-framework/.context/working/.fw-secret-key"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'NOT written by the vendor'
    echo "$output" | grep -q 'fw-secret-key'
    if echo "$output" | grep -q '^ *!'; then false; fi
}

@test "T-3677: a real invisible dir alongside leftovers still fails, and the remedy omits .context" {
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/.context/working"
    echo secret > "$C/.agentic-framework/.context/working/.fw-secret-key"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q '!.agentic-framework/tools'
    if echo "$output" | grep -q '!.agentic-framework/.context'; then false; fi
}

@test "T-3677: with a vendor source, files absent from it are foreign" {
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' '!.agentic-framework/tools' > "$C/.gitignore"
    S="$BATS_TEST_TMPDIR/src"; mkdir -p "$S/tools" "$S/bin"
    echo 'print(1)' > "$S/tools/corpus_explain.py"; echo 'echo hi' > "$S/bin/fw"
    mkdir -p "$C/.agentic-framework/stray"; echo x > "$C/.agentic-framework/stray/f"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "$S"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'stray/f'
}

# ── T-3832: judge the manifest of what the vendor WROTE, not what is on disk ──

@test "T-3832: with a manifest, ignored leftovers on disk are counted, never judged" {
    printf '%s\n' '.agentic-framework/old/' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/old"
    for i in 1 2 3; do echo x > "$C/.agentic-framework/old/f$i"; done
    M="$BATS_TEST_TMPDIR/manifest"
    printf '%s\n' tools/corpus_explain.py bin/fw > "$M"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "" "$M"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    echo "$output" | grep -q '3 file(s) under .agentic-framework were NOT written by the vendor'
    if echo "$output" | grep -q 'invisible to git'; then echo "$output"; false; fi
}

@test "T-3832: with a manifest, an invisible WRITTEN file still fails" {
    printf '%s\n' '.agentic-framework/tools/' > "$C/.gitignore"
    M="$BATS_TEST_TMPDIR/manifest"
    printf '%s\n' tools/corpus_explain.py bin/fw > "$M"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "" "$M"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q '1 of 2 vendored file(s) are invisible'
}

@test "T-3832: an invisible pinned designer build and lib/ts/dist/*.js are named outright" {
    mkdir -p "$C/.agentic-framework/vendor/designer" "$C/.agentic-framework/lib/ts/dist"
    echo '<html>' > "$C/.agentic-framework/vendor/designer/aef-workflow-designer-0.14.0.html"
    echo 'x' > "$C/.agentic-framework/lib/ts/dist/fw-util.js"
    echo 'x' > "$C/.agentic-framework/lib/ts/dist/loop-detect.js"
    printf '%s\n' '*.html' 'dist/' > "$C/.gitignore"
    M="$BATS_TEST_TMPDIR/manifest"
    printf '%s\n' bin/fw vendor/designer/aef-workflow-designer-0.14.0.html \
        lib/ts/dist/fw-util.js lib/ts/dist/loop-detect.js > "$M"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "" "$M"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'pinned designer build (T-3064): .agentic-framework/vendor/designer/aef-workflow-designer-0.14.0.html'
    echo "$output" | grep -q 'lib/ts/dist/\*.js: 2 compiled file(s) invisible'
}

# ── T-3851 (ring20 T-2226 finding 2): runtime .context never judged, never advised ──

@test "T-3851: runtime .context dirs that exist in a full-clone source are foreign, not vendored" {
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' '!.agentic-framework/tools' > "$C/.gitignore"
    S="$BATS_TEST_TMPDIR/src"; mkdir -p "$S/tools" "$S/bin"
    echo 'print(1)' > "$S/tools/corpus_explain.py"; echo 'echo hi' > "$S/bin/fw"
    local d
    for d in sidecar scans audits project working; do
        mkdir -p "$S/.context/$d" "$C/.agentic-framework/.context/$d"
        echo x > "$S/.context/$d/f"; echo x > "$C/.agentic-framework/.context/$d/f"
    done
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "$S"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    for d in sidecar scans audits project; do
        echo "$output" | grep -q ".context/$d/f"
    done
    if echo "$output" | grep -q '!.agentic-framework/.context'; then echo "$output"; false; fi
}

@test "T-3851: a manifest entry under runtime .context is not judged" {
    printf '%s\n' '.agentic-framework/.context/' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/.context/sidecar"
    echo x > "$C/.agentic-framework/.context/sidecar/hub-id"
    M="$BATS_TEST_TMPDIR/manifest"
    printf '%s\n' bin/fw .context/sidecar/hub-id > "$M"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "" "$M"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-3851: hidden designer maps get a hazard warning, never a re-include of .context" {
    printf '%s\n' '.agentic-framework/*' '!.agentic-framework/bin' '!.agentic-framework/tools' > "$C/.gitignore"
    mkdir -p "$C/.agentic-framework/.context/designer/projects" "$C/.agentic-framework/.context/working"
    echo '{}' > "$C/.agentic-framework/.context/designer/projects/aef-x.json"
    echo secret > "$C/.agentic-framework/.context/working/.fw-secret-key"
    M="$BATS_TEST_TMPDIR/manifest"
    printf '%s\n' bin/fw tools/corpus_explain.py .context/designer/projects/aef-x.json > "$M"
    run fw_vendor_check_visibility "$C/.agentic-framework" "$C" "" "$M"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'Do NOT re-include .agentic-framework/.context as a whole'
    if echo "$output" | grep -qE '^\s*!\.agentic-framework/\.context'; then echo "$output"; false; fi
    # Applying every `!` line the advice prints leaves the secret ignored.
    echo "$output" | grep -E '^\s*!\.agentic-framework/' | sed 's/^[[:space:]]*//' >> "$C/.gitignore"
    git -C "$C" check-ignore -q .agentic-framework/.context/working/.fw-secret-key
}

@test "T-3982: comm in vendor-visibility runs in the C collation its inputs are sorted in" {
    # Inputs are sorted with LC_ALL=C; comm under a user locale warned "not in sorted order"
    # (greenfield install, 2026-10-07). Every comm call in the file must carry LC_ALL=C.
    run bash -c "grep -nE '(^|[^=_A-Za-z])comm ' '$FRAMEWORK_ROOT/lib/vendor-visibility.sh' | grep -vE '^[0-9]+:[[:space:]]*#'"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -v 'LC_ALL=C comm'
}
