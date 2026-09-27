#!/bin/bash
# T-1945 — Heredoc-in-command-substitution edit-time guard.
#
# PreToolUse hook on Write/Edit. When the agent proposes editing
# bin/fw and the proposed content/new_string contains an inline
# `$(... <<TAG ... TAG)` block (or `python3 - <<TAG`), emit a one-line
# stderr warning naming L-332 and L-408 with the canonical fix.
#
# Advisory only — exit 0. The class is a self-lockout failure mode but
# not every heredoc-in-cmd-sub is dangerous (the stable multi-line-clean
# `<<PYEOF\n...\nPYEOF\n)` shape works fine). Blocking would obstruct
# legitimate maintenance edits to an existing heredoc.
#
# Exit codes:
#   0 — always (advisory; warning goes to stderr if pattern detected).
#
# Detection delegated to lib/heredoc_guard.py per L-332 — the bash side
# stays parse-safe and does not consume stdin via heredoc (which would
# starve the JSON pipe).
#
# Part of: Agentic Engineering Framework (P-002 / arc-006 future prevention).
# Originating learnings: L-332 (T-1629, 2026-05-01), L-408 (T-1942, 2026-05-19).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GUARD_HELPER="$FRAMEWORK_ROOT/lib/heredoc_guard.py"

# If the helper is missing on a degraded install, fail open silently.
[ -f "$GUARD_HELPER" ] || exit 0

# Read stdin JSON and let the python helper emit three lines.
RESULT=$(cat | python3 "$GUARD_HELPER" 2>/dev/null)
TOOL_NAME=$(echo "$RESULT" | sed -n '1p')
FILE_PATH=$(echo "$RESULT" | sed -n '2p')
VERDICT=$(echo "$RESULT" | sed -n '3p')

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

case "$FILE_PATH" in
    */bin/fw|bin/fw) ;;
    *) exit 0 ;;
esac

[ "$VERDICT" = "MATCH" ] || exit 0

cat <<'WARN' >&2

[L-332/L-408 GUARD] Proposed edit to bin/fw contains `$(... <<TAG ... TAG)`
(heredoc-in-command-substitution). This is the canonical self-lockout
failure mode: parse errors in bin/fw make every PreToolUse hook reject
all subsequent tool calls — escape requires `git checkout bin/fw` from
a human shell. Class incident count: 3× in 2026-05.

Canonical fix (L-332 prescription):
  • Extract Python >10 lines to a real file under lib/<name>.py.
  • Invoke from bash as: python3 "$FRAMEWORK_ROOT/lib/<name>.py" arg1 arg2
  • Bash side stays parse-safe; warning disappears; single source of truth.

If you have a good reason to keep the heredoc inline (and have run
`bash -n bin/fw` to confirm syntax), this warning is advisory only —
proceed. Otherwise, prefer extraction. See T-1944 for a worked example.

WARN

exit 0
