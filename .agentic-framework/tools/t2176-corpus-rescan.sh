#!/bin/bash
# T-2176: Fresh fw reviewer scan over .tasks/completed/ to refresh stale verdict cache.
# Writes back ## Reviewer Verdict block per task; logs JSON per task; aggregates FAIL list.
#
# Output:
#   .context/working/t2176-rescan-progress.log  — running progress (one line per task)
#   .context/working/t2176-rescan-verdicts.jsonl — one JSON per task (--no-write JSON dump)
#   .context/working/t2176-rescan-summary.yaml  — aggregate totals + per-pattern counts
#
# Runs reviewer twice per task in --no-write mode:
#   - Pass A: JSON capture for analysis
#   - Pass B: write-back so AC#1 (1900+ Scan ID lines) is satisfied
# The two passes are necessary because --no-write skips file mutation entirely.

set -euo pipefail

WORKDIR="/opt/999-Agentic-Engineering-Framework"
cd "$WORKDIR"

PROGRESS=".context/working/t2176-rescan-progress.log"
JSONL=".context/working/t2176-rescan-verdicts.jsonl"
SUMMARY=".context/working/t2176-rescan-summary.yaml"

: > "$PROGRESS"
: > "$JSONL"

n=0
n_fail=0
n_concern=0
n_pass=0
n_error=0
start_ts=$(date +%s)

for f in .tasks/completed/T-*.md; do
  tid=$(grep -m1 "^id:" "$f" | awk '{print $2}')
  [ -z "$tid" ] && continue

  n=$((n + 1))

  # Pass A: JSON for analysis (no file mutation)
  if json=$(bin/fw reviewer "$tid" --no-write --json 2>/dev/null); then
    echo "$json" >> "$JSONL"
    verdict=$(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('overall','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  else
    verdict="ERROR"
    n_error=$((n_error + 1))
    # Emit placeholder line so jsonl line count matches scan attempts
    echo "{\"task_id\":\"$tid\",\"overall\":\"ERROR\"}" >> "$JSONL"
  fi

  case "$verdict" in
    FAIL) n_fail=$((n_fail + 1)) ;;
    CONCERN) n_concern=$((n_concern + 1)) ;;
    PASS) n_pass=$((n_pass + 1)) ;;
  esac

  # Pass B: write-back verdict block to task file
  if [ "$verdict" != "ERROR" ]; then
    bin/fw reviewer "$tid" >/dev/null 2>&1 || true
  fi

  if [ $((n % 50)) -eq 0 ]; then
    el=$(( $(date +%s) - start_ts ))
    echo "[$n/$el s] PASS=$n_pass CONCERN=$n_concern FAIL=$n_fail ERR=$n_error  last=$tid" >> "$PROGRESS"
  fi
done

end_ts=$(date +%s)
elapsed=$((end_ts - start_ts))

cat > "$SUMMARY" <<EOF
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
elapsed_seconds: $elapsed
totals:
  scanned: $n
  PASS: $n_pass
  CONCERN: $n_concern
  FAIL: $n_fail
  ERROR: $n_error
EOF

echo "[done] $n scanned in $elapsed s — PASS=$n_pass CONCERN=$n_concern FAIL=$n_fail ERR=$n_error" >> "$PROGRESS"
echo "$SUMMARY"
