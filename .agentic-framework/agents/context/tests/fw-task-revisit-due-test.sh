#!/usr/bin/env bash
# fw-task-revisit-due-test.sh — Unit test for T-1453 (CLI wrapper around T-1452 scan)
#
# Creates a sandbox PROJECT_ROOT with one ripe, one future, and one no-revisit
# task, then runs `fw task revisit-due` with PWD inside the sandbox. Asserts:
#   1. Ripe-found path: stdout contains the "Ripe revisits" header AND the ripe T-ID line
#   2. No-ripe path (after removing the ripe task): stdout contains "No revisits due today"
#   3. Exit code 0 in both states

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW="$SCRIPT_DIR/../../../bin/fw"

test -x "$FW" || { echo "FAIL: fw binary not executable at $FW" >&2; exit 1; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working"

cat > "$SANDBOX/.tasks/active/T-9001-ripe.md" <<'EOF'
---
id: T-9001
name: "ripe revisit fixture"
status: started-work
horizon: now
owner: human
revisit_at: 1999-01-01
---
EOF

cat > "$SANDBOX/.tasks/active/T-9002-future.md" <<'EOF'
---
id: T-9002
name: "future revisit fixture"
status: started-work
horizon: now
owner: human
revisit_at: 2099-12-31
---
EOF

cat > "$SANDBOX/.tasks/active/T-9003-no-revisit.md" <<'EOF'
---
id: T-9003
name: "no revisit fixture"
status: started-work
horizon: now
owner: human
---
EOF

# --- Case 1: ripe-found ---
out=$(cd "$SANDBOX" && "$FW" task revisit-due 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL: ripe-found case — non-zero exit code $rc" >&2
    echo "$out" >&2
    exit 1
fi
if ! echo "$out" | grep -q "Ripe revisits"; then
    echo "FAIL: ripe-found case — header 'Ripe revisits' missing" >&2
    echo "$out" >&2
    exit 1
fi
if ! echo "$out" | grep -q "^T-9001 fires 1999-01-01:"; then
    echo "FAIL: ripe-found case — T-9001 line missing or malformed" >&2
    echo "$out" >&2
    exit 1
fi
if echo "$out" | grep -q "T-9002"; then
    echo "FAIL: ripe-found case — T-9002 (future) leaked into output" >&2
    echo "$out" >&2
    exit 1
fi

# --- Case 2: no-ripe ---
rm "$SANDBOX/.tasks/active/T-9001-ripe.md"
out=$(cd "$SANDBOX" && "$FW" task revisit-due 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL: no-ripe case — non-zero exit code $rc" >&2
    echo "$out" >&2
    exit 1
fi
if ! echo "$out" | grep -q "No revisits due today"; then
    echo "FAIL: no-ripe case — 'No revisits due today' message missing" >&2
    echo "$out" >&2
    exit 1
fi

# --- Case 3: verb discoverable in `fw task` help ---
help_out=$(cd "$SANDBOX" && "$FW" task 2>&1)
if ! echo "$help_out" | grep -q "revisit-due"; then
    echo "FAIL: discoverability — 'revisit-due' missing from fw task help" >&2
    echo "$help_out" >&2
    exit 1
fi

echo "PASS: fw task revisit-due — ripe-found, no-ripe, and discoverability cases all green"
exit 0
