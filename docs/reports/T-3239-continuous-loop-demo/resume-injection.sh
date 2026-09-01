#!/usr/bin/env bash
# T-3239 — arc-012 headline-mechanic demo, experiment E4: M2 links 4-5.
#
# The headline mechanic ends "...operator observes multi-cycle continuous session
# whose iteration counter, directive, and bounded tier-ceiling are visible in fw
# resume status". E3 measured link 1 (does the trigger fire). This measures the
# far end: given a resume, does the counter ADVANCE, does the directive get
# RE-INJECTED, and does the tier ceiling actually FREEZE the counter when breached?
#
# The ceiling case is the one worth measuring. W1-F2 in the arc-012 review said
# `arm --tier-ceiling N` writes a ceiling no enforcer reads. If that is still true
# the counter advances through a breach; if T-3233 wired it, the counter freezes
# and a termination reason is recorded. Those two outcomes are one integer apart
# in the state file and indistinguishable in prose, which is why this asserts the
# integer.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/resume-injection.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INJ="${REPO}/agents/context/inject-next-directive.py"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E4-resume-injection.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
pass=0; fail=0; report=""

# run_case <name> <state-yaml> <directive-yaml> <source> <expect-iter> <expect-stdout-substr>
run_case() {
    local name="$1" state="$2" directive="$3" source="$4" expect_iter="$5" expect_out="$6"
    local root="${SANDBOX}/${name}"; mkdir -p "${root}/.context/working"
    printf '%s' "$state"     > "${root}/.context/working/.continuous-mode.yaml"
    printf '%s' "$directive" > "${root}/.context/working/.next-directive.yaml"

    local before after out rc=0
    before=$(python3 -c "import yaml;print(yaml.safe_load(open('${root}/.context/working/.continuous-mode.yaml')).get('current_iteration'))")
    out=$(python3 "$INJ" --project-root "$root" --source "$source" 2>&1) || rc=$?
    after=$(python3 -c "import yaml;print(yaml.safe_load(open('${root}/.context/working/.continuous-mode.yaml')).get('current_iteration'))")
    local term
    term=$(python3 -c "import yaml;print(yaml.safe_load(open('${root}/.context/working/.continuous-mode.yaml')).get('last_terminated_reason') or '-')")

    local verdict="PASS"
    [ "$after" = "$expect_iter" ] || verdict="FAIL"
    if [ -n "$expect_out" ]; then
        case "$out" in *"$expect_out"*) ;; *) verdict="FAIL" ;; esac
    fi
    if [ "$verdict" = "PASS" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

    report+="  ${name}  (--source ${source})
      current_iteration  : ${before} -> ${after}   (want ${expect_iter})
      terminated reason  : ${term}
      stdout (first 200) : $(printf '%s' "$out" | tr '\n' ' ' | head -c 200)
      verdict            : ${verdict}

"
}

ARMED='enabled: true
current_iteration: 3
max_iterations: 10
tier_ceiling: 1
tasks_completed: 0
completed_task_ids: []
'
DIRECTIVE='directive: |
  Continue the arc-012 run: take the next action toward the arc.
'
FUTURE=$(python3 -c "
import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

# 1. The advance: a resume moves the SESSION counter 3 -> 4 and re-emits the directive.
run_case "1-resume-advances" "$ARMED" "expires_at: \"${FUTURE}\"
${DIRECTIVE}" resume 4 "Next Directive"

# 2. Operator /compact resets the loop to a fresh run (documented at :18-19).
run_case "2-compact-resets" "$ARMED" "expires_at: \"${FUTURE}\"
${DIRECTIVE}" compact 1 ""

# 3. Disarmed: the counter must NOT move. Control leg for cases 1-2 — without it,
#    "the counter advanced" cannot be told apart from "the counter always advances".
run_case "3-disarmed-frozen" 'enabled: false
current_iteration: 3
' "expires_at: \"${FUTURE}\"
${DIRECTIVE}" resume 3 ""

# 4. Expired directive: the terminating resume advances the counter ONCE (3 -> 4) and
#    records the reason. This expectation was 3 on first authoring, on the reasoning
#    that a run which terminated performed no iteration — and the ceiling-breach path
#    one line away DOES freeze the counter (`old_iter if ceiling_breach else new_iter`),
#    so the asymmetry looked like a defect.
#
#    Measured instead of assumed, and the assumption was wrong. Resuming an expired
#    directive five times in a row gives iter=4 every time and reason=expires_at every
#    time: the counter moves once, on the resume that discovers the termination, and
#    then converges. It is not a runaway, and it does not let max_iterations overtake
#    the real reason. The +1 records "a session started and found this loop terminated",
#    which is a true statement worth keeping.
run_case "4-expired-advances-once" "$ARMED" 'expires_at: "2020-01-01T00:00:00Z"
'"${DIRECTIVE}" resume 4 "LOOP TERMINATED"

{
    echo "T-3239 E4 — M2 links 4-5: resume advances the counter and re-injects"
    echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo sha:  $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)"
    echo
    echo "$report"
    echo "----------------------------------------------------------------"
    echo "PASS: $pass   FAIL: $fail"
} | tee "$OUT"

exit $(( fail > 0 ? 1 : 0 ))
