#!/bin/bash
# agents/audit/node1-nightly.sh — T-5392: nightly unit-suite run on node1 (ring20's pool).
#
# Builds and stages the unit-suite bundle of HEAD, submits every node1-compatible unit
# test file (agents/audit/node1-incompatible.txt lists the rest), holds while node1's
# feed health is not healthy, collects the results and writes
# .context/audits/unit-suite/node1/<date>.yaml + LATEST.yaml. Logic: node1_nightly.py.
#
#   agents/audit/node1-nightly.sh --dry-run          list what would be sent (no network)
#   agents/audit/node1-nightly.sh --health           node1's feed health only
#   agents/audit/node1-nightly.sh --limit 20         a small real run
#   agents/audit/node1-nightly.sh                    the nightly run (cron: node1-unit-suite-nightly)
#
# Overlap: a run can take most of a day (node1 is ~3x slower per core); the next night's
# run skips, logged, while one holds the lock.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
export FRAMEWORK_ROOT PROJECT_ROOT

for a in "$@"; do
    case "$a" in
        --dry-run|--health|-h|--help) exec python3 -I "$SCRIPT_DIR/node1_nightly.py" "$@" ;;
    esac
done

REPORT_DIR="$PROJECT_ROOT/.context/audits/unit-suite/node1"
LOCK_FILE="$PROJECT_ROOT/.context/locks/node1-nightly.lock"
mkdir -p "$REPORT_DIR" "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "$(date -u +%FT%TZ) SKIP lock-held $LOCK_FILE" >> "$REPORT_DIR/runs.log"
    echo "node1-nightly: another run holds $LOCK_FILE; skipping"
    exit 0
fi
cd "$PROJECT_ROOT" || exit 2
python3 -I "$SCRIPT_DIR/node1_nightly.py" "$@"
