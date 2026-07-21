#!/bin/bash
# T-1700 ollama-research harness (v2, T-2408) — exercises the v1 dispatch
# substrate end-to-end through `fw resolver run` onto litellm/ollama.
#
# Usage:
#   tools/t1700-ollama-harness.sh [N]
#
# N defaults to 3. Each iteration dispatches one ollama-loop worker via
# `fw resolver run <task> ollama-research --var TASK_DESCRIPTION=...` with a
# unique tool-use prompt, reads the JSON outcome (status / events_path), and
# counts real tool_use events from the events stream.
#
# v2 (T-2408): rerouted from the raw termlink-CLI dispatch path so every run
# lands an envelope row in .context/dispatches.jsonl, and a final
# `fw outcome backprop` appends matching rows to dispatch-outcomes.jsonl —
# closing the T-1697 observability loop. Model / tools / env now come from
# .context/project/workflows/ollama-research.yaml (single source of truth);
# the old T1700_HARNESS_MODEL / T1700_HARNESS_TOOLS knobs are gone — edit the
# workflow YAML to change the probe matrix.
#
#   T1700_HARNESS_TASK — task ID the dispatches are tagged with (default T-1700)
#
# Output: docs/reports/T-1700-harness-results.md (overwritten each run).
#
# Requirements (checked at start, fails loud if missing):
#   - litellm proxy on :4000 (health/liveliness)
#   - ollama @ 192.168.10.107:11434 (api/tags)
#   - .context/project/workflows/ollama-research.yaml exists
#   - claude binary on PATH (ollama-loop worker_kind spawns `claude -p`)
#
# Sequential (not parallel) to avoid overloading the single-host ollama.

set -euo pipefail

cd "$(dirname "$0")/.."
N="${1:-3}"
RESULTS="docs/reports/T-1700-harness-results.md"
BATCH_ID=$(date -u +%Y%m%d-%H%M%S)
HTASK="${T1700_HARNESS_TASK:-T-1700}"

# 10 tool-use prompts varying difficulty + tool mix
PROMPTS=(
  "Use Read to read /etc/hostname, then state the hostname in one sentence. /no_think"
  "Use Bash to run 'date -u +%Y-%m-%d', then report today's date. /no_think"
  "Use Read to read VERSION, then state the version number. /no_think"
  "Use Bash to run 'uname -m', then state the architecture. /no_think"
  "Use Read to read /proc/version, then state the kernel version in one sentence. /no_think"
  "Use Bash to count files in /etc with 'ls /etc | wc -l', then report the count. /no_think"
  "Use Read to read /etc/os-release, then identify the OS family. /no_think"
  "Use Bash to run 'whoami' and state the user. /no_think"
  "Use Grep to find lines containing 'task_type' in lib/resolver.py, count them, report the count. /no_think"
  "Use Bash to run 'echo \$PWD' and report the working directory. /no_think"
)

# Take first N prompts
PROMPTS=("${PROMPTS[@]:0:$N}")

# --- Pre-flight checks ---
echo "[$(date -u +%H:%M:%S)] T-1700 harness v2 starting (N=$N, batch=$BATCH_ID, task=$HTASK)"

curl -sf -m 3 http://localhost:4000/health/liveliness >/dev/null || {
  echo "FAIL: litellm proxy not responding on :4000" >&2; exit 1
}
curl -sf -m 5 http://192.168.10.107:11434/api/tags >/dev/null || {
  echo "FAIL: ollama not reachable at 192.168.10.107:11434" >&2; exit 1
}
test -f .context/project/workflows/ollama-research.yaml || {
  echo "FAIL: ollama-research workflow missing" >&2; exit 1
}
command -v claude >/dev/null || {
  echo "FAIL: claude binary not on PATH (ollama-loop spawns claude -p)" >&2; exit 1
}
echo "[$(date -u +%H:%M:%S)] Pre-flight OK"

# --- Run dispatches sequentially via fw resolver run (T-2408) ---
declare -a STATUSES
declare -a LATENCIES
declare -a RESULTS_ARR
declare -a TOOL_USE_COUNTS
declare -a DISPATCH_IDS
declare -a EVENTS_PATHS

