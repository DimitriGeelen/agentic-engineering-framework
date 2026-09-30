#!/usr/bin/env bats
# T-3586 (rebuilds T-3583) — review/dispatch cost: extensible operator-owned registry,
# JSONL cost ledger, paid-approval proposals, fw audit cost line, paid-backend hook.
#
# Every refusal has a control that differs by one input. The sandbox gets its own copy
# of policy/review-backends.yaml, so the live registry and ledgers are never touched.

load ../test_helper

RC="$FRAMEWORK_ROOT/lib/review_cost.py"
HOOK="$FRAMEWORK_ROOT/agents/context/check-paid-backend.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE FW_SESSION_SCOPED_FOCUS
    mkdir -p "$PROJECT_ROOT/policy" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    cp "$FRAMEWORK_ROOT/policy/review-backends.yaml" "$PROJECT_ROOT/policy/"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    POLICY="$PROJECT_ROOT/policy/review-backends.yaml"
    LEDGER="$PROJECT_ROOT/.context/costs/reviews.jsonl"
    CHANGES="$PROJECT_ROOT/.context/costs/registry-changes.jsonl"
    cd "$PROJECT_ROOT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

rc() { python3 "$RC" "$@"; }

# Build the hook's stdin for a command without the command text ever being a typed Bash
# argument of this test's parent session.
hook_json() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }
focus() { printf 'current_task: %s\n' "$1" > "$PROJECT_ROOT/.context/working/focus.yaml"; }
PAID_URL="https://""openrouter.ai/api/v1/chat/completions"

append_backend() {  # $1 id  $2 class  $3 approval  [$4 match regex]
    {
        printf '\n  - id: %s\n    name: "Fake %s"\n    harness_class: subscription\n' "$1" "$1"
        printf '    cost_class: %s\n    approval_required: %s\n' "$2" "$3"
        printf '    cost_estimate_method: unmetered\n    description: "fixture"\n'
        [ -n "${4:-}" ] && printf "    match:\n      - '%s'\n" "$4"
        true
    } >> "$POLICY"
}

# ── registry ──────────────────────────────────────────────────────────────────

@test "seeded registry: loads, five seeded backends, openrouter paid + approval" {
    run rc list-backends
    [ "$status" -eq 0 ]
    for id in claude-code codex opencode local-gpu openrouter; do [[ "$output" == *"$id"* ]]; done
    [[ "$(echo "$output" | grep '^openrouter')" == *"paid"*"true"* ]]
    [[ "$(echo "$output" | grep '^codex')" == *"internal"*"false"* ]]
}

@test "extensible: a backend added by DATA edit only is picked up by cost logging" {
    run rc cost log --task T-100 --backend fake-sub --purpose code-review
    [ "$status" -ne 0 ]                       # control: unknown before the edit
    [[ "$output" == *"unknown backend"* ]]
    append_backend fake-sub internal false
    run rc cost log --task T-100 --backend fake-sub --purpose code-review
    [ "$status" -eq 0 ]
    python3 -c "import json;r=[json.loads(l) for l in open('$LEDGER')];assert r[-1]['backend']=='fake-sub' and r[-1]['class']=='internal', r"
}

@test "extensible: an added PAID backend is gated like openrouter (no code change)" {
    append_backend fake-paid paid true
    run rc cost log --task T-100 --backend fake-paid --purpose code-review
    [ "$status" -ne 0 ]
    [[ "$output" == *"approved proposal"* ]]
}

@test "agent may add an INTERNAL backend via the verb, and it is logged for the operator" {
    CLAUDECODE=1 run rc backend add --id new-sub --name "New sub" --class internal
    [ "$status" -eq 0 ]
    grep -q "^  - id: new-sub$" "$POLICY"
    python3 -c "import json;r=[json.loads(l) for l in open('$CHANGES')][-1];assert r['action']=='add' and r['id']=='new-sub' and r['by']=='agent', r"
    run rc cost log --task T-100 --backend new-sub --purpose x
    [ "$status" -eq 0 ]
}

@test "the verb's text append keeps the operator's comments" {
    rc backend add --id keep-comments --name K --class internal
    grep -q "OPERATOR-OWNED AND EXTENSIBLE" "$POLICY"
}

