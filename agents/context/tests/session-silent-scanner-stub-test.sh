#!/bin/bash
# Stub test for agents/context/session-silent-scanner.sh (T-1212)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="$SCRIPT_DIR/../session-silent-scanner.sh"

test -x "$SCANNER" || { echo "FAIL: scanner not executable: $SCANNER"; exit 1; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.context/working" "$SANDBOX/.context/handovers" \
         "$SANDBOX/.agentic-framework/bin" "$SANDBOX/claude-projects/foo"

# Mock fw handover that records RECOVERED_SESSION_ID env var
cat > "$SANDBOX/.agentic-framework/bin/fw" <<'MOCK'
#!/bin/bash
if [ "${1:-}" = "handover" ]; then
    echo "$(date -u +%s) RECOVERED=${RECOVERED:-0} SESSION=${RECOVERED_SESSION_ID:-none}" >> "$RECOVERY_LOG"
fi
exit 0
MOCK
chmod +x "$SANDBOX/.agentic-framework/bin/fw"
export RECOVERY_LOG="$SANDBOX/recoveries.log"
touch "$RECOVERY_LOG"

# Case A: recent session (mtime now) → skipped
echo '{"type":"assistant"}' > "$SANDBOX/claude-projects/foo/S-RECENT.jsonl"

# Case B: old session with NO matching handover → should recover
echo '{"type":"assistant"}' > "$SANDBOX/claude-projects/foo/S-STALE.jsonl"
touch -d "2 hours ago" "$SANDBOX/claude-projects/foo/S-STALE.jsonl"

# Case C: old session WITH matching handover → skipped
echo '{"type":"assistant"}' > "$SANDBOX/claude-projects/foo/S-COVERED.jsonl"
touch -d "2 hours ago" "$SANDBOX/claude-projects/foo/S-COVERED.jsonl"
cat > "$SANDBOX/.context/handovers/S-COVERED.md" <<EOF
---
session_id: S-COVERED
---
already-handed-over
EOF

# Run scanner (DRY_RUN=0 because we want to exercise the recovery path in sandbox)
PROJECT_ROOT="$SANDBOX" \
CLAUDE_PROJECTS_DIR="$SANDBOX/claude-projects" \
SESSION_SILENT_THRESHOLD_MIN=30 \
DRY_RUN=0 \
"$SCANNER"
rc=$?
[ "$rc" = "0" ] || { echo "FAIL: scanner exited $rc"; exit 1; }

# Assertions
test -f "$RECOVERY_LOG" || { echo "FAIL: recovery log missing"; exit 1; }
calls=$(wc -l < "$RECOVERY_LOG")
[ "$calls" = "1" ] || { echo "FAIL: expected exactly 1 recovery call, got $calls"; cat "$RECOVERY_LOG"; exit 1; }
grep -q "SESSION=S-STALE" "$RECOVERY_LOG" || { echo "FAIL: recovery for S-STALE missing"; cat "$RECOVERY_LOG"; exit 1; }
grep -q "SESSION=S-RECENT" "$RECOVERY_LOG" && { echo "FAIL: recovered recent session"; cat "$RECOVERY_LOG"; exit 1; }
grep -q "SESSION=S-COVERED" "$RECOVERY_LOG" && { echo "FAIL: recovered already-covered session"; cat "$RECOVERY_LOG"; exit 1; }

LOG_FILE="$SANDBOX/.context/working/.session-silent-scanner.log"
test -f "$LOG_FILE" || { echo "FAIL: scanner log missing"; exit 1; }
grep -q "recovered session=S-STALE" "$LOG_FILE" || { echo "FAIL: log missing recovery entry"; cat "$LOG_FILE"; exit 1; }

echo "  Case A (recent → skip) PASS"
echo "  Case B (old, no handover → recovered) PASS"
echo "  Case C (old, with handover → skip) PASS"
echo "All session-silent-scanner stub tests PASS"