for i in "${!PROMPTS[@]}"; do
  IDX=$((i+1))
  PROMPT="${PROMPTS[$i]}"

  echo "[$(date -u +%H:%M:%S)] [$IDX/${#PROMPTS[@]}] Dispatching: ${PROMPT:0:60}..."
  START=$(date +%s)

  # resolver run exit codes: 0 ok, 1 infra error, 2 worker terminal error.
  # All three still produce a JSON outcome on stdout when the resolver got far
  # enough to spawn; capture regardless and parse what we got.
  RC=0
  OUTCOME_JSON=$(bin/fw resolver run "$HTASK" ollama-research \
    --var TASK_DESCRIPTION="$PROMPT" --json 2>/dev/null) || RC=$?

  END=$(date +%s)
  LATENCY=$((END - START))
  LATENCIES+=("$LATENCY")

  if [ -n "$OUTCOME_JSON" ]; then
    read -r STATUS EVENTS_PATH RESULT_HEAD < <(python3 -c "
import json, sys
try:
    o = json.loads(sys.argv[1])
except Exception:
    print('parse-error - -'); raise SystemExit
te = o.get('terminal_event') or {}
head = str(te.get('result', ''))[:80].replace(chr(10), ' ') or '-'
print(o.get('status', 'unknown'), o.get('events_path', '-'), head)
" "$OUTCOME_JSON")
    STATUSES+=("$STATUS")
    EVENTS_PATHS+=("$EVENTS_PATH")
    RESULTS_ARR+=("$RESULT_HEAD")
    # T-1700 RCA: clean completion is NOT a tool-use signal. Count actual
    # tool_use events in the assistant content blocks of the events stream.
    # This is the real GO criterion. (T-2408: reads resolver events_path —
    # no more orphan exit_code polling.)
    TOOL_USES=$(python3 -c "
import json, sys
try:
    events = [json.loads(l) for l in open('$EVENTS_PATH') if l.strip()]
    n = sum(1 for e in events if e.get('type')=='assistant'
            for c in e.get('message',{}).get('content',[])
            if isinstance(c, dict) and c.get('type')=='tool_use')
    print(n)
except Exception: print(0)" 2>/dev/null || echo 0)
    TOOL_USE_COUNTS+=("$TOOL_USES")
    echo "[$(date -u +%H:%M:%S)] [$IDX/${#PROMPTS[@]}] status=$STATUS tools=$TOOL_USES latency=${LATENCY}s (rc=$RC)"
  else
    STATUSES+=("spawn-failed")
    EVENTS_PATHS+=("-")
    RESULTS_ARR+=("(no outcome JSON — rc=$RC)")
    TOOL_USE_COUNTS+=(0)
    echo "[$(date -u +%H:%M:%S)] [$IDX/${#PROMPTS[@]}] SPAWN FAILED (rc=$RC)"
  fi
done

# Dispatch ids for this task (tail = this batch's rows, newest last)
mapfile -t DISPATCH_IDS < <(python3 -c "
import json
rows = []
try:
    for l in open('.context/dispatches.jsonl'):
        l = l.strip()
        if not l: continue
        try: r = json.loads(l)
        except Exception: continue
        if r.get('task_id') == '$HTASK' and r.get('dispatch_id'):
            rows.append(r['dispatch_id'])
except OSError: pass
for d in rows[-${#PROMPTS[@]}:]: print(d)")

# --- Compute stats ---
PASS=0
FAIL=0
TOOL_USE_PASS=0
for i in "${!STATUSES[@]}"; do
  st="${STATUSES[$i]}"
  tu="${TOOL_USE_COUNTS[$i]}"
  # lib/spawn.py outcome status vocabulary is "success" | "error"
  if [ "$st" = "success" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  # T-1700: real success = clean completion AND at least one tool call.
  # Clean completion alone is cleanly-hallucinated output. The 90% threshold
  # MUST be measured against this stricter metric.
  if [ "$st" = "success" ] && [ "$tu" -ge 1 ]; then
    TOOL_USE_PASS=$((TOOL_USE_PASS+1))
  fi
done
TOTAL=${#STATUSES[@]}
PCT=$((PASS * 100 / TOTAL))
TOOL_USE_PCT=$((TOOL_USE_PASS * 100 / TOTAL))

# Median latency (sorted middle)
SORTED_LATS=$(printf '%s\n' "${LATENCIES[@]}" | sort -n)
MEDIAN=$(echo "$SORTED_LATS" | awk 'BEGIN{c=0} {a[c++]=$1} END{print (c%2==1) ? a[int(c/2)] : (a[c/2-1]+a[c/2])/2}')
P95_IDX=$(awk "BEGIN{print int(0.95*${TOTAL}-0.5)}")
P95=$(echo "$SORTED_LATS" | sed -n "$((P95_IDX+1))p")

# --- Backprop outcomes (T-2408: close the T-1697 observability loop) ---
echo "[$(date -u +%H:%M:%S)] Backprop: fw outcome backprop $HTASK"
BACKPROP_OUT=$(bin/fw outcome backprop "$HTASK" 2>&1 || true)
BACKPROP_N=$(echo "$BACKPROP_OUT" | grep -oE 'outcomes appended:\s+[0-9]+' | grep -oE '[0-9]+' || echo 0)
echo "$BACKPROP_OUT" | sed 's/^/  /'

# --- Write results ---
WORKFLOW_MODEL=$(grep -E '^model:' .context/project/workflows/ollama-research.yaml | awk '{print $2}')
{
  echo "# T-1700 — ollama-research harness results (v2, resolver-run substrate)"
  echo ""
  echo "**Batch:** \`$BATCH_ID\` &nbsp; **N:** $TOTAL &nbsp; **Task:** \`$HTASK\` &nbsp; **Model (workflow):** \`$WORKFLOW_MODEL\`"
  echo ""
  echo "| Metric | Value | Threshold | Status |"
  echo "|--------|-------|-----------|--------|"
  echo "| **Real tool-use rate** | $TOOL_USE_PASS/$TOTAL ($TOOL_USE_PCT%) | ≥90% | $([ "$TOOL_USE_PCT" -ge 90 ] && echo "✅ MET" || echo "❌ MISSED") |"
  echo "| Completed status | $PASS/$TOTAL ($PCT%) | (informational) | — |"
  echo "| Median latency | ${MEDIAN}s | — | — |"
  echo "| p95 latency | ${P95}s | — | — |"
  echo "| Outcome rows backpropped | $BACKPROP_N | ≥$TOTAL | $([ "$BACKPROP_N" -ge "$TOTAL" ] && echo "✅" || echo "❌") |"
  echo ""
  echo "**Critical:** clean completion is NOT a tool-use signal. The worker completes"
  echo "cleanly when the model hallucinates an answer instead of calling tools. T-1700 GO"
  echo "requires real tool_use events in the events stream, not just clean completion."
  echo ""
  echo "**v2 (T-2408):** dispatches route through \`fw resolver run $HTASK ollama-research\`;"
  echo "envelope rows land in \`.context/dispatches.jsonl\`; \`fw outcome backprop\` appends"
  echo "matching rows to \`.context/dispatch-outcomes.jsonl\`."
  echo ""
  echo "## Per-dispatch results"
  echo ""
  echo "| # | Status | Tools called | Latency | Prompt (head) | Result (head) |"
  echo "|---|--------|--------------|---------|---------------|---------------|"
  for i in "${!PROMPTS[@]}"; do
    P="${PROMPTS[$i]:0:50}"
    R="${RESULTS_ARR[$i]:0:80}"
    echo "| $((i+1)) | ${STATUSES[$i]} | ${TOOL_USE_COUNTS[$i]} | ${LATENCIES[$i]}s | ${P//|/\\|} | ${R//|/\\|} |"
  done
  echo ""
  echo "## Dispatches (this batch, from .context/dispatches.jsonl)"
  echo ""
  if [ "${#DISPATCH_IDS[@]}" -gt 0 ]; then
    for d in "${DISPATCH_IDS[@]}"; do
      echo "- \`$d\` — forensics: \`fw resolver explain $d\` / merged view: \`fw outcome read $d\`"
    done
  else
    echo "- (none found for $HTASK — dispatches.jsonl emit missing?)"
  fi
  echo ""
  echo "## Events streams"
  echo ""
  for i in "${!PROMPTS[@]}"; do
    echo "- \`${EVENTS_PATHS[$i]}\`"
  done
  echo ""
  echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} > "$RESULTS"

echo
echo "[$(date -u +%H:%M:%S)] Done. Completed: $PASS/$TOTAL ($PCT%). Real tool-use: $TOOL_USE_PASS/$TOTAL. Backprop rows: $BACKPROP_N. Median: ${MEDIAN}s."
echo "Report: $RESULTS"
