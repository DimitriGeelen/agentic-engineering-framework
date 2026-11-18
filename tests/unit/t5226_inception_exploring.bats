#!/usr/bin/env bats
# T-5226 — EXPLORING: an inception's recommendation reads "not ready for
# decision" until every IW question is disposed.
#
#   AC1  all four filing paths accept EXPLORING and default agent filings to it,
#        the rationale still required
#   AC2  the retrofit sweep writes EXPLORING stubs (and never re-stubs them)
#   AC3  fw task review, fw task review-batch and fw inception decide refuse an
#        EXPLORING inception and emit no decide link (the page: the .py sibling)
#   AC4  disposed-but-still-EXPLORING is reported as "ready for a
#        recommendation" by audit (C-006b) and by the handover
#
# All fixtures live in a tmp project root; the real .tasks/ is never touched.

load ../test_helper

setup() {
    P="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$P"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$P/.tasks"
    export CONTEXT_DIR="$P/.context"
    export NO_COLOR=1
    export WATCHTOWER_URL="http://test-host:7777"
    unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_ALLOW_UNREADY_HANDOFF
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.tasks/templates" \
             "$P/.context/working" "$P/.context/episodic" "$P/.context/project"
    echo "id: TEST" > "$P/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$P/.tasks/templates/inception.md"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$P/.tasks/templates/default.md" 2>/dev/null || true
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _inception ID REC QUESTIONS — QUESTIONS: open | disposed | none | nosection
_inception() {
    local id="$1" rec="$2" qs="$3"
    : > "$P/.context/working/.reviewed-$id"
    { printf -- '---\nid: %s\nname: "fixture inception"\nstatus: started-work\n' "$id"
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n'
      printf 'created: 2026-11-01T00:00:00Z\nlast_update: 2026-11-01T00:00:00Z\n---\n\n'
      printf '# %s: fixture inception\n\n## Problem Statement\n\nx\n\n' "$id"
      case "$qs" in
        open)
          printf '## Open Questions\n\n'
          printf -- '- **IW-1: first question**\n  disposition: answered\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  disposition:\n  rationale:\n\n'
          printf -- '- **IW-3: third question**\n\n' ;;
        disposed)
          printf '## Open Questions\n\n'
          printf -- '- **IW-1: first question**\n  disposition: answered\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  disposition: deferred\n  rationale: to its own ruling\n\n' ;;
        none)
          printf '## Open Questions\n\nnone filed yet\n\n' ;;
        nosection) ;;
      esac
      printf '## Recommendation\n\n**Recommendation:** %s\n\n**Rationale:** because.\n\n' "$rec"
      printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n\n### Human\n<!-- @auto-tick-on-decide -->\n- [ ] [REVIEW] Approve\n\n'
      printf '## Decision\n\n## Updates\n'; } > "$P/.tasks/active/${id}-fixture.md"
    echo "$P/.tasks/active/${id}-fixture.md"
}

_lib() {  # run a lib function in a clean shell under set -euo pipefail
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" NO_COLOR=1 \
        timeout 120 bash -c "set -euo pipefail; source '$FRAMEWORK_ROOT/lib/colors.sh'; source '$FRAMEWORK_ROOT/lib/review.sh'; $*" 2>&1
}

_blockers() {
    bash -c ". '$FRAMEWORK_ROOT/lib/inception-readiness.sh'; . '$FRAMEWORK_ROOT/lib/task-audit.sh'; inception_handoff_blockers '$1'"
}

_created_file() { find "$P/.tasks/active" -name 'T-*.md' -type f | head -1; }

# ── AC1: filing paths ─────────────────────────────────────────────────────────

@test "AC1 path 1: fw inception start under an agent, rationale only -> EXPLORING" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"; source "$FRAMEWORK_ROOT/lib/inception.sh"
    CLAUDECODE=1 run do_inception_start "explore one" --rationale "worth a look because X"
    [ "$status" -eq 0 ]
    grep -q '^\*\*Recommendation:\*\* EXPLORING' "$(_created_file)"
}

