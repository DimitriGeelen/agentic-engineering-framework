#!/usr/bin/env bats
# T-2183 (Slice 2 of T-2181) — end-to-end test for the chat bare-path hooks.
#
# Exercises the full scan -> record -> warn -> consume cycle:
#   1. chat-bare-path-scan.sh against a transcript with a bare-path turn
#      => .bare-path-violations.yaml grows by one entry.
#   2. chat-bare-path-warn.sh
#      => stdout contains a <system-reminder> block AND the violations file is
#         truncated (consume-on-show).

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SCAN="$FRAMEWORK_ROOT/agents/context/chat-bare-path-scan.sh"
    WARN="$FRAMEWORK_ROOT/agents/context/chat-bare-path-warn.sh"
    [ -f "$SCAN" ] || skip "chat-bare-path-scan.sh not found"
    [ -f "$WARN" ] || skip "chat-bare-path-warn.sh not found"
    python3 -c 'import json' 2>/dev/null || skip "python3 unavailable"

    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"
    VIOL="$PROJ/.context/working/.bare-path-violations.yaml"
    TR="$PROJ/transcript.jsonl"
    python3 - "$TR" <<'PY'
import json, sys
with open(sys.argv[1], "w") as f:
    f.write(json.dumps({"type":"assistant","message":{"role":"assistant",
        "content":[{"type":"text","text":
            "Session handoffs:\n- T-2143 review at /review/T-2143\n"}]}}) + "\n")
PY
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
}

@test "scan records exactly one violation for a single bare-path turn" {
    [ ! -f "$VIOL" ] || rm -f "$VIOL"
    echo "{\"transcript_path\":\"$TR\",\"session_id\":\"S-e2e\"}" \
        | PROJECT_ROOT="$PROJ" bash "$SCAN"
    [ -f "$VIOL" ]
    run grep -c '^- path:' "$VIOL"
    [ "$output" -eq 1 ]
}

@test "scan exits 0 (never blocks) even with violations present" {
    run bash -c "echo '{\"transcript_path\":\"$TR\"}' | PROJECT_ROOT='$PROJ' bash '$SCAN'"
    [ "$status" -eq 0 ]
}

@test "warn emits <system-reminder> and truncates the violations file" {
    # seed a violation
    echo "{\"transcript_path\":\"$TR\",\"session_id\":\"S-e2e\"}" \
        | PROJECT_ROOT="$PROJ" bash "$SCAN"
    [ -s "$VIOL" ]

    run bash -c "echo '{}' | PROJECT_ROOT='$PROJ' bash '$WARN'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"<system-reminder>"* ]]
    [[ "$output" == *"/review/T-2143"* ]]
    [[ "$output" == *"fw task review"* ]]

    # consume-on-show: file truncated to empty
    [ ! -s "$VIOL" ]
}

@test "warn is a no-op (no output) when there are no violations" {
    : > "$VIOL"
    run bash -c "echo '{}' | PROJECT_ROOT='$PROJ' bash '$WARN'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "scan is a clean no-op when transcript path is missing" {
    [ ! -f "$VIOL" ] || rm -f "$VIOL"
    run bash -c "echo '{\"transcript_path\":\"/nonexistent/x.jsonl\"}' | PROJECT_ROOT='$PROJ' bash '$SCAN'"
    [ "$status" -eq 0 ]
    [ ! -f "$VIOL" ] || [ ! -s "$VIOL" ]
}
