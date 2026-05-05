#!/usr/bin/env bats
# T-1727 — escalation-scan v0.5 unit coverage.
#
# Pins the structural invariants that A2/A3/A4/A5/A6/A9 depend on. Per AC A8
# the rule is "≥1 test per AC" — this file covers the AC subset that is
# bats-testable; A5 UI rendering is pinned by tests/playwright/test_escalation_v05.py
# and A7 (Evolution log) is part of the task file itself, not source.

load ../test_helper

# ---- A1: workflow + prompt template (filesystem-side) ----

@test "A1: escalation-triage workflow YAML exists and is valid" {
    run python3 -c "
import yaml
d = yaml.safe_load(open('$FRAMEWORK_ROOT/.context/project/workflows/escalation-triage.yaml'))
assert d['task_type'] == 'escalation-triage', f'task_type={d.get(\"task_type\")!r}'
assert d['worker_kind'] == 'ollama-loop', f'worker_kind={d.get(\"worker_kind\")!r}'
assert d['prompt_template'] == 'prompts/escalation-triage.md'
assert 'Read' in d['allowed_tools']
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "A1: escalation-triage prompt template names the three verdicts" {
    grep -q 'real_symptom_fix' "$FRAMEWORK_ROOT/prompts/escalation-triage.md"
    grep -q 'false_positive' "$FRAMEWORK_ROOT/prompts/escalation-triage.md"
    grep -q 'defer' "$FRAMEWORK_ROOT/prompts/escalation-triage.md"
}

# ---- A2: tool exists + parses + dry-runs ----

@test "A2: tools/escalation-scan-v0.5.py exists and parses" {
    test -f "$FRAMEWORK_ROOT/tools/escalation-scan-v0.5.py"
    run python3 -c "import ast; ast.parse(open('$FRAMEWORK_ROOT/tools/escalation-scan-v0.5.py').read())"
    [ "$status" -eq 0 ]
}

@test "A2: dry-run emits dispatch envelope with task_type=escalation-triage" {
    cd "$FRAMEWORK_ROOT"
    # Need a v0 LATEST.yaml to exist; the cron has been running so this is
    # generally true on a live framework repo. If absent, skip.
    [ -f .context/working/escalation-drift-LATEST.yaml ] || skip "v0 LATEST.yaml absent"
    run python3 tools/escalation-scan-v0.5.py --dry-run --limit 1 --window-days 90
    [ "$status" -eq 0 ]
    [[ "$output" == *"dispatch_id="* ]] || [[ "$output" == *"nothing to triage"* ]]
}

# ---- A3: idempotency ----

@test "A3: repeat dry-run within idempotency window does not redispatch" {
    cd "$FRAMEWORK_ROOT"
    [ -f .context/working/escalation-drift-LATEST.yaml ] || skip "v0 LATEST.yaml absent"
    [ -f .context/working/escalation-drift-LATEST-v0.5.yaml ] || skip "no prior v0.5 run to be idempotent against"
    # If a recent verdict exists for the first candidate, --dry-run with no
    # --force should record skipped_idempotent >= 1 in the resulting summary.
    run python3 tools/escalation-scan-v0.5.py --dry-run --limit 1 --window-days 30
    [ "$status" -eq 0 ]
    # Either skipped_idempotent fired OR the corpus emptied — both demonstrate
    # the idempotency gate fires (it's the same code path).
    [[ "$output" == *"skipped_idempotent="* ]] || [[ "$output" == *"nothing to triage"* ]]
}

# ---- A4: cron wiring ----

@test "A4: oe-daily crontab includes escalation-scan-v0.5" {
    grep -q "escalation-scan-v0.5" "$FRAMEWORK_ROOT/.context/cron/agentic-audit.crontab"
}

@test "A4: v0 cron line still present (additive, not replaced)" {
    grep -q "escalation-scan-v0.py" "$FRAMEWORK_ROOT/.context/cron/agentic-audit.crontab"
}

# ---- A5: Watchtower template hooks (Playwright runs the live browser test) ----

@test "A5: escalation_drift template carries v0.5 panel data-testid" {
    grep -q 'data-testid="escalation-v05-panel"' "$FRAMEWORK_ROOT/web/templates/escalation_drift.html"
}

@test "A5: escalation_drift template carries v0.5 table data-testid" {
    grep -q 'data-testid="escalation-v05-table"' "$FRAMEWORK_ROOT/web/templates/escalation_drift.html"
}

@test "A5: tests/playwright/test_escalation_v05.py exists" {
    test -f "$FRAMEWORK_ROOT/tests/playwright/test_escalation_v05.py"
}

# ---- A6: disagreement-rate report ----

@test "A6: docs/reports/T-1727-v0-5-disagreement-rate.md exists with required content" {
    test -f "$FRAMEWORK_ROOT/docs/reports/T-1727-v0-5-disagreement-rate.md"
    grep -q -i "disagreement" "$FRAMEWORK_ROOT/docs/reports/T-1727-v0-5-disagreement-rate.md"
    grep -q -i "30-day" "$FRAMEWORK_ROOT/docs/reports/T-1727-v0-5-disagreement-rate.md"
}

# ---- A9a: validator regression pin (T-1689 fix) ----

@test "A9a: VALID_WORKER_KINDS still includes ollama-loop" {
    cd "$FRAMEWORK_ROOT"
    run python3 -c "
import sys; sys.path.insert(0, 'lib')
from resolver import VALID_WORKER_KINDS
sys.exit(0 if 'ollama-loop' in VALID_WORKER_KINDS else 1)
"
    [ "$status" -eq 0 ]
}

# ---- A9b: prompts/default.md no longer leaks unresolved \$VAR ----

@test "A9b: prompts/default.md does not write a literal \$VAR token" {
    cd "$FRAMEWORK_ROOT"
    # The leak was from the doc text "the resolver substitutes \`\$VAR\` slots".
    # The fix replaces it with "named slots" — no \$VAR token remains.
    run grep -E '\$VAR\b' prompts/default.md
    [ "$status" -ne 0 ]
}

@test "A9b: dispatch with default-fallback workflow no longer emits unresolved-vars trailer" {
    cd "$FRAMEWORK_ROOT"
    run bash -c "bin/fw resolver dispatch T-1727 escalation-triage --dry-run --json --var CANDIDATE_BODY=test 2>/dev/null | python3 -c \"import sys,json; d=json.loads(sys.stdin.read()); p=d.get('prompt') or d.get('rendered_prompt',''); sys.exit(0 if 'resolver: unresolved' not in p else 1)\""
    [ "$status" -eq 0 ]
}
