#!/usr/bin/env bats
# T-3453 — `fw doctor`'s Watchtower smoke test was an INVERTED ALARM: it printed
# a result only when the smoke test had found nothing, and printed nothing at all
# when it had found failures.
#
# Mechanism: web/smoke_test.py exits 1 when any endpoint fails, while still
# writing its complete JSON. bin/fw captured it as
#     smoke_result=$(python3 … --json 2>/dev/null || echo '{"failed":0,…}')
# where the `|| echo` existed only to satisfy `set -e`. On a failing run the
# script HAD written its JSON, so the fallback object was appended to it, the
# capture became two concatenated JSON documents, every json.load raised
# "Extra data" and fell back to 0, and the print logic had no branch for
# failed==0 && passed==0 — so nothing was printed.
#
# Extraction convention (T-3202): the real block is sed-extracted from bin/fw
# and executed against stub smoke_test.py scripts. Re-implementing the logic
# here would produce a test that cannot detect the logic changing.
#
# Both legs are pinned AND the failing leg is demonstrated against the PRE-FIX
# block read from git, so this file distinguishes "fires correctly" from
# "always fires" — a guard that only ever passes is the thing being fixed.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    mkdir -p "$TEST_TEMP_DIR/fwroot/web"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# The shipped block, as it exists in bin/fw right now.
_extract_block() {
    sed -n '/^        local smoke_result smoke_rc$/,/^        fi$/p' "$FW"
}

# The block as it was BEFORE this task, read from git rather than retyped —
# the control leg. `$1` is the git ref to read bin/fw from.
_extract_prefix_block() {
    git -C "$FRAMEWORK_ROOT" show "$1:bin/fw" \
        | sed -n '/^        local smoke_result$/,/^        fi$/p'
}

# Write a stub standing in for web/smoke_test.py.
#   $1 = python body
_stub() {
    printf '%s\n' "$1" > "$TEST_TEMP_DIR/fwroot/web/smoke_test.py"
}

# Run an extracted block against the current stub. The block uses `local`, which
# is only legal inside a function, so it is wrapped in one. Colour variables are
# blanked so assertions match plain text.
#   $1 = file containing the extracted block
_run_block() {
    {
        echo 'set -euo pipefail'
        echo 'GREEN=""; YELLOW=""; NC=""'
        echo 'warnings=0'
        echo "FRAMEWORK_ROOT='$TEST_TEMP_DIR/fwroot'"
        echo '_doctor_wt_port=3002'
        echo '_smoke_block() {'
        cat "$1"
        echo '}'
        echo '_smoke_block'
        echo 'echo "WARNINGS=$warnings"'
    } > "$TEST_TEMP_DIR/harness.sh"
    run bash "$TEST_TEMP_DIR/harness.sh"
}

STUB_FAILING='import sys, json
print(json.dumps({"passed": 47, "failed": 6, "total": 53,
                  "errors": [{"path": "/", "error": "timed out"}]}))
sys.exit(1)'

STUB_CLEAN='import sys, json
print(json.dumps({"passed": 53, "failed": 0, "total": 53, "errors": []}))
sys.exit(0)'

STUB_GARBAGE='import sys
print("this is not json at all")
sys.exit(1)'

STUB_ZERO='import sys, json
print(json.dumps({"passed": 0, "failed": 0, "total": 0, "errors": []}))
sys.exit(0)'

# ── The regression itself ──────────────────────────────────────────────────

@test "a failing smoke run (exit 1 WITH valid JSON) produces a visible WARN" {
    _stub "$STUB_FAILING"
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    _run_block "$TEST_TEMP_DIR/block.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"6/53 endpoints failed"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "CONTROL: the pre-fix block printed NOTHING for that same failing run" {
    # If this ever starts producing a verdict line, the control has stopped
    # controlling and the test above proves nothing.
    _stub "$STUB_FAILING"
    _extract_prefix_block "e7e8ec72a" > "$TEST_TEMP_DIR/old.sh"
    [ -s "$TEST_TEMP_DIR/old.sh" ]
    _run_block "$TEST_TEMP_DIR/old.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"endpoints failed"* ]]
    [[ "$output" != *"Watchtower smoke test ("* ]]
    # It did not merely stay quiet — it counted no warning either.
    [[ "$output" == *"WARNINGS=0"* ]]
}

@test "a clean smoke run still produces the OK line (the fix did not invert the inversion)" {
    _stub "$STUB_CLEAN"
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    _run_block "$TEST_TEMP_DIR/block.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower smoke test (53/53 endpoints)"* ]]
    [[ "$output" == *"WARNINGS=0"* ]]
}

# ── No reachable state renders as silence ─────────────────────────────────

@test "unparseable output WARNs rather than vanishing" {
    _stub "$STUB_GARBAGE"
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    _run_block "$TEST_TEMP_DIR/block.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"result unreadable"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "a probe reporting 0 passed and 0 failed WARNs — this was the silent hole" {
    _stub "$STUB_ZERO"
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    _run_block "$TEST_TEMP_DIR/block.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing was actually checked"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "every stub produces exactly one verdict line — no state is silent, none double-reports" {
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    local stub
    for stub in "$STUB_FAILING" "$STUB_CLEAN" "$STUB_GARBAGE" "$STUB_ZERO"; do
        _stub "$stub"
        _run_block "$TEST_TEMP_DIR/block.sh"
        [ "$status" -eq 0 ]
        # Count lines carrying a verdict token, ignoring the indented error detail
        # lines and the harness's own WARNINGS= line.
        local n
        n=$(printf '%s\n' "$output" | grep -cE '^  (OK|WARN)  Watchtower smoke')
        [ "$n" -eq 1 ]
    done
}

# ── The capture contract the fix rests on ─────────────────────────────────

@test "stdout and exit status are captured separately, not merged by a || fallback" {
    # The specific shape being forbidden: a `|| echo '{...}'` INSIDE the command
    # substitution, which appends a second JSON document to a payload the script
    # already wrote.
    _extract_block > "$TEST_TEMP_DIR/block.sh"
    grep -q 'smoke_rc=0 || smoke_rc=\$?' "$TEST_TEMP_DIR/block.sh"
    run grep -c "json 2>/dev/null || echo '{" "$TEST_TEMP_DIR/block.sh"
    [ "$output" = "0" ]
}

@test "smoke_test.py really does exit non-zero while emitting valid JSON (the premise)" {
    # If this ever stops being true the fix is still correct but its rationale
    # has changed, and whoever reads this file deserves to be told by a red test
    # rather than by a comment that quietly went stale.
    _stub "$STUB_FAILING"
    run bash -c "python3 '$TEST_TEMP_DIR/fwroot/web/smoke_test.py' --port 1 --json"
    [ "$status" -eq 1 ]
    run bash -c "python3 '$TEST_TEMP_DIR/fwroot/web/smoke_test.py' --port 1 --json 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)[\"failed\"])'"
    [ "$output" = "6" ]
}
