#!/bin/bash
# T-2908: PreToolUse label gate for the MCP rail-post producer surface.
#
# T-2904/T-2905 put an identity guard and an auto-attached from_project label
# inside `do_rail post` (bin/fw / lib/rail-identity.sh). The class was reported
# closed. It wasn't: `mcp__termlink__termlink_channel_post` reaches the SAME
# topics with neither gate in scope, because both live in OUR shell wrapper and
# an MCP tool call never runs it — Claude Code calls termlink's MCP server
# directly with whatever `metadata` the caller supplied.
#
# SCOPE: this hook enforces the LABEL only, not the identity.
#
# The label is a per-call JSON field (`tool_input.metadata.from_project`) — a
# PreToolUse hook can inspect and block it, exactly like any other tool_input
# check in this repo (see check-tier0.sh, check-arc-id.py). That is prevention,
# reachable and shipped here.
#
# The IDENTITY is not: termlink's MCP server resolves its signing key ONCE, at
# process start, from an environment this hook does not control and cannot
# re-introspect per call — the server was already running before this hook
# ever fires. T-2908 measured this surface signing with a non-host key at one
# point in time (mcp__termlink__termlink_channel_post -> 0e7ee6cad65137fc, vs.
# the shell surface's d1993c2c3ec44c94), but termlink's internal resolution
# logic is out of this project's boundary (T-559) and was not, and could not
# safely be, re-derived by reusing lib/rail-identity.sh's rail_identity_guard
# here: that function shells out to a FRESH `termlink agent identity --resolve`
# call, which reflects what a hook subprocess would sign as right now, not
# what the already-running MCP server process actually signed the call with.
# Reusing it would be a plausible-looking check with no verified relationship
# to the surface it claims to guard — worse than not checking at all. So: for
# identity, this hook does DETECTION-by-documentation (this comment + the
# block message below), not prevention. Re-verify with `bin/fw rail identity`
# whenever this surface's attribution matters.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — allow
#   2 — block (stderr shown to agent)
#
# Bypass: mcp__termlink__termlink_channel_post has no command-line surface a
# flag or an env-var prefix could reach (the call is a direct tool invocation,
# not a shell command this hook's own env wraps) — so unlike
# FW_ALLOW_HOST_SIGNED_RAIL (T-2904), the bypass here is a one-shot file token:
# `bin/fw rail allow-unlabeled-mcp` arms it, this hook consumes (deletes) it on
# first use and logs Tier-2 to .gate-bypass-log.yaml. TTL default 300s
# (FW_RAIL_MCP_BYPASS_TTL) so a stale token from an earlier session cannot
# silently authorise a later, unrelated call.
#
# Part of: Agentic Engineering Framework (T-2908, L-399/L-572 parity leg).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
source "$FRAMEWORK_ROOT/lib/rail-identity.sh"
fw_hook_crash_trap "check-rail-mcp-label"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)

[ "$TOOL_NAME" = "mcp__termlink__termlink_channel_post" ] || exit 0

FROM_PROJECT=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {}) or {}
    md = ti.get('metadata', {}) or {}
    print(md.get('from_project', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -n "$FROM_PROJECT" ] && exit 0

# ── one-shot bypass token ─────────────────────────────────────────────────
BYPASS_FILE="${PROJECT_ROOT:-$PWD}/.context/working/.rail-mcp-label-bypass"
BYPASS_TTL="${FW_RAIL_MCP_BYPASS_TTL:-300}"

if [ -f "$BYPASS_FILE" ]; then
    _bp_ts="$(head -1 "$BYPASS_FILE" 2>/dev/null)"
    rm -f "$BYPASS_FILE" 2>/dev/null || true  # one-shot: consumed either way
    _now="$(date +%s)"
    if [ -n "$_bp_ts" ] && [ "$_bp_ts" -eq "$_bp_ts" ] 2>/dev/null \
        && [ $(( _now - _bp_ts )) -le "$BYPASS_TTL" ]; then
        _rail_log_bypass "mcp__termlink__termlink_channel_post (unlabeled, via allow-unlabeled-mcp token)" "rail-mcp-label" "allow-unlabeled-mcp token"
        exit 0
    fi
fi

LABEL="$(rail_project_label)"
cat >&2 <<EOF
BLOCKED: this MCP rail post has no from_project metadata.

'fw rail post' auto-attaches this label (T-2905); the MCP tool
(mcp__termlink__termlink_channel_post) is a second producer to the same rail
that skips it — the label is injected by our shell wrapper, and an MCP call
never runs that code path. Measured (T-2908): the MCP surface reaches the
same topics as 'fw rail post' with neither gate in scope.

Fix (pick one):

  1. Retry the call with the canonical label in metadata:
       metadata: {..., "from_project": "$LABEL"}

  2. Post anyway, accepting no label (logged Tier-2):
       bin/fw rail allow-unlabeled-mcp
     then retry the SAME call once, within ${BYPASS_TTL}s.

NOTE on identity: this hook enforces the LABEL only. The MCP surface's
signing identity is not re-verified per call — termlink's MCP server
resolves its key once, at process start, in an environment this hook cannot
re-introspect. T-2908 measured this surface signing with a project key at one
point in time; that is an observation, not a structural guarantee. Re-check
with 'bin/fw rail identity' if you depend on this surface's attribution.
EOF
exit 2