@test "agent adding a PAID backend is refused; --i-am-human allows it" {
    CLAUDECODE=1 run rc backend add --id p2 --name P2 --class paid
    [ "$status" -ne 0 ]
    [[ "$output" == *"operator action"* ]]
    # T-3592: a bare `! cmd` never fails a bats test (errexit ignores it); assert the status.
    run grep -q "id: p2$" "$POLICY"
    [ "$status" -ne 0 ]
    CLAUDECODE=1 run rc backend add --id p2 --name P2 --class paid --i-am-human
    [ "$status" -eq 0 ]
    grep -q "id: p2$" "$POLICY"
    [[ "$(rc list-backends | grep '^p2 ')" == *"paid"*"true"* ]]   # paid defaults to approval
}

@test "agent changing class or approval_required is refused; operator override applies and logs before/after" {
    CLAUDECODE=1 run rc backend set --id codex --class paid
    [ "$status" -ne 0 ]
    [[ "$(rc list-backends | grep '^codex')" == *"internal"* ]]
    CLAUDECODE=1 run rc backend set --id codex --approval-required true
    [ "$status" -ne 0 ]
    CLAUDECODE=1 run rc backend set --id codex --class paid --approval-required true --i-am-human
    [ "$status" -eq 0 ]
    [[ "$(rc list-backends | grep '^codex')" == *"paid"*"true"* ]]
    python3 -c "import json;r=[json.loads(l) for l in open('$CHANGES')][-1];assert r['by']=='human-override' and r['before']['cost_class']=='internal', r"
}

@test "human (no CLAUDECODE) may change a class without the override" {
    run rc backend set --id local-gpu --approval-required true
    [ "$status" -eq 0 ]
    python3 -c "import json;r=[json.loads(l) for l in open('$CHANGES')][-1];assert r['by']=='human', r"
}

@test "openrouter cannot be reclassified — not by the verb, not even with --i-am-human" {
    run rc backend set --id openrouter --class internal --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"pinned"* ]]
    run rc backend set --id openrouter --approval-required false --i-am-human
    [ "$status" -ne 0 ]
    grep -A4 "id: openrouter" "$POLICY" | grep -q "cost_class: paid"
}

@test "openrouter hand-edited to internal: the registry refuses to load, logging and audit fail closed" {
    python3 - "$POLICY" <<'EOF'
import re,sys
p=sys.argv[1]; s=open(p).read()
i=s.index("  - id: openrouter")
s=s[:i]+s[i:].replace("cost_class: paid","cost_class: internal",1).replace("approval_required: true","approval_required: false",1)
open(p,"w").write(s)
EOF
    run rc cost log --task T-100 --backend openrouter --purpose x
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot be reclassified"* ]]
    run rc cost log --task T-100 --backend codex --purpose x      # whole registry refused
    [ "$status" -ne 0 ]
    run rc audit
    [[ "$output" == *"FAIL"*"registry is invalid"* ]]
}

@test "a paid entry without approval_required is invalid data" {
    append_backend bad-paid paid false
    run rc list-backends
    [ "$status" -ne 0 ]
    [[ "$output" == *"bad-paid: a paid backend must have approval_required: true"* ]]
}

# ── ledger ────────────────────────────────────────────────────────────────────

@test "cost log writes exactly one JSON object per line with the required fields" {
    rc cost log --task T-100 --backend codex --purpose code-review
    rc cost log --task T-101 --backend claude-code --purpose code-review --tokens 1200
    [ "$(wc -l < "$LEDGER")" -eq 2 ]
    python3 - "$LEDGER" <<'EOF'
import json,sys
a,b=[json.loads(l) for l in open(sys.argv[1])]
for r in (a,b):
    for k in ("ts","task","backend","class","purpose","metering"): assert k in r, (k,r)
assert a["metering"]=="unmetered (subscription)" and a["class"]=="internal", a
assert b["metering"]=="metered" and b["tokens"]==1200, b
EOF
}

