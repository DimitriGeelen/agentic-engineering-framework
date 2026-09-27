#!/usr/bin/env bash
# revisit-due-scan-test.sh — Unit test for T-1452 / G-053
#
# Creates a sandbox PROJECT_ROOT with two mock tasks (one ripe, one future)
# plus one without revisit_at, runs the scanner, asserts only the ripe task
# appears in the output file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$SCRIPT_DIR/../revisit-due-scan.sh"

test -x "$SCAN" || { echo "FAIL: scanner not executable: $SCAN" >&2; exit 1; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working"

# Ripe task
cat > "$SANDBOX/.tasks/active/T-9001-ripe.md" <<'EOF'
---
id: T-9001
name: "ripe revisit"
status: started-work
horizon: now
owner: human
revisit_at: 1999-01-01
---
EOF

# Future task
cat > "$SANDBOX/.tasks/active/T-9002-future.md" <<'EOF'
---
id: T-9002
name: "future revisit"
status: started-work
horizon: now
owner: human
revisit_at: 2099-12-31
---
EOF

# No revisit_at
cat > "$SANDBOX/.tasks/active/T-9003-neither.md" <<'EOF'
---
id: T-9003
name: "no revisit"
status: started-work
horizon: now
owner: human
---
EOF

# Commented hint only (must be ignored — should be the template default state)
cat > "$SANDBOX/.tasks/active/T-9004-commented.md" <<'EOF'
---
id: T-9004
name: "commented hint"
status: started-work
horizon: now
owner: human
# revisit_at: YYYY-MM-DD          # T-1451 hint
# revisit_evidence_needed:        # T-1451 hint
---
EOF

PROJECT_ROOT="$SANDBOX" "$SCAN"

OUT="$SANDBOX/.context/working/.revisits-due.txt"

if [ ! -f "$OUT" ]; then
    echo "FAIL: output file missing — expected T-9001 to be ripe" >&2
    exit 1
fi

if ! grep -q "^T-9001 fires 1999-01-01:" "$OUT"; then
    echo "FAIL: T-9001 (ripe) not in output:" >&2
    cat "$OUT" >&2
    exit 1
fi

if grep -q "T-9002" "$OUT"; then
    echo "FAIL: T-9002 (future) leaked into output:" >&2
    cat "$OUT" >&2
    exit 1
fi

if grep -q "T-9003\|T-9004" "$OUT"; then
    echo "FAIL: T-9003 or T-9004 (no real revisit_at) leaked into output:" >&2
    cat "$OUT" >&2
    exit 1
fi

# Now test the "no ripe" case: remove the ripe task, re-run, assert file is removed
rm "$SANDBOX/.tasks/active/T-9001-ripe.md"
PROJECT_ROOT="$SANDBOX" "$SCAN"

if [ -e "$OUT" ]; then
    echo "FAIL: output file should be removed when nothing is ripe; still exists:" >&2
    cat "$OUT" >&2
    exit 1
fi

echo "PASS: revisit-due-scan correctly classifies ripe vs future, ignores commented hints, removes output when empty"
exit 0