@test "AC1 path 1: no rationale under an agent is still refused" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"; source "$FRAMEWORK_ROOT/lib/inception.sh"
    CLAUDECODE=1 run do_inception_start "explore two"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--rationale required"* ]]
    [ -z "$(_created_file)" ]
}

@test "AC1 path 1: explicit EXPLORING accepted; the operator (--i-am-human) may file GO, logged" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"; source "$FRAMEWORK_ROOT/lib/inception.sh"
    CLAUDECODE=1 run do_inception_start "explicit" --recommendation EXPLORING --rationale "r"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Injected Recommendation: EXPLORING"* ]]
    rm -f "$P"/.tasks/active/T-*.md
    CLAUDECODE=1 run do_inception_start "operator verdict" --i-am-human --recommendation GO --rationale "known"
    [ "$status" -eq 0 ]
    grep -q '^\*\*Recommendation:\*\* GO' "$(_created_file)"
    grep -q -- "--i-am-human" "$P/.context/working/.gate-bypass-log.yaml"
}

@test "AC1 path 2: fw work-on --type inception routes to the same default" {
    CLAUDECODE=1 run timeout 120 "$FRAMEWORK_ROOT/bin/fw" work-on "explore via work-on" --type inception --rationale "because Y"
    [ "$status" -eq 0 ]
    grep -q '^\*\*Recommendation:\*\* EXPLORING' "$(_created_file)"
}

@test "AC1 path 3: create-task.sh under an agent, rationale only -> EXPLORING" {
    CLAUDECODE=1 run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" --name "Explore three" \
        --type inception --description d --owner human --rationale "because Z"
    [ "$status" -eq 0 ]
    grep -q '^\*\*Recommendation:\*\* EXPLORING' "$(_created_file)"
}

@test "AC1 path 3: no rationale refused, invalid value refused, FW_ALLOW_EMPTY_RECOMMENDATION still logs" {
    CLAUDECODE=1 run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" --name "No rat" \
        --type inception --description d --owner human
    [ "$status" -eq 1 ]
    [[ "$output" == *"--rationale"* ]]
    CLAUDECODE=1 run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" --name "Bad" \
        --type inception --description d --owner human --recommendation MAYBE --rationale r
    [ "$status" -eq 1 ]
    [[ "$output" == *"EXPLORING, GO, NO-GO, or DEFER"* ]]
    CLAUDECODE=1 FW_ALLOW_EMPTY_RECOMMENDATION=1 run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "Bypass" --type inception --description d --owner human
    [ "$status" -eq 0 ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$P/.context/working/.gate-bypass-log.yaml"
}

@test "AC1 path 4: the Write/Edit hook accepts EXPLORING and still blocks a template-only block" {
    local f="$P/.tasks/active/T-9101-hook.md"
    local body
    body=$(printf -- '---\nid: T-9101\nworkflow_type: inception\n---\n\n## Recommendation\n\n**Recommendation:** EXPLORING\n\n**Rationale:** r\n')
    run bash -c "jq -n --arg p '$f' --arg c \"\$1\" '{tool_name:\"Write\",tool_input:{file_path:\$p,content:\$c}}' \
        | CLAUDECODE=1 PROJECT_ROOT='$P' python3 '$FRAMEWORK_ROOT/agents/context/check-inception-recommendation.py'" _ "$body"
    [ "$status" -eq 0 ]
    body=$(printf -- '---\nid: T-9101\nworkflow_type: inception\n---\n\n## Recommendation\n\n<!-- **Recommendation:** GO -->\n')
    run bash -c "jq -n --arg p '$f' --arg c \"\$1\" '{tool_name:\"Write\",tool_input:{file_path:\$p,content:\$c}}' \
        | CLAUDECODE=1 PROJECT_ROOT='$P' python3 '$FRAMEWORK_ROOT/agents/context/check-inception-recommendation.py'" _ "$body"
    [ "$status" -eq 2 ]
    [[ "$output" == *"EXPLORING"* ]]
}

# ── AC2: retrofit ─────────────────────────────────────────────────────────────

@test "AC2: retrofit --apply writes an EXPLORING stub, and a second run leaves it alone" {
    { printf -- '---\nid: T-9201\nname: "stub"\nstatus: captured\nworkflow_type: inception\n---\n\n'
      printf '## Recommendation\n\n<!-- **Recommendation:** GO / NO-GO / DEFER -->\n\n## Decision\n'; } \
        > "$P/.tasks/active/T-9201-stub.md"
    source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"; source "$FRAMEWORK_ROOT/lib/inception.sh"
    run do_inception_retrofit_recommendations --apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"WROTE: EXPLORING stub"* ]]
    grep -q '^\*\*Recommendation:\*\* EXPLORING' "$P/.tasks/active/T-9201-stub.md"
    run do_inception_retrofit_recommendations --apply
    [[ "$output" == *"No active inceptions need Recommendation retrofit"* ]]
    [ "$(grep -c '^## Recommendation' "$P/.tasks/active/T-9201-stub.md")" -eq 1 ]
}