@test "cost log refuses an unknown backend and a non-task id" {
    run rc cost log --task T-100 --backend nope --purpose x
    [ "$status" -ne 0 ]
    run rc cost log --task nottask --backend codex --purpose x
    [ "$status" -ne 0 ]
    [ ! -f "$LEDGER" ]
}

# ── proposals ─────────────────────────────────────────────────────────────────

@test "paid: no proposal refused, pending refused, approved accepted once, reuse refused" {
    run rc cost log --task T-100 --backend openrouter --purpose x
    [ "$status" -ne 0 ]
    pid=$(rc propose --task T-100 --backend openrouter --why "high risk" --estimate-cost 3 | grep -o 'RP-[0-9a-f]*')
    run rc cost log --task T-100 --backend openrouter --purpose x --proposal-id "$pid"
    [ "$status" -ne 0 ]                       # pending
    rc approve "$pid" --reason "ok"
    run rc cost log --task T-101 --backend openrouter --purpose x --proposal-id "$pid"
    [ "$status" -ne 0 ]                       # approved, but for another task
    run rc cost log --task T-100 --backend openrouter --purpose x --proposal-id "$pid" --cost 2.5
    [ "$status" -eq 0 ]
    run rc cost log --task T-100 --backend openrouter --purpose x --proposal-id "$pid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already used"* ]]
}

@test "approve: agent refused, agent with --i-am-human allowed, human allowed" {
    p1=$(rc propose --task T-100 --backend openrouter --why w | grep -o 'RP-[0-9a-f]*')
    p2=$(rc propose --task T-100 --backend openrouter --why w | grep -o 'RP-[0-9a-f]*')
    CLAUDECODE=1 run rc approve "$p1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"operator action"* ]]
    CLAUDECODE=1 run rc approve "$p1" --i-am-human --reason "at keyboard"
    [ "$status" -eq 0 ]
    run rc approve --proposal-id "$p2"
    [ "$status" -eq 0 ]
    run rc list-proposals
    [[ "$output" == *"$p1"*"approved"* ]]
}

@test "propose is refused for an internal backend (nothing to approve)" {
    run rc propose --task T-100 --backend codex --why w
    [ "$status" -ne 0 ]
}

# ── fw audit cost line ────────────────────────────────────────────────────────

@test "weekly report groups by ISO week, backend and class, summing cost" {
    mkdir -p "$(dirname "$LEDGER")"
    cat > "$LEDGER" <<'EOF'
{"ts":"2026-09-28T10:00:00Z","task":"T-1","backend":"codex","class":"internal","purpose":"r","metering":"unmetered (subscription)"}
{"ts":"2026-09-29T10:00:00Z","task":"T-1","backend":"codex","class":"internal","purpose":"r","metering":"unmetered (subscription)"}
{"ts":"2026-09-21T10:00:00Z","task":"T-1","backend":"codex","class":"internal","purpose":"r","metering":"unmetered (subscription)"}
{"ts":"2026-09-29T11:00:00Z","task":"T-1","backend":"fakepaid","class":"paid","purpose":"r","cost_amount":2.5,"metering":"metered"}
{"ts":"2026-09-30T11:00:00Z","task":"T-1","backend":"fakepaid","class":"paid","purpose":"r","cost_amount":1.0,"metering":"metered"}
EOF
    run rc cost report --json
    [ "$status" -eq 0 ]
    python3 -c "
import json,sys
rows={(r['week'],r['backend']):r for r in json.loads(sys.argv[1])}
assert rows[('2026-W40','codex')]['records']==2, rows
assert rows[('2026-W39','codex')]['records']==1, rows
assert rows[('2026-W40','fakepaid')]['cost']==3.5 and rows[('2026-W40','fakepaid')]['class']=='paid', rows
" "$output"
}

