#!/usr/bin/env bash
# sidecar-inbox.sh — UserPromptSubmit hook: surface pending peer consults.
#
# T-3407 (arc-011 slice 5). Runs `fw sidecar inbox --peek --json` and, when
# consults are pending, emits them as additionalContext so the agent sees
# them at the start of its next turn without having been told to look.
#
# Three properties are load-bearing and each has a test:
#   PEEK, never consume — surfacing is not reading. A consult the hook
#     consumed and the agent then ignored would vanish from `fw sidecar
#     inbox`. The cursor is left where it was.
#   SILENT when empty — no consults means no stdout at all, so the common
#     case costs the turn nothing.
#   FAIL OPEN — no termlink, hub down, timeout, malformed JSON: empty
#     stdout, exit 0. A consult surface must never block a prompt.
#
# Invoked as: fw hook sidecar-inbox   (resolved via $AGENTS_DIR/context/)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
export FRAMEWORK_ROOT PROJECT_ROOT

# Drain stdin (Claude Code sends hook input JSON); we do not need it.
cat >/dev/null 2>&1 || true

FW_BIN="${FW_BIN:-$FRAMEWORK_ROOT/bin/fw}"
[ -x "$FW_BIN" ] || exit 0
command -v termlink >/dev/null 2>&1 || exit 0

# --peek: do not advance the cursor. Timeout bounds the whole thing so a
# wedged hub costs at most SIDECAR_INBOX_TIMEOUT seconds, then nothing.
raw="$(timeout "${SIDECAR_INBOX_TIMEOUT:-5}" "$FW_BIN" sidecar inbox --peek --json 2>/dev/null)" || exit 0
[ -n "$raw" ] || exit 0

python3 - "$raw" <<'PY' 2>/dev/null || exit 0
import json, sys
try:
    msgs = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
if not isinstance(msgs, list) or not msgs:
    sys.exit(0)

lines = [f"# Pending peer consult(s): {len(msgs)} — read with `fw sidecar inbox`, reply with `fw sidecar send --to <from> --conversation <id> --body '...'`", ""]
for m in msgs:
    who = m.get("from") or "unknown"
    conv = m.get("conversation_id") or "-"
    body = (m.get("body") or "").strip()
    lines.append(f"## From {who}  [conversation: {conv}]  @offset {m.get('offset')}")
    lines.append(body)
    lines.append("")
lines.append("(Surfaced by the sidecar-inbox hook, T-3407. This was a PEEK — the consult is still in your inbox until you read it with `fw sidecar inbox`.)")

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "\n".join(lines),
}}))
PY
exit 0
