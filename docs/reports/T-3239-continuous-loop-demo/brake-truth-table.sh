#!/usr/bin/env bash
# T-3239 — arc-012 headline-mechanic demo, experiment E1.
#
# Drives agents/context/stop-driver.sh directly against a THROWAWAY project root
# and records, for every brake in the driver's own table, both halves of the
# contract: the JSON it emits on stdout (which is what actually drives or does not
# drive a turn) and the line it writes to .stop-driver.log (which is what a
# diagnostician reads afterwards).
#
# WHY BOTH HALVES. T-3163 measured that {"decision":"block"} drives a turn while
# {"ok": false} is silently inert — the log line is identical in both cases. So a
# harness that checked only the log would certify a driver that drives nothing.
# Every row below asserts the stdout shape, and the log line is recorded as
# corroboration rather than as the assertion.
#
# ISOLATION. CLAUDE_PROJECT_DIR is pointed at a temp tree, so nothing here reads or
# writes the live .context/working state. The live log is left alone.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/brake-truth-table.sh
# Exit:  0 = every row matched its expectation, 1 = at least one row diverged.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DRIVER="${REPO}/agents/context/stop-driver.sh"
OUT="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence/E1-brake-truth-table.txt"

[ -x "$DRIVER" ] || { echo "FATAL: driver not executable at $DRIVER" >&2; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

pass=0; fail=0
rows=()

# run_case <name> <state-yaml|__NONE__> <directive-yaml|__NONE__> <payload-json>
#          <halt:0|1> <expect-drives:yes|no> <expect-log-substr>
run_case() {
    local name="$1" state="$2" directive="$3" payload="$4" halt="$5" \
          expect_drives="$6" expect_log="$7"

    local root="${SANDBOX}/${name}"
    mkdir -p "${root}/.context/working"
    local wd="${root}/.context/working"

    [ "$state"     != "__NONE__" ] && printf '%s' "$state"     > "${wd}/.continuous-mode.yaml"
    [ "$directive" != "__NONE__" ] && printf '%s' "$directive" > "${wd}/.next-directive.yaml"
    [ "$halt" = "1" ] && : > "${wd}/.continuous-halt"

    local stdout_raw
    stdout_raw=$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$root" bash "$DRIVER" 2>/dev/null)

    local logline="(no log line)"
    [ -f "${wd}/.stop-driver.log" ] && logline=$(tail -1 "${wd}/.stop-driver.log")

    # The load-bearing assertion: does this output actually drive a turn?
    local drives="no"
    if printf '%s' "$stdout_raw" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if d.get("decision")=="block" else 1)
' 2>/dev/null; then
        drives="yes"
    fi

    local verdict="PASS"
    [ "$drives" = "$expect_drives" ] || verdict="FAIL"
    case "$logline" in *"$expect_log"*) ;; *) verdict="FAIL" ;; esac

    if [ "$verdict" = "PASS" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

    rows+=("$(printf '%-26s | drives=%-3s (want %-3s) | %s\n      stdout: %s\n      log:    %s' \
        "$name" "$drives" "$expect_drives" "$verdict" \
        "$(printf '%s' "$stdout_raw" | head -c 160)" \
        "$(printf '%s' "$logline" | sed 's/^[0-9TZ:-]* //' | head -c 160)")")
}

ARMED='enabled: true
current_iteration: 0
max_iterations: 10
tier_ceiling: 1
tasks_completed: 0
max_tasks: null
completed_task_ids: []
'

# --- the driver's brake table, one row each -------------------------------
run_case "01-armed-continues"      "$ARMED" "__NONE__" '{"stop_hook_active":false}' 0 yes "decision=continue"
run_case "02-stop_hook_active"     "$ARMED" "__NONE__" '{"stop_hook_active":true}'  0 no  "stop_hook_active=true"
run_case "03-halt-file"            "$ARMED" "__NONE__" '{"stop_hook_active":false}' 1 no  "halt-file present"
run_case "04-disabled"             'enabled: false
current_iteration: 0
'                                             "__NONE__" '{"stop_hook_active":false}' 0 no  "continuous-mode-disabled"
run_case "05-terminated-stored"    'enabled: false
current_iteration: 0
last_terminated_reason: expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z)
terminated_at: "2026-08-26T12:50:35Z"
'                                             "__NONE__" '{"stop_hook_active":false}' 0 no  "terminated[stored@2026-08-26T12:50:35Z]"
run_case "06-max_tasks-reached"    'enabled: true
current_iteration: 0
tasks_completed: 3
max_tasks: 3
'                                             "__NONE__" '{"stop_hook_active":false}' 0 no  "max_tasks-reached(3>=3)"
run_case "07-max_iterations"       'enabled: true
current_iteration: 10
max_iterations: 10
'                                             "__NONE__" '{"stop_hook_active":false}' 0 no  "max_iterations-reached(11>10)"
run_case "08-expired-directive"    "$ARMED" 'expires_at: "2020-01-01T00:00:00Z"
' '{"stop_hook_active":false}' 0 no  "expired-at(2020-01-01T00:00:00Z)"
run_case "09-no-state-file"        "__NONE__" "__NONE__" '{"stop_hook_active":false}' 0 no  "no state file"
run_case "10-malformed-state"      'enabled: true
  : : bad yaml [[[
'                                             "__NONE__" '{"stop_hook_active":false}' 0 no  "state-unreadable-or-empty"
run_case "11-empty-payload"        "$ARMED" "__NONE__" ''                           0 yes "decision=continue"

{
    echo "T-3239 E1 — stop-driver brake truth table"
    echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "driver:    agents/context/stop-driver.sh"
    echo "driver sha: $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "isolation: CLAUDE_PROJECT_DIR -> throwaway tmp tree (live state untouched)"
    echo
    echo "'drives' = the emitted JSON is {\"decision\":\"block\"}, the only shape"
    echo "measured (T-3163) to actually cause another turn. Anything else is inert."
    echo
    for r in "${rows[@]}"; do echo "  $r"; echo; done
    echo "----------------------------------------------------------------"
    echo "PASS: $pass   FAIL: $fail"
} | tee "$OUT"

exit $(( fail > 0 ? 1 : 0 ))