@test "AC2: the cron entry still runs the retrofit verb (registry unchanged in shape)" {
    python3 - "$FRAMEWORK_ROOT/.context/cron-registry.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
jobs = d["jobs"] if isinstance(d, dict) else d
j = [j for j in jobs if j["id"] == "inception-retrofit-rec-hourly"][0]
assert "retrofit-recommendations --apply" in j["command"], j["command"]
assert "EXPLORING" in j["description"] and "DEFER stubs" not in j["description"]
PY
}

# ── AC3: review, review-batch, decide ─────────────────────────────────────────

@test "AC3: shared predicate names EXPLORING with the open-question count" {
    local f
    f=$(_inception T-9301 EXPLORING open)
    run _blockers "$f"
    grep -qP '^exploring\tRecommendation is EXPLORING: not ready for decision, 2 question\(s\) open' <<<"$output"
    f=$(_inception T-9302 EXPLORING none)
    run _blockers "$f"
    grep -qP '^exploring\t.*no Open Questions filed yet' <<<"$output"
    f=$(_inception T-9303 GO disposed)
    run _blockers "$f"
    [ -z "$output" ]
}

@test "AC3: fw task review refuses an EXPLORING inception, no link" {
    _inception T-9311 EXPLORING open >/dev/null
    run _lib "emit_review T-9311"
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT READY: T-9311 is EXPLORING"* ]]
    [[ "$output" == *"2 question(s) open"* ]]
    [[ "$output" != *"/inception/T-9311"* ]]
}

@test "AC3: FW_ALLOW_UNREADY_HANDOFF does not open an EXPLORING inception" {
    _inception T-9312 EXPLORING disposed >/dev/null
    run bash -c "FW_ALLOW_UNREADY_HANDOFF=1 PROJECT_ROOT='$P' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' WATCHTOWER_URL=http://test-host:7777 NO_COLOR=1 \
        timeout 120 bash -c \"set -euo pipefail; source '$FRAMEWORK_ROOT/lib/colors.sh'; source '$FRAMEWORK_ROOT/lib/review.sh'; emit_review T-9312\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"READY FOR A RECOMMENDATION: T-9312"* ]]
    [[ "$output" != *"/inception/T-9312"* ]]
}

@test "AC3: fw task review-batch refuses the whole batch when one inception is EXPLORING" {
    _inception T-9321 EXPLORING open >/dev/null
    _inception T-9322 GO disposed >/dev/null
    run _lib "emit_review_batch T-9321 T-9322"
    [ "$status" -ne 0 ]
    [[ "$output" == *"T-9321 is EXPLORING"* ]]
    [ "$(grep -c '/inception/' <<<"$output")" -eq 0 ]
}

@test "AC3: a GO inception with every question disposed still gets its link (control)" {
    _inception T-9331 GO disposed >/dev/null
    run _lib "emit_review T-9331"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/inception/T-9331"* ]]
}

