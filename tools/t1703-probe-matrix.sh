#!/bin/bash
# T-1703 probe matrix — gemma4 + qwen3.5 against 3 tool catalogues.
# Uses simple-read prompts only (Read tool sufficient) so the Read-only
# catalogue cell isn't penalised for prompts that need Bash.
#
# Output: docs/reports/T-1703-curated-catalogue-probe.md
#
# Usage: tools/t1703-probe-matrix.sh [N_per_cell]   (default 3)

set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-3}"
REPORT="docs/reports/T-1703-curated-catalogue-probe.md"
BATCH=$(date -u +%Y%m%d-%H%M%S)
WDIR_BASE="/tmp/tl-dispatch"

# Simple-read prompts (Read tool alone is sufficient for all)
PROMPTS=(
  "Use the Read tool to read /etc/hostname, then state the hostname in one sentence. /no_think"
  "Use the Read tool to read VERSION, then state the version number. /no_think"
  "Use the Read tool to read /etc/os-release, then identify the OS family in one sentence. /no_think"
)
PROMPTS=("${PROMPTS[@]:0:$N}")

# Probe cells: model × tool catalogue
declare -a CELLS=(
  "gemma4|claude-3-5-sonnet-gemma4|"                          # wide catalogue (claude -p default)
  "gemma4|claude-3-5-sonnet-gemma4|Read,Bash,Grep"            # narrow
  "gemma4|claude-3-5-sonnet-gemma4|Read"                      # curated single-tool
  "qwen3.5|claude-3-5-sonnet-qwen35|"
  "qwen3.5|claude-3-5-sonnet-qwen35|Read,Bash,Grep"
  "qwen3.5|claude-3-5-sonnet-qwen35|Read"
)

# Pre-flight
curl -sf -m 3 http://localhost:4000/health/liveliness >/dev/null || { echo "FAIL: litellm proxy down"; exit 1; }
curl -sf -m 5 http://192.168.10.107:11434/api/tags >/dev/null || { echo "FAIL: ollama unreachable"; exit 1; }

# --- Run the matrix ---
declare -a CELL_NAMES TOOL_PCT_LIST EXIT_PCT_LIST MEDIAN_LIST DETAIL_LINES

run_cell() {
  local name="$1" model="$2" tools="$3" idx="$4"
  local pass=0 tu_pass=0
  local -a lats=()
  echo "[$(date -u +%H:%M:%S)] cell $idx: $name | tools=${tools:-WIDE} | N=$N"

  for i in "${!PROMPTS[@]}"; do
    local n=$((i+1))
    local worker="t1703-${BATCH}-c${idx}-p${n}"
    local prompt="${PROMPTS[$i]}"
    local tools_arg=()
    [ -n "$tools" ] && tools_arg=(--tools "$tools")
    local start=$(date +%s)

    bin/fw termlink dispatch \
      --task T-1703 --name "$worker" --task-type ollama-research \
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
    DETAIL_LINES+=("| $idx | $name | \`${tools:-WIDE}\` | $n | $ec | $tu | ${lat}s |")
    echo "  [$n/$N] exit=$ec tools=$tu lat=${lat}s"
  done

  local total="${#PROMPTS[@]}"
  local tool_pct=$((tu_pass * 100 / total))
  local exit_pct=$((pass * 100 / total))
  local median=$(printf '%s\n' "${lats[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2==1)?a[int(NR/2)+1]:(a[NR/2]+a[NR/2+1])/2}')
  CELL_NAMES+=("$name | \`${tools:-WIDE}\`")
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

# --- Identify winner ---
WINNER="(none — no cell ≥90%)"
PIVOT=""
best_pct=0
for i in "${!TOOL_PCT_LIST[@]}"; do
  pct=${TOOL_PCT_LIST[$i]}
  if [ "$pct" -ge 90 ]; then
    WINNER="${CELL_NAMES[$i]} — $pct% real tool-use"
    break
  fi
  [ "$pct" -gt "$best_pct" ] && best_pct=$pct
done
[ "$WINNER" = "(none — no cell ≥90%)" ] && PIVOT="No cell hit 90%. Best: ${best_pct}%. Pivot path: claude-code-router OR pull tool-use-tuned model (hermes-3:8b, xlam:7b) OR system-prompt forcing."

# --- Write report ---
{
  echo "# T-1703 — gemma4 + qwen3.5 curated-catalogue probe"
  echo ""
  echo "**Batch:** \`$BATCH\` &nbsp; **N per cell:** $N &nbsp; **Total dispatches:** $((${#CELLS[@]} * N))"
  echo "**Task class:** simple-read (Read tool sufficient for all prompts)"
  echo ""
  echo "## Bottom line"
  echo ""
  if [ "$WINNER" != "(none — no cell ≥90%)" ]; then
    echo "**Winner:** $WINNER"
    echo ""
    echo "Action: update \`.context/project/workflows/ollama-research.yaml\` to use the winning"
    echo "alias and tool restriction. T-1700 v2 path resolved without router swap or model pull."
  else
    echo "**Pivot:** $PIVOT"
    echo ""
    echo "The cheapest paths (already-loaded models × catalogue restriction) do not clear the"
    echo "90% bar on simple-read. Open-weight 8-9B generalist models hallucinate text answers"
    echo "even when the tool catalogue is restricted to a single tool — describe-instead-of-call"
    echo "is a model-tuning issue, not a catalogue-size issue."
  fi
  echo ""
  echo "## Probe matrix"
  echo ""
  echo "| Cell | Model | Tool catalogue | Real tool-use | Exit-code pass | Median latency |"
  echo "|------|-------|----------------|---------------|----------------|----------------|"
  for i in "${!CELL_NAMES[@]}"; do
    pct="${TOOL_PCT_LIST[$i]}"
    status=""
    [ "$pct" -ge 90 ] && status=" ✅" || status=" ❌"
    echo "| $((i+1)) | ${CELL_NAMES[$i]} | $pct%$status | ${EXIT_PCT_LIST[$i]}% | ${MEDIAN_LIST[$i]}s |"
  done
  echo ""
  echo "## Per-dispatch detail"
  echo ""
  echo "| Cell | Model | Tools | # | Exit | Tool calls | Latency |"
  echo "|------|-------|-------|---|------|------------|---------|"
  printf '%s\n' "${DETAIL_LINES[@]}"
  echo ""
  echo "## Method"
  echo ""
  echo "- Simple-read prompts only — Read tool sufficient for every prompt, so a Read-only"
  echo "  catalogue is not unfairly penalised."
  echo "- Real tool-use metric: \`exit=0 AND tool_use events ≥ 1\` (parsed from \`result.jsonl\`"
  echo "  assistant content blocks). Per L-346, \`exit=0\` alone is not a tool-use signal."
  echo "- Sequential dispatch (ollama serializes anyway). Per-worker timeout 120s."
  echo "- Litellm proxy translates \`claude-3-5-sonnet-{gemma4,qwen35}\` → \`ollama_chat/{gemma4:latest,qwen3.5:latest}\`."
  echo ""
  echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} > "$REPORT"

echo
echo "[$(date -u +%H:%M:%S)] Done. Report: $REPORT"
echo "Cells: ${#CELLS[@]}, dispatches: $((${#CELLS[@]} * N))"
echo "$WINNER"
[ -n "$PIVOT" ] && echo "$PIVOT"
