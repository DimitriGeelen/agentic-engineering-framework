#!/usr/bin/env bats
# T-2308: fw pickup send must produce parseable YAML when --detail or --summary
# contain YAML-active characters (quotes, backslashes, regex like \d/\s,
# multi-line, non-ASCII). Prevents the cross-project bug-report channel from
# silently corrupting payloads that matter most (stack traces, code, regex).
# Origin: P-002 from /opt/100-Video-riper-and-translation-app — same class as
# L-005 (episodic YAML on regex content).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d -t fw-t2308-XXXXXX)
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    [ -d "${TMP_PROJECT:-}" ] && rm -rf "$TMP_PROJECT"
}

# Helper: parse the most-recent inbox envelope, print the requested key path.
# Usage: parse_envelope_field "payload.detail"
parse_envelope_field() {
    local field="$1"
    local envelope
    envelope=$(ls -t "$TMP_PROJECT/.context/pickup/inbox/"*.yaml 2>/dev/null | head -1)
    [ -n "$envelope" ] || { echo "NO_ENVELOPE"; return 1; }
    PARSE_PATH="$field" python3 - "$envelope" <<'PYEOF'
import os, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
path = os.environ["PARSE_PATH"].split(".")
node = data
for p in path:
    node = node[p]
print(node)
PYEOF
}

@test "t2308 t1: --detail with embedded double-quote produces parseable YAML, round-trips verbatim" {
    local payload='Stack trace says: "could not find expected colon" at line 42'
    run do_pickup_send --type bug-report --summary "embedded quote test" --detail "$payload"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
    run parse_envelope_field "payload.detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"could not find expected colon"'* ]]
}

@test "t2308 t2: --detail with regex backslashes (\\d, \\s) round-trips verbatim, no YAML escape error" {
    local payload='Regex matched \d{4} but expected \s+, no match — check pattern'
    run do_pickup_send --type bug-report --summary "regex backslash test" --detail "$payload"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
    run parse_envelope_field "payload.detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *'\d{4}'* ]]
    [[ "$output" == *'\s+'* ]]
}

@test "t2308 t3: --summary with quote+backslash combination parses + round-trips" {
    local payload='Bug: regex \w+ failed on input "abc\\def" — escape mismatch'
    run do_pickup_send --type bug-report --summary "$payload" --detail "small detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
    run parse_envelope_field "payload.summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *'\w+'* ]]
    [[ "$output" == *'"abc\\def"'* ]]
}

@test "t2308 t4: multi-line --detail preserves newlines (YAML block scalar emission)" {
    local payload="Line 1: symptom observed
Line 2: stack trace follows
Line 3:   indented continuation"
    run do_pickup_send --type bug-report --summary "multi-line test" --detail "$payload"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
    run parse_envelope_field "payload.detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Line 1: symptom observed"* ]]
    [[ "$output" == *"Line 2: stack trace follows"* ]]
    [[ "$output" == *"Line 3:   indented continuation"* ]]
}

@test "t2308 t5: non-ASCII unicode in --detail round-trips (allow_unicode)" {
    local payload='Émission: «règle» — naïve quoting → 文字化け'
    run do_pickup_send --type bug-report --summary "unicode test" --detail "$payload"
    [ "$status" -eq 0 ]
    run parse_envelope_field "payload.detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Émission"* ]]
    [[ "$output" == *"«règle»"* ]]
    [[ "$output" == *"文字化け"* ]]
}

@test "t2308 t6: emitted envelope file is itself yaml.safe_load parseable (post-write guard)" {
    local payload='Mixed: "quotes" + \d{2,4} regex + newline
and second line'
    run do_pickup_send --type bug-report --summary 'sum "with quote"' --detail "$payload"
    [ "$status" -eq 0 ]
    local envelope
    envelope=$(ls -t "$TMP_PROJECT/.context/pickup/inbox/"*.yaml 2>/dev/null | head -1)
    [ -f "$envelope" ]
    # If yaml.safe_load throws, exit status is non-zero — caught by the run/[ ] test.
    run python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1])); print('OK')" "$envelope"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}
