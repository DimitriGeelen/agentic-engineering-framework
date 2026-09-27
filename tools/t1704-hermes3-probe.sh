#!/bin/bash
# T-1704 hermes3:8b probe — same matrix shape as T-1703, single model.
# hermes3 is Nous Research's function-calling-tuned line; the v3 hypothesis
# is that explicit tool-call training fixes what catalogue restriction
# couldn't. 3 cells × N=3 = 9 dispatches.
#
# Output: docs/reports/T-1704-hermes3-probe.md
# Usage: tools/t1704-hermes3-probe.sh [N_per_cell]   (default 3)

set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-3}"
REPORT="docs/reports/T-1704-hermes3-probe.md"
BATCH=$(date -u +%Y%m%d-%H%M%S)
WDIR_BASE="/tmp/tl-dispatch"

PROMPTS=(
  "Use the Read tool to read /etc/hostname, then state the hostname in one sentence. /no_think"
  "Use the Read tool to read VERSION, then state the version number. /no_think"
  "Use the Read tool to read /etc/os-release, then identify the OS family in one sentence. /no_think"
)
PROMPTS=("${PROMPTS[@]:0:$N}")

declare -a CELLS=(
  "hermes3|claude-3-5-sonnet-hermes3|"
  "hermes3|claude-3-5-sonnet-hermes3|Read,Bash,Grep"
  "hermes3|claude-3-5-sonnet-hermes3|Read"
)

curl -sf -m 3 http://localhost:4000/health/liveliness >/dev/null || { echo "FAIL: litellm proxy down"; exit 1; }
curl -sf -m 5 http://192.168.10.107:11434/api/tags >/dev/null || { echo "FAIL: ollama unreachable"; exit 1; }
curl -sf http://192.168.10.107:11434/api/tags | python3 -c "
import json,sys
d=json.load(sys.stdin)
names=[m['name'] for m in d.get('models',[])]
sys.exit(0 if 'hermes3:8b' in names else 1)" || { echo "FAIL: hermes3:8b not loaded"; exit 1; }

declare -a CELL_NAMES TOOL_PCT_LIST EXIT_PCT_LIST MEDIAN_LIST DETAIL_LINES SAMPLE_OUTS