@test "AC3: fw inception decide refuses an EXPLORING inception and writes nothing" {
    local f before
    f=$(_inception T-9341 EXPLORING disposed)
    before=$(md5sum "$f" | cut -d' ' -f1)
    source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/tasks.sh"; source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
    run do_inception_decide T-9341 go --rationale "try" --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"T-9341 is EXPLORING"* ]]
    [ "$(md5sum "$f" | cut -d' ' -f1)" = "$before" ]
}

# ── AC4: ready for a recommendation ───────────────────────────────────────────

@test "AC4: disposed + EXPLORING -> ready-for-recommendation (also with no Open Questions section)" {
    local f
    f=$(_inception T-9401 EXPLORING disposed)
    run _blockers "$f"
    grep -qP '^ready-for-recommendation\t.*ready for a recommendation' <<<"$output"
    f=$(_inception T-9402 EXPLORING nosection)
    run _blockers "$f"
    grep -qP '^ready-for-recommendation\t' <<<"$output"
}

# The shipped audit block, cut out of audit.sh and run against fixtures (T-4380
# pattern): a copy would stay green if the block were broken.
_audit_c006b() {
    awk '/^# C-006b \(T-5226\)/{f=1} f{print} f && /^unset _c6b_f _c6b_kind _c6b_id/{exit}' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh" > "$P/c006b.sh"
    [ -s "$P/c006b.sh" ] || { echo "C-006b block extraction empty" >&2; return 1; }
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" bash -c '
        warn() { printf "WARN|%s|%s|%s\n" "$1" "$2" "$3"; }
        pass() { printf "PASS|%s\n" "$1"; }
        . "$1"' _ "$P/c006b.sh"
}

@test "AC4: audit C-006b WARNs on ready-for-recommendation, not on still-exploring" {
    _inception T-9411 EXPLORING disposed >/dev/null
    _inception T-9412 EXPLORING open >/dev/null
    _inception T-9413 GO disposed >/dev/null
    run _audit_c006b
    [ "$status" -eq 0 ]
    grep -q '^WARN|C-006b: Inception T-9411 is ready for a recommendation' <<<"$output"
    [ "$(grep -c '^WARN' <<<"$output")" -eq 1 ]
}

@test "AC4: audit C-006b passes when nothing waits on a recommendation" {
    _inception T-9421 EXPLORING open >/dev/null
    run _audit_c006b
    grep -q '^PASS|C-006b: No EXPLORING inception is waiting on a recommendation (1 still exploring)' <<<"$output"
}

# The shipped handover Work-in-Progress renderer, cut out and run on fixtures.
_handover_block() {
    awk '/^# Add active tasks sorted by horizon/{s=1; next}
         s && !f && /python3 << .PYEOF./{f=1; next}
         f && /^PYEOF$/{exit}
         f' "$FRAMEWORK_ROOT/agents/handover/handover.sh" > "$P/wip.py"
    [ -s "$P/wip.py" ] || { echo "handover block extraction empty" >&2; return 1; }
    TASKS_DIR_PY="$P/.tasks" WT_URL_PY="http://test-host:7777" PROJECT_ROOT_PY="$P" \
        FRAMEWORK_ROOT_PY="$FRAMEWORK_ROOT" HANDOVER_DIGEST=0 DIGEST_TOP_N=50 python3 "$P/wip.py"
}

@test "AC4: handover lists ready-for-recommendation and exploring apart from awaiting-decision" {
    _inception T-9431 EXPLORING disposed >/dev/null
    _inception T-9432 EXPLORING open >/dev/null
    _inception T-9433 GO disposed >/dev/null
    run _handover_block
    [ "$status" -eq 0 ]
    grep -q '^### Inceptions Ready for a Recommendation' <<<"$output"
    grep -q '^- T-9431: .*ready for a recommendation' <<<"$output"
    grep -q '^### Inceptions Exploring — Not Ready for Decision' <<<"$output"
    grep -q '^- T-9432: ' <<<"$output"
    # Only the GO inception carries a decide link.
    [ "$(grep -c '/inception/' <<<"$output")" -eq 1 ]
    grep -q '/inception/T-9433' <<<"$output"
}
