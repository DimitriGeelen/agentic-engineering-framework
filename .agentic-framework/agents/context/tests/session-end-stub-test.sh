#!/bin/bash
# Stub test for agents/context/session-end.sh (T-1212)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLER="$SCRIPT_DIR/../session-end.sh"

test -x "$HANDLER" || { echo "FAIL: handler not executable: $HANDLER"; exit 1; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.context/working" "$SANDBOX/.context/handovers" "$SANDBOX/.agentic-framework/bin"

# Mock fw that records handover invocations into a file so we can assert it was/
# wasn't called.
cat > "$SANDBOX/.agentic-framework/bin/fw" <<'MOCK'
#!/bin/bash
if [ "${1:-}" = "handover" ]; then
    echo "$$ $(date -u +%s)" >> "$HANDOVER_CALL_LOG"
    exit 0
fi
exit 0
MOCK
chmod +x "$SANDBOX/.agentic-framework/bin/fw"
export HANDOVER_CALL_LOG="$SANDBOX/handover-calls"
touch "$HANDOVER_CALL_LOG"

# --- Case A: new session, no existing handover → background spawn expected ---
PAYLOAD_A='{"session_id":"S-NEW-001","reason":"logout","transcript_path":"/nonexistent"}'
echo "$PAYLOAD_A" | PROJECT_ROOT="$SANDBOX" "$HANDLER"
rc=$?
[ "$rc" = "0" ] || { echo "FAIL A: handler exited $rc"; exit 1; }

TELEMETRY="$SANDBOX/.context/working/.session-end-log"
test -f "$TELEMETRY" || { echo "FAIL A: telemetry file missing"; exit 1; }
grep -q "S-NEW-001" "$TELEMETRY" || { echo "FAIL A: telemetry missing session_id"; cat "$TELEMETRY"; exit 1; }
grep -q '"reason": "logout"' "$TELEMETRY" || { echo "FAIL A: telemetry missing reason"; cat "$TELEMETRY"; exit 1; }

# Wait briefly for background process to start (Popen is async)
sleep 1
lines=$(wc -l < "$HANDOVER_CALL_LOG")
[ "$lines" -ge "1" ] || { echo "FAIL A: fw handover was not invoked (handover-calls has $lines lines)"; exit 1; }
echo "  Case A PASS (new session → handover spawned)"

# --- Case B: session_id matches LATEST.md → skip ---
cat > "$SANDBOX/.context/handovers/LATEST.md" <<EOF
---
session_id: S-EXISTING-001
timestamp: 2026-04-24T00:00:00Z
---

# Handover
EOF

: > "$HANDOVER_CALL_LOG"   # reset mock log

PAYLOAD_B='{"session_id":"S-EXISTING-001","reason":"clear","transcript_path":"/nonexistent"}'
echo "$PAYLOAD_B" | PROJECT_ROOT="$SANDBOX" "$HANDLER"
rc=$?
[ "$rc" = "0" ] || { echo "FAIL B: handler exited $rc"; exit 1; }

sleep 1
if [ -s "$HANDOVER_CALL_LOG" ]; then
    echo "FAIL B: handover was called despite matching session_id"
    cat "$HANDOVER_CALL_LOG"; exit 1
fi

grep -q "skip-already-handed-over" "$SANDBOX/.context/working/session-end.log" || {
    echo "FAIL B: no skip-already log line"
    cat "$SANDBOX/.context/working/session-end.log"; exit 1
}
grep -q '"session_id": "S-EXISTING-001"' "$TELEMETRY" || {
    echo "FAIL B: telemetry missing entry for skip case"
    cat "$TELEMETRY"; exit 1
}
echo "  Case B PASS (matching session_id → skip, no handover call)"

echo "All session-end stub tests PASS"
