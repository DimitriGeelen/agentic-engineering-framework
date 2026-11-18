#!/bin/bash
# Block Claude Code's built-in cross-session messaging tools — TermLink only (T-5225)
#
# Operator ruling 2026-11-17, confirmed 2026-11-18 (option 1): agent-to-agent
# messages go over TermLink. Claude Code's own messaging tools deliver to another
# session or project outside TermLink's observability, receipts, untrusted-data
# framing and idle-aware delivery, so they are refused here.
#
# Refused tools (evidence in T-5225 ## Decisions):
#   SendMessage           — messages another session / teammate (to:, message:)
#   SendToProject         — sends this session's work to a Claude Project
#   SendToProjectContext  — the read step that exists only to feed SendToProject
#
# Every other tool is allowed (exit 0). A payload that cannot be read is
# refused (fail CLOSED): the settings matcher routes only the refused tools to
# this hook, so an unreadable payload here is almost certainly one of them.
#
# Pattern: agents/context/block-task-tools.sh (T-1115/T-1117).

BLOCKED_TOOLS="SendMessage SendToProject SendToProjectContext"

# Context-aware fw path (G-033/T-1182)
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$FRAMEWORK_ROOT/lib/paths.sh" 2>/dev/null || true
_fw=$(_fw_cmd 2>/dev/null || echo "bin/fw")

payload=$(cat 2>/dev/null || true)
tool_name=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    t = d.get("tool_name") if isinstance(d, dict) else None
    print(t if isinstance(t, str) else "")
except Exception:
    print("")
' 2>/dev/null)

if [ -n "$tool_name" ]; then
    case " $BLOCKED_TOOLS " in
        *" $tool_name "*) ;;          # refused below
        *) exit 0 ;;                  # any other tool: allow
    esac
    shown="$tool_name"
else
    shown="(unreadable hook payload — refused, fail closed)"
fi

# T-5231: STABLE CONTRACT. Peers (010's session-message prover) match this exact marker line.
# The prose below may change; this line must not.
echo "FW-DENY: cross-session-messaging (T-5225)" >&2
echo "BLOCKED: $shown — Claude Code's own cross-session messaging is forbidden in this project." >&2
echo "Operator rule (2026-11-17, confirmed 2026-11-18): agent-to-agent messages always go over TermLink." >&2
echo "Refused tools: $BLOCKED_TOOLS." >&2
echo "Send it this way instead:  $_fw sidecar send --to <peer> --body \"...\"" >&2
echo "(peers: 'termlink list'; reply on a thread with --conversation <id>; read yours with '$_fw sidecar inbox')" >&2
exit 2
