#!/bin/bash
# T-1700 ollama-research harness — exercises v1 dispatch substrate end-to-end
# through litellm proxy onto ollama. Used for AC group 4 (empirical validation).
#
# Usage:
#   tools/t1700-ollama-harness.sh [N]
#
# N defaults to 3. Each iteration spawns one TermLink worker via
# `fw termlink dispatch --task-type ollama-research` with a unique tool-use
# prompt, waits for completion, captures exit code + result + latency.
#
# Output: docs/reports/T-1700-harness-results.md (overwritten each run).
#
# Requirements (checked at start, fails loud if missing):
#   - litellm proxy on :4000 (health/liveliness)
#   - ollama @ 192.168.10.107:11434 (api/tags)
#   - .context/project/workflows/ollama-research.yaml exists
#   - termlink binary on PATH
#
# Timeout per worker: 180s. Sequential (not parallel) to avoid overloading
# the single-host ollama. ollama serializes most requests anyway.

set -euo pipefail

cd "$(dirname "$0")/.."
N="${1:-3}"
RESULTS="docs/reports/T-1700-harness-results.md"
BATCH_ID=$(date -u +%Y%m%d-%H%M%S)
WDIR_BASE="/tmp/tl-dispatch"

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
echo "[$(date -u +%H:%M:%S)] T-1700 harness starting (N=$N, batch=$BATCH_ID)"

curl -sf -m 3 http://localhost:4000/health/liveliness >/dev/null || {
  echo "FAIL: litellm proxy not responding on :4000" >&2; exit 1
}
curl -sf -m 5 http://192.168.10.107:11434/api/tags >/dev/null || {
  echo "FAIL: ollama not reachable at 192.168.10.107:11434" >&2; exit 1
}
test -f .context/project/workflows/ollama-research.yaml || {
  echo "FAIL: ollama-research workflow missing" >&2; exit 1
}
command -v termlink >/dev/null || {
  echo "FAIL: termlink binary not on PATH" >&2; exit 1
}
echo "[$(date -u +%H:%M:%S)] Pre-flight OK"

# --- Run dispatches sequentially ---
declare -a EXITS
declare -a LATENCIES
declare -a RESULTS_ARR
declare -a TOOL_USE_COUNTS

