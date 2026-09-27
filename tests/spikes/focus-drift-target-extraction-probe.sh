#!/bin/bash
# tests/spikes/focus-drift-target-extraction-probe.sh (T-2833)
#
# Probe harness for the T-1730 focus-drift gate's Bash target-extraction
# regexes (agents/context/check-active-task.sh:305-319). Runs a matrix of
# focus-state x command-shape combinations through the REAL hook script,
# against a throwaway sandbox PROJECT_ROOT — the live session's
# .context/working/focus.yaml is never touched.
#
# Usage: bash tests/spikes/focus-drift-target-extraction-probe.sh
# Prints a markdown table: expect | got | pass/fail | command
#
# Origin: T-2833 — Pattern 3 (git commit ... T-NNNN:) used two independent
# regexes ANDed together, so the extracted id needed not belong to the
# commit's own -m/--message value at all. That produced both a fail-open
# false negative (real drift missed) and a false positive (unrelated text
# supplying the id). The fix anchors extraction to the flag's value.

set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/agents/context/check-active-task.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.context/working" "$SANDBOX/.tasks/active"
echo "session_id: S-probe" > "$SANDBOX/.context/working/session.yaml"
echo "version: probe" > "$SANDBOX/.framework.yaml"
echo "completed: 2026-01-01T00:00:00Z" > "$SANDBOX/.context/working/.onboarding-complete"

_create_task() {
    local id="$1"
    cat > "$SANDBOX/.tasks/active/${id}-probe.md" <<MD
---
id: $id
name: "probe"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# $id

## Acceptance Criteria
### Agent
- [ ] Real AC
MD
}

_set_focus() {
    cat > "$SANDBOX/.context/working/focus.yaml" <<YAML
current_task: $1
focus_session: S-probe
priorities: []
blockers: []
YAML
}

_create_task T-2900
_create_task T-2901
_set_focus T-2900

pass=0
fail=0

printf '| %-6s | %-40.40s | %-8s | %-8s | %s |\n' "row" "command" "expect" "got" "result"
printf '|--------|------------------------------------------|----------|----------|--------|\n'

_probe() {
    local desc="$1" cmd="$2" expect="$3"
    local json
    json=$(PROJECT_ROOT="$SANDBOX" python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd")
    local out status got
    out=$(PROJECT_ROOT="$SANDBOX" CLAUDECODE=1 bash "$HOOK" <<< "$json" 2>&1)
    status=$?
    if [ "$status" -eq 2 ] && echo "$out" | grep -q "FOCUS-DRIFT"; then
        got="block"
    else
        got="allow"
    fi
    local result="OK"
    if [ "$got" != "$expect" ]; then
        result="FAIL"
        fail=$((fail+1))
    else
        pass=$((pass+1))
    fi
    printf '| %-6s | %-40.40s | %-8s | %-8s | %s |\n' "$desc" "$cmd" "$expect" "$got" "$result"
}

# Focus = T-2900 throughout this block.
_probe "d1" 'git commit -m "T-2900: legitimate work"' "allow"
_probe "d2" 'git commit -m "T-2901: cherry-pick fix"' "block"
_probe "d3" 'git commit -am "T-2901: cherry-pick fix"' "block"
_probe "d4" 'git commit --message="T-2901: cherry-pick fix"' "block"
_probe "d5-A" 'echo "See T-2900: prior context" && git commit -m "T-2901: actual fix"' "block"
_probe "d6-B" 'grep -rn "T-2901:" docs/ && git commit -m "T-2900: fix docs"' "allow"
_probe "d7" 'git commit' "allow"
_probe "d8" 'echo hello' "allow"
_probe "d9" 'fw task update T-2901 --add-tag x' "block"
_probe "d10" 'fw task update T-2900 --add-tag x' "allow"

echo ""
echo "Totals: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
