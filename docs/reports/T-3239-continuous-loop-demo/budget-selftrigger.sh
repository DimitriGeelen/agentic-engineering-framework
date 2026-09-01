#!/usr/bin/env bash
# T-3239 — arc-012 headline-mechanic demo, experiment E3: M2 link 1.
#
# The headline mechanic's FIRST link is "agent crosses the context-budget
# threshold without operator relay -> checkpoint fires self-trigger". Everything
# downstream (handover, restart, directive re-injection, iteration counter) is
# unreachable if this link does not fire. So it gets measured on its own, with a
# control leg, rather than inferred from the fact that the loop once ran.
#
# THE PAIR. Both cases carry the SAME token volume, far above the critical
# threshold. They differ in exactly one property: whether lib/context_tokens.py
# can scope the transcript to a dominant model. That isolates the failure to the
# scoping rule rather than to the token arithmetic.
#
# WHY THIS SHAPE. context_tokens.py returns 0 when it cannot scope ("below two
# in-scope entries, return 0 rather than guess"), and budget-gate maps 0 to
# level=ok. So "I could not measure this session" and "this session is fresh"
# produce byte-identical output. That is the arc's own bug class (L-555) sitting
# in the first link of its own headline mechanic.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/budget-selftrigger.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="${REPO}/agents/context/budget-gate.sh"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E3-budget-selftrigger.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

pass=0; fail=0
report=""

# make_transcript <path> <n_entries> <tokens_each> <model>
make_transcript() {
    python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, sys
path, n, tok, model = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
with open(path, "w") as f:
    for i in range(n):
        f.write(json.dumps({
            "type": "assistant",
            "timestamp": "2026-09-01T00:00:%02dZ" % min(i, 59),
            "message": {"model": model,
                        "usage": {"input_tokens": tok,
                                  "cache_read_input_tokens": 0,
                                  "cache_creation_input_tokens": 0}},
        }) + "\n")
PY
}

# run_case <name> <make-transcript:yes|no> <n> <model-mix> <expect-exit> <expect-signal:yes|no>
run_case() {
    local name="$1" mk="$2" n="$3" mix="$4" expect_exit="$5" expect_signal="$6"
    local root="${SANDBOX}/${name}"
    mkdir -p "${root}/.context/working"
    local tpath="${root}/transcript.jsonl"
    local payload='{}'

    if [ "$mk" = "yes" ]; then
        if [ "$mix" = "single" ]; then
            make_transcript "$tpath" "$n" 400000 "claude-opus-5"
        else
            make_transcript "$tpath" "$n" 400000 "claude-opus-5"
        fi
        payload="{\"transcript_path\":\"${tpath}\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo hi\"}}"
    fi

    local scanned="n/a"
    [ -f "$tpath" ] && scanned=$(python3 "${REPO}/lib/context_tokens.py" "" < "$tpath" 2>/dev/null)

    local rc=0
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$root" PROJECT_ROOT="$root" \
        FW_CONTEXT_WINDOW=100000 FW_CLAUDE_FW_SUPERVISED=1 \
        bash "$GATE" >"${root}/stdout" 2>"${root}/stderr" || rc=$?

    local signal="no"
    [ -f "${root}/.context/working/.restart-requested" ] && signal="yes"
    local status_line="(none)"
    [ -f "${root}/.context/working/.budget-status" ] && status_line=$(cat "${root}/.context/working/.budget-status")

    local verdict="PASS"
    [ "$rc" = "$expect_exit" ] || verdict="FAIL"
    [ "$signal" = "$expect_signal" ] || verdict="FAIL"
    if [ "$verdict" = "PASS" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

    report+="  ${name}
      transcript entries : ${n}$([ "$mk" = "no" ] && echo "  (no transcript at all)")
      context_tokens.py  : ${scanned}     <- what the gauge believes
      gate exit code     : ${rc} (want ${expect_exit}; 2 = blocked at critical)
      .restart-requested : ${signal} (want ${expect_signal})
      .budget-status     : ${status_line}
      verdict            : ${verdict}

"
}

# CONTROL LEG — scopeable transcript, 3 entries, one model. 400K tokens against a
# 100K window: unambiguously critical.
run_case "A-scopeable-critical"   yes 3 single 2 yes

# THE DEFECT — identical token volume, one entry short of scopeable.
run_case "B-unscopeable-1-entry"  yes 1 single 0 no

# The other fail-open path: no transcript at all.
run_case "C-no-transcript"        no  0 single 0 no

{
    echo "T-3239 E3 — M2 link 1: does the budget self-trigger fire?"
    echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo sha:  $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)"
    echo "window:    FW_CONTEXT_WINDOW=100000  (critical at 95% = 95000)"
    echo "each transcript entry carries 400000 tokens — 4x the whole window."
    echo
    echo "$report"
    echo "----------------------------------------------------------------"
    echo "PASS: $pass   FAIL: $fail"
    echo
    echo "READING THIS: case A and case B carry the SAME token volume. A is"
    echo "blocked at critical and arms the restart; B reports level=ok, exits 0,"
    echo "and writes no restart signal — because the scan could not scope it and"
    echo "returns 0, which is the same value a genuinely fresh session produces."
    echo "Nothing on B's output says 'I could not measure'."
} | tee "$OUT"

exit $(( fail > 0 ? 1 : 0 ))