for i in "${!PROMPTS[@]}"; do
  N=$((i+1))
  WORKER="t1700-h-$BATCH_ID-$N"
  PROMPT="${PROMPTS[$i]}"

  echo "[$(date -u +%H:%M:%S)] [$N/${#PROMPTS[@]}] Dispatching: ${PROMPT:0:60}..."
  START=$(date +%s)

  bin/fw termlink dispatch \
    --task T-1700 \
    --name "$WORKER" \
    --task-type ollama-research \
    --model claude-3-5-sonnet-20241022 \
    --timeout 180 \
    --env "ANTHROPIC_BASE_URL=http://localhost:4000" \
    --env "ANTHROPIC_API_KEY=sk-litellm-local-dev" \
    --prompt "$PROMPT" >/dev/null 2>&1

  # Wait for completion (poll exit_code file)
  for _ in $(seq 1 90); do
    [ -f "$WDIR_BASE/$WORKER/exit_code" ] && break
    sleep 2
  done

  END=$(date +%s)
  LATENCY=$((END - START))
  LATENCIES+=("$LATENCY")

  if [ -f "$WDIR_BASE/$WORKER/exit_code" ]; then
    EC=$(cat "$WDIR_BASE/$WORKER/exit_code")
    EXITS+=("$EC")
    RES=$(head -c 200 "$WDIR_BASE/$WORKER/result.md" 2>/dev/null || echo "(empty)")
    RESULTS_ARR+=("$RES")
    # T-1700 RCA: exit=0 is NOT a tool-use signal. Count actual tool_use events
    # in the assistant's content blocks. This is the real GO criterion.
    TOOL_USES=$(python3 -c "
import json,sys
try:
    events = [json.loads(l) for l in open('$WDIR_BASE/$WORKER/result.jsonl')]
    n = sum(1 for e in events if e.get('type')=='assistant'
            for c in e.get('message',{}).get('content',[])
            if c.get('type')=='tool_use')
    print(n)
except: print(0)" 2>/dev/null || echo 0)
    TOOL_USE_COUNTS+=("$TOOL_USES")
    echo "[$(date -u +%H:%M:%S)] [$N/${#PROMPTS[@]}] exit=$EC tools=$TOOL_USES latency=${LATENCY}s"
  else
    EXITS+=("TIMEOUT")
    RESULTS_ARR+=("(timeout — no exit_code)")
    TOOL_USE_COUNTS+=(0)
    echo "[$(date -u +%H:%M:%S)] [$N/${#PROMPTS[@]}] TIMEOUT"
  fi
done

# --- Compute stats ---
PASS=0
FAIL=0
TOOL_USE_PASS=0
for i in "${!EXITS[@]}"; do
  ec="${EXITS[$i]}"
  tu="${TOOL_USE_COUNTS[$i]}"
  if [ "$ec" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  # T-1700: real success = exit 0 AND at least one tool call. exit=0 alone is
  # cleanly-hallucinated output. The 90% threshold MUST be measured against
  # this stricter metric.
  if [ "$ec" = "0" ] && [ "$tu" -ge 1 ]; then
    TOOL_USE_PASS=$((TOOL_USE_PASS+1))
  fi
done
TOTAL=${#EXITS[@]}
PCT=$((PASS * 100 / TOTAL))
TOOL_USE_PCT=$((TOOL_USE_PASS * 100 / TOTAL))

# Median latency (sorted middle)
SORTED_LATS=$(printf '%s\n' "${LATENCIES[@]}" | sort -n)
MEDIAN=$(echo "$SORTED_LATS" | awk 'BEGIN{c=0} {a[c++]=$1} END{print (c%2==1) ? a[int(c/2)] : (a[c/2-1]+a[c/2])/2}')
P95_IDX=$(awk "BEGIN{print int(0.95*${TOTAL}-0.5)}")
P95=$(echo "$SORTED_LATS" | sed -n "$((P95_IDX+1))p")

# --- Write results ---
MODEL_USED="${T1700_HARNESS_MODEL:-claude-3-5-sonnet-20241022}"
mkdir -p "$(dirname "$RESULTS")"
{
  echo "# T-1700 — ollama-research harness results"
  echo ""
  echo "**Batch:** \`$BATCH_ID\` &nbsp; **N:** $TOTAL &nbsp; **Model alias:** \`$MODEL_USED\`"
  echo ""
  echo "| Metric | Value | Threshold | Status |"
  echo "|--------|-------|-----------|--------|"
  echo "| **Real tool-use rate** | $TOOL_USE_PASS/$TOTAL ($TOOL_USE_PCT%) | ≥90% | $([ "$TOOL_USE_PCT" -ge 90 ] && echo "✅ MET" || echo "❌ MISSED") |"
  echo "| Exit-code pass | $PASS/$TOTAL ($PCT%) | (informational) | — |"
  echo "| Median latency | ${MEDIAN}s | — | — |"
  echo "| p95 latency | ${P95}s | — | — |"
  echo ""
  echo "**Critical:** \`exit=0\` is NOT a tool-use signal. \`claude -p\` exits cleanly when"
  echo "the model hallucinates an answer instead of calling tools. T-1700 GO requires real"
  echo "tool_use events in the response stream, not just clean exit."
  echo ""
  echo "## Per-dispatch results"
  echo ""
  echo "| # | Exit | Tools called | Latency | Prompt (head) | Result (head) |"
  echo "|---|------|--------------|---------|---------------|---------------|"
  for i in "${!PROMPTS[@]}"; do
    P="${PROMPTS[$i]:0:50}"
    R="${RESULTS_ARR[$i]:0:80}"
    echo "| $((i+1)) | ${EXITS[$i]} | ${TOOL_USE_COUNTS[$i]} | ${LATENCIES[$i]}s | ${P//|/\\|} | ${R//|/\\|} |"
  done
  echo ""
  echo "## Workers"
  echo ""
  for i in "${!PROMPTS[@]}"; do
    echo "- \`$WDIR_BASE/t1700-h-$BATCH_ID-$((i+1))/\`"
  done
  echo ""
  echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} > "$RESULTS"

echo
echo "[$(date -u +%H:%M:%S)] Done. Pass: $PASS/$TOTAL ($PCT%). Median: ${MEDIAN}s. p95: ${P95}s."
echo "Report: $RESULTS"

# Cleanup test workers (keep last batch for forensics)
# Keeping all workers — fw termlink cleanup handles stale ones
true
