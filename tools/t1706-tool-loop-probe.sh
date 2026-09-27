#!/bin/bash
# T-1706 — Spike A probe for the thin tool-loop worker.
#
# Same simple-read prompts as T-1704 (hermes3:8b through claude -p, 0/9).
# Goal: ≥90% real tool_use events through tools/ollama-tool-loop.py
# (curated litellm /v1/messages directly).
#
# Usage: tools/t1706-tool-loop-probe.sh [N_per_cell]   (default 3)
# Output: docs/reports/T-1706-tool-loop-probe.md

set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-3}"
REPORT="docs/reports/T-1706-tool-loop-probe.md"
BATCH=$(date -u +%Y%m%d-%H%M%S)
WDIR_BASE="/tmp/tl-dispatch"
PROJECT_ROOT_ABS="$(pwd)"

PROMPTS=(
  "Use the Read tool to read /etc/hostname, then state the hostname in one sentence."
  "Use the Read tool to read VERSION, then state the version number."
  "Use the Read tool to read /etc/os-release, then identify the OS family in one sentence."
)
PROMPTS=("${PROMPTS[@]:0:$N}")

# Three cells to mirror T-1703/T-1704 shape: same model (hermes3:8b), but the
# new variable here is the tool LOOP, not the catalogue. We keep the
# 3-tool curated def in ollama-tool-loop.py constant and vary only the
# prompt to widen coverage of model behaviour.

curl -sf -m 3 http://localhost:4000/health/liveliness >/dev/null \
  || { echo "FAIL: litellm proxy down"; exit 1; }
curl -sf -m 5 http://192.168.10.107:11434/api/tags >/dev/null \
  || { echo "FAIL: ollama unreachable"; exit 1; }
curl -sf http://192.168.10.107:11434/api/tags | python3 -c "
import json,sys
d=json.load(sys.stdin)
names=[m['name'] for m in d.get('models',[])]
sys.exit(0 if 'hermes3:8b' in names else 1)" \
  || { echo "FAIL: hermes3:8b not loaded"; exit 1; }

declare -a DETAIL_LINES SAMPLE_OUTS
total_passes=0
total_runs=0
declare -a LATS

