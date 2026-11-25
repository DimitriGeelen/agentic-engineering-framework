#!/bin/bash
# scripts/node1/node1-nightly.sh — T-5392: nightly unit-suite run on node1 (ring20's pool).
#
# Builds and stages the unit-suite bundle of HEAD, submits every node1-compatible unit
# test file (scripts/node1/node1-incompatible.txt lists the rest), holds while node1's
# feed health is not healthy, collects the results and writes
# .context/audits/unit-suite/node1/<date>.yaml + LATEST.yaml. Logic: node1_nightly.py.
#
#   scripts/node1/node1-nightly.sh --dry-run          list what would be sent (no network)
#   scripts/node1/node1-nightly.sh --health           node1's feed health only
#   scripts/node1/node1-nightly.sh --limit 20         a small real run
#   scripts/node1/node1-nightly.sh                    the nightly run (cron: node1-unit-suite-nightly)
#   scripts/node1/node1-nightly.sh --repin            OPERATOR ONLY: pin the pool client's new sha256 (T-5410)
#
# This project's ring20 adapter: scripts/ is not shipped by `fw vendor`, so it never
# reaches a consumer. Exit codes: node1_nightly.py (3 = incomplete, never green).
#
# Overlap: a run can take most of a day (node1 is ~3x slower per core); the next night's
# run skips, logged, while one holds the lock.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"   # scripts/node1 → repo root
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
export FRAMEWORK_ROOT PROJECT_ROOT

for a in "$@"; do
    case "$a" in
        --dry-run|--health|--repin|-h|--help) exec python3 -I "$SCRIPT_DIR/node1_nightly.py" "$@" ;;
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