@test "audit WARNs on a paid record with no approved proposal; an approved one does not" {
    mkdir -p "$(dirname "$LEDGER")"
    echo '{"ts":"2026-09-29T11:00:00Z","task":"T-7","backend":"openrouter","class":"paid","purpose":"r","proposal_id":null}' > "$LEDGER"
    run rc audit
    [[ "$output" == *"WARN"*"Paid review with no approved proposal: T-7 on openrouter"* ]]
    [[ "$output" == *"Review cost 2026-W40: openrouter (paid)"* ]]
    # control: same record, now backed by an approved proposal
    pid=$(rc propose --task T-7 --backend openrouter --why w | grep -o 'RP-[0-9a-f]*')
    rc approve "$pid"
    echo "{\"ts\":\"2026-09-29T11:00:00Z\",\"task\":\"T-7\",\"backend\":\"openrouter\",\"class\":\"paid\",\"purpose\":\"r\",\"proposal_id\":\"$pid\"}" > "$LEDGER"
    run rc audit
    [[ "$output" != *"Paid review with no approved proposal"* ]]
    [[ "$output" == *"1 paid — each with an approved proposal"* ]]
}

@test "audit WARNs on unparseable ledger lines (the T-3583 multi-line shape)" {
    mkdir -p "$(dirname "$LEDGER")"
    printf '{\n  "ts": "2026-09-30T09:56:57Z",\n  "task": "T-1"\n}\n' > "$LEDGER"
    run rc audit
    [[ "$output" == *"WARN"*"unparseable line"* ]]
}

@test "fw audit runs the review-cost section" {
    grep -q "review_cost.py\" audit" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

# ── hook ──────────────────────────────────────────────────────────────────────

@test "hook reads the command from stdin JSON (not \$1): a paid URL with no proposal is blocked" {
    focus T-100
    run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "curl -s $PAID_URL -d @req.json")")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"needs an approved, unused proposal for T-100"* ]]
    [[ "$output" == *"fw review propose"* ]]
}

@test "hook allows the paid call once an approved proposal exists for the focused task" {
    focus T-100
    pid=$(rc propose --task T-100 --backend openrouter --why w | grep -o 'RP-[0-9a-f]*')
    rc approve "$pid"
    run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "curl -s $PAID_URL")")"
    [ "$status" -eq 0 ]
    # an approval for ANOTHER task does not carry over
    focus T-200
    run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "curl -s $PAID_URL")")"
    [ "$status" -eq 2 ]
}

@test "hook allows internal harnesses (codex, opencode, claude -p) with a cost reminder" {
    focus T-100
    for c in 'codex exec "review this"' 'opencode run brief.md' 'claude -p "review"'; do
        run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "$c")")"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; false; }
        [[ "$output" == *"Internal backend"*"fw review cost log"* ]] || { echo "no reminder: $c"; false; }
    done
}

@test "hook is silent on ordinary commands and on reading the registry" {
    focus T-100
    # the third is the prose shape that false-blocked a doc edit during T-3586
    for c in 'ls -la' 'grep -n openrouter policy/review-backends.yaml' 'git status' \
             'python3 - <<EOF
| **Paid** | OpenRouter (pay-per-use), --backend openrouter --why x |
EOF'; do
        run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "$c")")"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; false; }
        [ -z "$output" ] || { echo "noise on: $c -> $output"; false; }
    done
}

@test "hook picks up a paid backend added by data, via its match: pattern" {
    focus T-100
    append_backend fake-paid paid true 'fakepaid\.example/api'
    run bash -c "$(printf '%q' "$HOOK") <<< $(printf '%q' "$(hook_json "curl https://fakepaid.example/api/x")")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"fake-paid"* ]]
}

@test "hook is registered on Bash through fw hook, not an absolute path" {
    python3 - "$FRAMEWORK_ROOT/.claude/settings.json" <<'EOF'
import json,sys
s=json.load(open(sys.argv[1]))
cmds=[h["command"] for m in s["hooks"]["PreToolUse"] if m.get("matcher")=="Bash" for h in m["hooks"]]
assert "${CLAUDE_PROJECT_DIR}/bin/fw hook check-paid-backend" in cmds, cmds
assert not any("lib/hooks/check-paid-backend" in c for c in cmds), cmds
EOF
}

# ── collateral: T-3583 overwrote lib/review.sh ────────────────────────────────

@test "lib/review.sh is the fw task review emitter again (emit_review defined)" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/colors.sh' 2>/dev/null; source '$FRAMEWORK_ROOT/lib/review.sh'; declare -F emit_review && declare -F emit_review_batch"
    [ "$status" -eq 0 ]
}