run_cell() {
  local name="$1" model="$2" tools="$3" idx="$4"
  local pass=0 tu_pass=0
  local -a lats=()
  echo "[$(date -u +%H:%M:%S)] cell $idx: $name | tools=${tools:-WIDE} | N=$N"

  for i in "${!PROMPTS[@]}"; do
    local n=$((i+1))
    local worker="t1704-${BATCH}-c${idx}-p${n}"
    local prompt="${PROMPTS[$i]}"
    local tools_arg=()
    [ -n "$tools" ] && tools_arg=(--tools "$tools")
    local start=$(date +%s)

    bin/fw termlink dispatch \
      --task T-1704 --name "$worker" --task-type ollama-research \
      --model "$model" --timeout 120 \
      --env "ANTHROPIC_BASE_URL=http://localhost:4000" \
      --env "ANTHROPIC_API_KEY=sk-litellm-local-dev" \
      "${tools_arg[@]}" \
      --prompt "$prompt" >/dev/null 2>&1

    for _ in $(seq 1 70); do [ -f "$WDIR_BASE/$worker/exit_code" ] && break; sleep 2; done
    local end=$(date +%s); local lat=$((end-start)); lats+=("$lat")

    local ec="TIMEOUT"
    [ -f "$WDIR_BASE/$worker/exit_code" ] && ec=$(cat "$WDIR_BASE/$worker/exit_code")
    local tu=0
    if [ -f "$WDIR_BASE/$worker/result.jsonl" ]; then
      tu=$(python3 -c "
import json
try:
    events=[json.loads(l) for l in open('$WDIR_BASE/$worker/result.jsonl')]
    print(sum(1 for e in events if e.get('type')=='assistant'
              for c in e.get('message',{}).get('content',[])
              if c.get('type')=='tool_use'))
except: print(0)" 2>/dev/null || echo 0)
    fi
    [ "$ec" = "0" ] && pass=$((pass+1))
    [ "$ec" = "0" ] && [ "$tu" -ge 1 ] && tu_pass=$((tu_pass+1))
    DETAIL_LINES+=("| $idx | \`${tools:-WIDE}\` | $n | $ec | $tu | ${lat}s |")
    if [ "$n" = "1" ] && [ -f "$WDIR_BASE/$worker/result.md" ]; then
      local sample=$(head -c 200 "$WDIR_BASE/$worker/result.md" | tr '\n' ' ' | sed 's/|/\\|/g')
      SAMPLE_OUTS+=("| \`${tools:-WIDE}\` | $tu | ${sample:0:180} |")
    fi
    echo "  [$n/$N] exit=$ec tools=$tu lat=${lat}s"
  done

  local total="${#PROMPTS[@]}"
  local tool_pct=$((tu_pass * 100 / total))
  local exit_pct=$((pass * 100 / total))
  local median=$(printf '%s\n' "${lats[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2==1)?a[int(NR/2)+1]:(a[NR/2]+a[NR/2+1])/2}')
  CELL_NAMES+=("\`${tools:-WIDE}\`")
  TOOL_PCT_LIST+=("$tool_pct")
  EXIT_PCT_LIST+=("$exit_pct")
  MEDIAN_LIST+=("$median")
}

idx=1
for cell in "${CELLS[@]}"; do
  IFS='|' read -r name model tools <<<"$cell"
  run_cell "$name" "$model" "$tools" "$idx"
  idx=$((idx+1))
done

best_idx=-1
best_pct=0
for i in "${!TOOL_PCT_LIST[@]}"; do
  pct=${TOOL_PCT_LIST[$i]}
  if [ "$pct" -gt "$best_pct" ]; then best_pct=$pct; best_idx=$i; fi
done

if [ "$best_pct" -ge 90 ]; then
  CONCLUSION="WINNER: ${CELL_NAMES[$best_idx]} — ${best_pct}% real tool-use"
elif [ "$best_pct" -gt 0 ]; then
  CONCLUSION="Partial: best cell ${CELL_NAMES[$best_idx]} — ${best_pct}% (below 90%)"
else
  CONCLUSION="Negative: all cells 0% — function-calling tuning alone is not sufficient"
fi

{
  echo "# T-1704 — hermes3:8b function-calling probe"
  echo ""
  echo "**Batch:** \`$BATCH\` &nbsp; **N per cell:** $N &nbsp; **Total:** $((${#CELLS[@]} * N))"
  echo "**Model:** \`hermes3:8b\` (Nous Research, function-calling-tuned)"
  echo ""
  echo "## Bottom line"
  echo ""
  if [ "$best_pct" -ge 90 ]; then
    echo "**WINNER:** ${CELL_NAMES[$best_idx]} hit ${best_pct}% real tool-use ✅"
    echo ""
    echo "Action: update \`.context/project/workflows/ollama-research.yaml\` to use this"
    echo "model alias + tool restriction. T-1700 v2 path resolved with a single model pull."
  elif [ "$best_pct" -gt 0 ]; then
    echo "**Partial:** best cell ${CELL_NAMES[$best_idx]} = ${best_pct}%. Below 90% threshold."
    echo ""
    echo "Function-calling tuning produces SOME tool_use events but not reliably enough"
    echo "for ollama-research to ship as default. Direction is right; magnitude insufficient."
    echo "Pivot options: try xlam:7b OR claude-code-router OR pull a 14B+ tool-tuned model."
  else
    echo "**Negative:** all cells 0%."
    echo ""
    echo "Even an explicitly function-calling-tuned 8B model fails on claude -p's wide"
    echo "prompt. Strong evidence that the bottleneck is not model tuning alone — claude -p's"
    echo "prompt format itself may be incompatible with non-Anthropic models. Pivot to"
    echo "claude-code-router or accept text-only ollama-research as the v1 ceiling."
  fi
  echo ""
  echo "## Probe matrix"
  echo ""
  echo "| Cell | Tool catalogue | Real tool-use | Exit-code pass | Median latency |"
  echo "|------|----------------|---------------|----------------|----------------|"
  for i in "${!CELL_NAMES[@]}"; do
    pct="${TOOL_PCT_LIST[$i]}"
    if [ "$pct" -ge 90 ]; then status=" ✅"; elif [ "$pct" -gt 0 ]; then status=" ⚠️"; else status=" ❌"; fi
    echo "| $((i+1)) | ${CELL_NAMES[$i]} | $pct%$status | ${EXIT_PCT_LIST[$i]}% | ${MEDIAN_LIST[$i]}s |"
  done
  echo ""
  echo "## Per-dispatch detail"
  echo ""
  echo "| Cell | Tools | # | Exit | Tool calls | Latency |"
  echo "|------|-------|---|------|------------|---------|"
  printf '%s\n' "${DETAIL_LINES[@]}"
  echo ""
  echo "## Sample outputs (prompt 1 per cell)"
  echo ""
  echo "| Catalogue | Tool calls | Output (truncated 180c) |"
  echo "|-----------|------------|-------------------------|"
  printf '%s\n' "${SAMPLE_OUTS[@]}"
  echo ""
  echo "## Comparison vs T-1703 (gemma4 + qwen3.5)"
  echo ""
  echo "T-1703 result on identical prompts: 0/18 across 6 cells (0%)."
  echo "T-1704 hermes3:8b best cell: ${best_pct}%."
  if [ "$best_pct" -gt 0 ]; then
    echo ""
    echo "Function-calling tuning DOES change behaviour on this prompt class."
  else
    echo ""
    echo "Function-calling tuning alone does not change behaviour on claude -p's prompt."
    echo "The bottleneck is upstream of the model — claude -p's prompt may not coax the"
    echo "format even from a function-calling-tuned model."
  fi
  echo ""
  echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} > "$REPORT"

echo
echo "[$(date -u +%H:%M:%S)] Done. Report: $REPORT"
echo "$CONCLUSION"
