#!/usr/bin/env bats
# T-2183 (Slice 2 of T-2181) — regex corpus test for the chat bare-path scanner.
#
# Asserts chat-bare-path-scan.sh discriminates: it flags bare Watchtower paths in
# markdown bullet/table contexts (positive corpus) and stays silent on legitimate
# references (negative corpus: full URLs, inline code, fenced blocks, prose, the
# doc table inside CLAUDE.md, the regex literal itself).
#
# The scanner reads a transcript JSONL; each case here synthesises a one-turn
# transcript whose assistant text is the sample under test, runs the scanner, and
# checks whether a violation was recorded.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SCAN="$FRAMEWORK_ROOT/agents/context/chat-bare-path-scan.sh"
    [ -f "$SCAN" ] || skip "chat-bare-path-scan.sh not found"
    python3 -c 'import json' 2>/dev/null || skip "python3 unavailable"

    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"
    VIOL="$PROJ/.context/working/.bare-path-violations.yaml"
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
}

# Write a one-turn transcript whose assistant text is $1, then run the scanner.
_scan() {
    local text="$1"
    local tr="$PROJ/transcript.jsonl"
    python3 - "$tr" "$text" <<'PY'
import json, sys
tr, text = sys.argv[1], sys.argv[2]
with open(tr, "w") as f:
    f.write(json.dumps({"type":"assistant","message":{"role":"assistant",
        "content":[{"type":"text","text":text}]}}) + "\n")
PY
    : > "$VIOL"
    echo "{\"transcript_path\":\"$tr\",\"session_id\":\"S-test\"}" \
        | PROJECT_ROOT="$PROJ" bash "$SCAN"
}

_violation_count() {
    local n=0
    [ -f "$VIOL" ] && n=$(grep -c '^- path:' "$VIOL" 2>/dev/null)
    echo "${n:-0}"
}

# ---------- POSITIVE corpus (must flag) ----------

@test "positive: bare /review/T-XXX in a bullet" {
    _scan "- Handoff: /review/T-2143 for the partial-complete"
    [ "$(_violation_count)" -ge 1 ]
}

@test "positive: bare /inception/T-XXX in a bullet" {
    _scan "- Decision pending at /inception/T-2209"
    [ "$(_violation_count)" -ge 1 ]
}

@test "positive: bare /approvals in a numbered list" {
    _scan "1. Approve at /approvals/T-608"
    [ "$(_violation_count)" -ge 1 ]
}

@test "positive: bare /arcs/<slug> in a table cell" {
    _scan "| arc-011 | close | /arcs/parallel-execution-aef |"
    [ "$(_violation_count)" -ge 1 ]
}

@test "positive: two bare paths in one table row both flagged" {
    _scan "| /review/T-1 | /inception/T-2 |"
    [ "$(_violation_count)" -ge 2 ]
}

# ---------- NEGATIVE corpus (must stay silent) ----------

@test "negative: full http URL is not flagged" {
    _scan "- See http://192.168.10.107:3000/review/T-2143 for review"
    [ "$(_violation_count)" -eq 0 ]
}

@test "negative: inline-code path is not flagged" {
    _scan "- The literal \`/review/T-999\` is the example path"
    [ "$(_violation_count)" -eq 0 ]
}

@test "negative: fenced code block path is not flagged" {
    _scan "Run this:
\`\`\`
/approvals/T-555
\`\`\`"
    [ "$(_violation_count)" -eq 0 ]
}

@test "negative: prose (non-bullet, non-table) mention is not flagged" {
    _scan "The /gaps/G-1 page lists open gaps for the operator to read."
    [ "$(_violation_count)" -eq 0 ]
}

@test "negative: the regex literal in a code fence is not flagged" {
    _scan "Pattern:
\`\`\`
/(review|inception|approvals)/T?-?[A-Za-z0-9_-]+
\`\`\`"
    [ "$(_violation_count)" -eq 0 ]
}

@test "negative: https URL with route tail not flagged (URL-strip-first)" {
    _scan "| T-A | https://host/inception/T-A | https://host/review/T-B |"
    [ "$(_violation_count)" -eq 0 ]
}