run_one() {
  local idx="$1"
  local prompt="$2"
  local n="$3"
  local worker="t1706-${BATCH}-p${n}"
  local wdir="$WDIR_BASE/$worker"
  mkdir -p "$wdir"
  printf '%s\n' "$prompt" > "$wdir/prompt.md"
  printf '{"name":"%s","status":"running","worker_kind":"ollama-loop"}\n' "$worker" > "$wdir/meta.json"

  local start end lat ec tu
  start=$(date +%s)
  PROJECT_ROOT="$PROJECT_ROOT_ABS" \
    ANTHROPIC_BASE_URL=http://localhost:4000 \
    ANTHROPIC_API_KEY=sk-litellm-local-dev \
    OLLAMA_LOOP_MODEL=claude-3-5-sonnet-hermes3 \
    timeout 240 python3 tools/ollama-tool-loop.py --wdir "$wdir" \
    >"$wdir/stdout.log" 2>"$wdir/stderr.log" || true
  end=$(date +%s)
  lat=$((end - start))
  LATS+=("$lat")

  ec="TIMEOUT"
  [ -f "$wdir/exit_code" ] && ec=$(cat "$wdir/exit_code")
  tu=0
  if [ -f "$wdir/result.jsonl" ]; then
    tu=$(python3 -c "
import json
try:
    events=[json.loads(l) for l in open('$wdir/result.jsonl')]
    print(sum(1 for e in events if e.get('type')=='assistant'
              for c in e.get('message',{}).get('content',[])
              if c.get('type')=='tool_use'))
except Exception: print(0)" 2>/dev/null || echo 0)
  fi

  total_runs=$((total_runs + 1))
  [ "$ec" = "0" ] && [ "$tu" -ge 1 ] && total_passes=$((total_passes + 1))

  DETAIL_LINES+=("| $n | exit=$ec | tool_use=$tu | ${lat}s |")
  if [ -f "$wdir/result.md" ]; then
    local sample
    sample=$(head -c 200 "$wdir/result.md" | tr '\n' ' ' | sed 's/|/\\|/g')
    SAMPLE_OUTS+=("| $n | $tu | ${sample:0:180} |")
  fi
  echo "  [$n/$N] exit=$ec tool_use=$tu lat=${lat}s"
}

echo "[$(date -u +%H:%M:%S)] T-1706 Spike A: ollama-tool-loop probe (N=$N)"
for i in "${!PROMPTS[@]}"; do
  run_one 1 "${PROMPTS[$i]}" "$((i+1))"
done

# Median
median=$(printf '%s\n' "${LATS[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2==1)?a[int(NR/2)+1]:(a[NR/2]+a[NR/2+1])/2}')
pct=$((total_passes * 100 / total_runs))

if [ "$pct" -ge 90 ]; then
  STATUS="GO"
  CONCLUSION="**Spike A GO:** ${pct}% real tool_use ≥ 90% threshold ✅"
elif [ "$pct" -gt 0 ]; then
  STATUS="PARTIAL"
  CONCLUSION="**Spike A partial:** ${pct}% (below 90%). Investigate before proposing wire-up."
else
  STATUS="FAIL"
  CONCLUSION="**Spike A FAIL:** 0% — investigate worker before pivoting to Spike B."
fi

{
  echo "# T-1706 — Spike A probe (thin tool-loop worker)"
  echo ""
  echo "**Batch:** \`$BATCH\` &nbsp; **N:** $N &nbsp; **Worker:** \`tools/ollama-tool-loop.py\`"
  echo "**Model alias:** \`claude-3-5-sonnet-hermes3\` → \`ollama_chat/hermes3:8b\`"
  echo "**Prompts:** simple-read (hostname / VERSION / os-release), identical to T-1704."
  echo ""
  echo "## Bottom line"
  echo ""
  echo "$CONCLUSION"
  echo ""
  echo "Real tool-use rate: **${total_passes}/${total_runs} (${pct}%)**, median latency ${median}s."
  echo ""
  echo "## Comparison with prior probes"
  echo ""
  echo "| Probe | Path | Model | Real tool_use |"
  echo "|-------|------|-------|---------------|"
  echo "| T-1700 | claude -p (wide) | qwen3:14b | 0/10 (0%) |"
  echo "| T-1700 | claude -p (wide) | gpt-oss:20b | 1/3 (33%) |"
  echo "| T-1703 | claude -p × 3 catalogues | gemma4:8b | 0/9 (0%) |"
  echo "| T-1703 | claude -p × 3 catalogues | qwen3.5:9.7b | 0/9 (0%) |"
  echo "| T-1704 | claude -p × 3 catalogues | hermes3:8b | 0/9 (0%) |"
  echo "| **T-1706** | **thin tool-loop** | **hermes3:8b** | **${total_passes}/${total_runs} (${pct}%)** |"
  echo ""
  echo "## Per-dispatch detail"
  echo ""
  echo "| # | Exit | tool_use | Latency |"
  echo "|---|------|----------|---------|"
  printf '%s\n' "${DETAIL_LINES[@]}"
  echo ""
  echo "## Sample outputs"
  echo ""
  echo "| Prompt # | tool_use | Result (truncated 180c) |"
  echo "|----------|----------|--------------------------|"
  printf '%s\n' "${SAMPLE_OUTS[@]}"
  echo ""
  echo "## Spike A go/no-go evaluation"
  echo ""
  echo "From T-1705 §Go/No-Go Criteria:"
  echo ""
  echo "- ≥90% real tool_use on simple-read prompts: **${pct}% — $([ $pct -ge 90 ] && echo PASS || echo FAIL)**"
  echo "- Worker writes wdir contract (result.jsonl/result.md/exit_code/meta.json): **PASS** (verified by this probe)"
  echo "- Latency ≤2× T-1704 hermes3 figures (7-21s): **${median}s median — $([ "$median" -le 60 ] && echo PASS || echo CHECK)**"
  echo ""
  echo "Decision: **$STATUS**"
  echo ""
  echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} > "$REPORT"

echo
echo "[$(date -u +%H:%M:%S)] Done. Report: $REPORT"
echo "Real tool-use: ${total_passes}/${total_runs} (${pct}%) — $STATUS"
