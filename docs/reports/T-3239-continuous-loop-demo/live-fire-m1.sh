#!/usr/bin/env bash
# T-3239 — arc-012 headline-mechanic demo, experiment E2: M1 live-fire.
#
# THE QUESTION E1 COULD NOT ANSWER. E1 proved the driver emits {"decision":"block"}
# for an armed state. It cannot prove Claude Code then TAKES another turn, nor how
# many times — that is a property of the platform, not of our script. Only a real
# session can answer it, so this runs one.
#
# ISOLATION. A throwaway project tree with its own .claude/settings.json and its own
# .context/working. The live repo's continuous-mode state is never armed, so this
# session (and the operator's) is never driven. That matters: arming the real state
# file to test the loop would hand the operator's own session to the loop, which is
# the exact failure the driver's DISARMED-BY-DEFAULT posture exists to prevent.
#
# WIRE LEVEL. The transcript is captured as stream-json — one JSON object per event,
# so assistant turns can be counted mechanically rather than eyeballed from prose.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/live-fire-m1.sh [armed|disarmed|expiring]
set -uo pipefail

MODE="${1:-armed}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DRIVER="${REPO}/agents/context/stop-driver.sh"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
mkdir -p "$EVID"

command -v claude >/dev/null || { echo "FATAL: claude not on PATH" >&2; exit 1; }

PROJ="$(mktemp -d)/proj"
mkdir -p "${PROJ}/.context/working" "${PROJ}/.claude"

# --- the Stop hook, and nothing else -------------------------------------
cat > "${PROJ}/.claude/settings.json" <<EOF
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "${DRIVER}" } ] }
    ]
  }
}
EOF

case "$MODE" in
  armed)
    cat > "${PROJ}/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: true
current_iteration: 0
max_iterations: 10
tier_ceiling: 1
tasks_completed: 0
max_tasks: null
completed_task_ids: []
EOF
    ;;
  expiring)
    # A bound that CAN fire inside one session: wall-clock expiry.
    cat > "${PROJ}/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: true
current_iteration: 0
max_iterations: 10
tasks_completed: 0
completed_task_ids: []
EOF
    python3 - "$PROJ" <<'PY'
import sys, datetime
p = sys.argv[1]
exp = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=40)
open(f"{p}/.context/working/.next-directive.yaml", "w").write(
    'expires_at: "%s"\ndirective: |\n  bounded test directive\n' % exp.strftime("%Y-%m-%dT%H:%M:%SZ"))
print("expires_at set to", exp.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
    ;;
  disarmed)
    # THE CONTROL LEG. Identical in every respect except the one bit.
    cat > "${PROJ}/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: false
current_iteration: 0
max_iterations: 10
tasks_completed: 0
completed_task_ids: []
EOF
    ;;
  *) echo "unknown mode: $MODE" >&2; exit 1 ;;
esac

STREAM="${EVID}/E2-${MODE}-stream.jsonl"
LOG="${EVID}/E2-${MODE}-stop-driver.log"
SUM="${EVID}/E2-${MODE}-summary.txt"

echo "== T-3239 E2 live-fire (mode=$MODE) =="
echo "sandbox: $PROJ"
echo "running claude -p (timeout 300s)..."

start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd "$PROJ" || exit 1
timeout 300 claude -p "Reply with exactly the word: ping" \
    --output-format stream-json --verbose \
    > "$STREAM" 2>"${EVID}/E2-${MODE}-stderr.txt"
rc=$?
end=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cp "${PROJ}/.context/working/.stop-driver.log" "$LOG" 2>/dev/null || echo "(no stop-driver log produced)" > "$LOG"

# --- count assistant turns from the wire, not from prose ------------------
turns=$(python3 - "$STREAM" <<'PY'
import json, sys
n = 0
try:
    for line in open(sys.argv[1]):
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("type") == "assistant":
            n += 1
except FileNotFoundError:
    pass
print(n)
PY
)

cont=$(grep -c 'decision=continue' "$LOG" 2>/dev/null); cont=${cont:-0}
stops=$(grep -c 'decision=stop' "$LOG" 2>/dev/null); stops=${stops:-0}

{
    echo "T-3239 E2 — M1 live-fire, mode=$MODE"
    echo "started:  $start"
    echo "ended:    $end"
    echo "claude:   $(claude --version 2>/dev/null)"
    echo "repo sha: $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)"
    echo "exit rc:  $rc  (124 = timeout)"
    echo
    echo "assistant turns on the wire : $turns"
    echo "decision=continue lines     : $cont"
    echo "decision=stop lines         : $stops"
    echo
    echo "--- stop-driver.log (verbatim) ---"
    cat "$LOG"
    echo "--- end ---"
} | tee "$SUM"

rm -rf "$(dirname "$PROJ")"
