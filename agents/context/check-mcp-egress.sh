#!/bin/bash
# check-mcp-egress — PreToolUse hook (matcher `mcp__.*`): MCP tools that can move data off
# this host need the operator's approval for each use (T-5394, G-140).
#
# Origin: 050-email-archive (their T-2570) published the operator's personal data to a
# claude.ai artifact through an MCP publish tool, unasked. Bash send verbs were gated
# (T-2548, Tier 0); MCP tools reached no gate.
#
# The verdict lives in lib/mcp_egress.py (`check`); classification is data in
# policy/mcp-egress.yaml. This wrapper only hands it the payload and FAILS CLOSED: the
# matcher routes only MCP tools here, so anything that goes wrong refuses the call.
#
# Exit: 0 allow, 2 refuse.

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

payload=$(cat 2>/dev/null) || payload=""

if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$FRAMEWORK_ROOT/lib/mcp_egress.py" ]; then
    echo "FW-DENY: mcp-egress (T-5394)" >&2
    echo "BLOCKED: MCP tool refused — the egress gate cannot run (python3 or lib/mcp_egress.py missing); fail closed." >&2
    exit 2
fi

printf '%s' "$payload" | PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" check
rc=$?
[ "$rc" -eq 0 ] && exit 0
if [ "$rc" -ne 2 ]; then
    echo "FW-DENY: mcp-egress (T-5394)" >&2
    echo "BLOCKED: MCP tool refused — the egress gate exited $rc (crash); fail closed." >&2
fi
exit 2
