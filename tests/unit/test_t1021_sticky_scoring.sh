#!/bin/bash
# T-865 — teeth for automatic inception scoring with STICKY human overrides.
#
# WHAT IT DEFENDS. Operator direction 2026-09-26: rank everything automatically,
# take the human out of scoring — "but if I want to override it then it should
# not be overwritten by an automatic ranking". Sticky is what makes repeated
# auto-scoring safe: if a re-score can paint over a judgement call, re-scoring
# is destructive, nobody runs it often, and the estimates never improve.
#
# THE FAILURE THAT MATTERS IS SILENT. A sticky guard that stops working looks
# exactly like one that works, until someone notices their overrides have been
# quietly erased for weeks. Two consequences for this file:
#   - `bytes_unchanged` asserts the FILE, not just the returned dict. A guard
#     that reports "protected" while the writer rewrites the value anyway would
#     satisfy any check that only reads the return value.
#   - `protection_is_reported` asserts the count reaches the operator. An
#     unreported guard is an unverifiable one, which is the whole thesis of the
#     arc this task sits in.
#
# MUTATION. Stripping the `src == "human"` branch must kill every sticky case
# while the control cases — which do not depend on it — stay green. Controls
# going red means the mutant is broken rather than blind, and every red in that
# run is false; that is reported as MUTATION SETUP BROKEN rather than read as a
# clean kill (the mistake T-849 actually made).

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f "$ROOT/FRAMEWORK.md" ]; then FW_HOME="$ROOT"; else FW_HOME="$ROOT/.agentic-framework"; fi
cd "$ROOT" || { echo "REFUSING: cannot cd to $ROOT"; exit 2; }
SUBJECT="${SUBJECT:-$FW_HOME/agents/termlink/bvp-estimator/estimator.py}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t865t.XXXXXX")"
trap 'rm -rf "$WORK"; rm -f "${MUT:-}"' EXIT

PASS=0; FAIL=0
# WHERE THE PROTECTION ACTUALLY LIVES, corrected after the first mutation run.
# The guard operates at SCORE time (_score_inception_voi prefers the human
# value) — not at a write site, because nothing writes these fields back. The
# first version of this suite asserted "not overwritten" and those cases PASSED
# under the mutant: they were vacuous, true whether the guard existed or not,
# because no writer exists to overwrite anything. They are kept, reclassified as
# controls, because "the file is never rewritten" is still worth pinning — it
# just is not evidence of stickiness.
STICKY_CASES="score_uses_human_value protection_is_reported divergence_is_logged"
CONTROL_CASES="unflagged_value_is_estimated non_inception_is_skipped estimator_still_produces_scores file_is_never_rewritten"

ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "$2"; }

grep -q "propose_inception_inputs" "$SUBJECT" || {
    echo "TEETH BROKEN — propose_inception_inputs not found in $SUBJECT."
    echo "This probe can no longer test what it claims to test. Not reporting a pass."
    exit 4; }

mkfix() { # $1=path $2=extra frontmatter $3=workflow_type
    cat > "$1" <<EOF
---
id: T-9991
name: "Fixture inception"
status: started-work
workflow_type: ${3:-inception}
owner: agent
$2
---

# body

States no leverage whatsoever, so the estimator scores it at the floor.
EOF
}

# ── mutation ────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--mutation" ]; then
    MUT="$(dirname "$SUBJECT")/.t865-mutated-$$.py"
    python3 - "$SUBJECT" "$MUT" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
# STICKINESS LIVES IN TWO PLACES, and the first version of this mutation only
# found one. `propose_inception_inputs` has the REPORTING guard;
# `_score_inception_voi` has the SCORING guard, which is the one that actually
# changes a rank. Disabling only the reporter left score_uses_human_value green
# and the run correctly refused as MUTATION FAILED. "Sticky off" means both.
needles = [
    ('        if src == "human":\n',
     '        if False:  # MUTANT: reporting guard disabled\n'),
    ('    if src == "human" and voi is not None:\n',
     '    if False:  # MUTANT: scoring guard disabled\n'),
]
missing = [n for n, _ in needles if n not in t]
if missing:
    sys.exit(f"mutation anchor not found — a sticky branch was restructured: {missing}")
for n, r in needles:
    t = t.replace(n, r, 1)
open(dst, "w").write(t)
PYEOF
    [ -s "$MUT" ] || { echo "MUTATION SETUP FAILED: no mutant"; exit 1; }
    python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$MUT" \
        || { echo "MUTATION SETUP FAILED: mutant does not parse"; exit 1; }
    echo "=== T-865 MUTATION RUN (sticky guard disabled) ==="
    out=$(SUBJECT="$MUT" bash "${BASH_SOURCE[0]}" 2>&1)
    printf '%s\n' "$out" | sed 's/^/  | /'
    echo
    broken=""
    for c in $CONTROL_CASES; do
        printf '%s' "$out" | grep -q "PASS  $c\$" || broken="$broken $c"
    done
    if [ -n "$broken" ]; then
        echo "MUTATION SETUP BROKEN — cases independent of the guard also failed:$broken"
        echo "The mutant is not blind, it is broken. Every red above is false."
        exit 1
    fi
    survivors=""
    for c in $STICKY_CASES; do
        printf '%s' "$out" | grep -q "PASS  $c\$" && survivors="$survivors $c"
    done
    [ -n "$survivors" ] && { echo "MUTATION FAILED — pass without the guard:$survivors"; exit 1; }
    echo "MUTATION OK — controls green, every sticky case went red."
    exit 0
fi

echo "=== T-865 sticky inception-scoring teeth ==="
echo "subject: $SUBJECT"
echo

export FW_BVP_STICKY_TELEMETRY_PATH="$WORK/tel.jsonl"
mkfix "$WORK/human.md" $'voi_score: 0.9\nvoi_score_source: human\ntarget_blast_radius: 7\ntarget_blast_radius_source: human'
mkfix "$WORK/plain.md" $'voi_score: 0.5'
mkfix "$WORK/build.md" $'voi_score: 0.5' build

OUT="$WORK/out.txt"
PROJECT_ROOT="$ROOT" SUBJECT="$SUBJECT" python3 - "$WORK" "$SUBJECT" > "$OUT" 2>&1 <<'PYEOF'
import sys, json, importlib.util
from pathlib import Path
W, SUBJ = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("est", SUBJ)
m = importlib.util.module_from_spec(spec); sys.modules["est"] = m; spec.loader.exec_module(m)

p = Path(W) / "human.md"; before = p.read_bytes()
r = m.propose_inception_inputs(p)
fm, body = m.parse_task(p)
print("PROTECTED", json.dumps(r["protected"]))
print("DIVERGED", json.dumps(r["diverged"]))
print("STORED_VOI", fm.get("voi_score"))
print("BYTES_SAME", p.read_bytes() == before)
s, ev = m._score_inception_voi(fm, body, [])
print("SCORE_EV", ev[-1])

p2 = Path(W) / "plain.md"
r2 = m.propose_inception_inputs(p2)
print("PLAIN_PROTECTED", json.dumps(r2["protected"]))
print("PLAIN_ESTIMATED", json.dumps(sorted(r2["estimated"])))

p3 = Path(W) / "build.md"
r3 = m.propose_inception_inputs(p3)
print("BUILD_RESULT", json.dumps([r3["protected"], sorted(r3["estimated"])]))

drivers = m._load_drivers()
res = m.estimate_task(Path(W) / "plain.md", drivers)
print("SCORES_N", len(res["scores"]))
PYEOF

# ── STICKY CASES ────────────────────────────────────────────────────────────
# THE CASE THAT ACTUALLY BITES. The score must come from the human's 0.9
# (-> 4), not the estimator's floor 0.2 (-> 1). Everything else about
# stickiness is bookkeeping; this is the behaviour the operator asked for.
if grep -q 'HUMAN-SET, sticky' "$OUT" && grep -q '^SCORE_EV →4 ' "$OUT"; then
    ok score_uses_human_value
else
    bad score_uses_human_value "the score ignored the human value and used the estimate: $(grep '^SCORE_EV' "$OUT")"
fi

grep -q '^PROTECTED \["voi_score", "target_blast_radius"\]$' "$OUT" \
  && ok protection_is_reported \
  || bad protection_is_reported "protection not reported to the caller: $(grep '^PROTECTED' "$OUT")"

if grep -q '^DIVERGED \["voi_score", "target_blast_radius"\]$' "$OUT" \
   && [ "$(grep -c '"field"' "$WORK/tel.jsonl" 2>/dev/null || echo 0)" -ge 2 ]; then
    ok divergence_is_logged
else
    bad divergence_is_logged "the human-vs-estimate delta was not recorded; it cannot be reconstructed later"
fi

# ── CONTROL CASES — independent of the sticky branch ────────────────────────
if grep -q '^PLAIN_PROTECTED \[\]$' "$OUT" \
   && grep -q '^PLAIN_ESTIMATED \["target_blast_radius", "voi_score"\]$' "$OUT"; then
    ok unflagged_value_is_estimated
else
    bad unflagged_value_is_estimated "an unflagged value was not estimated: $(grep '^PLAIN_' "$OUT" | tr '\n' ' ')"
fi

grep -q '^BUILD_RESULT \[\[\], \[\]\]$' "$OUT" \
  && ok non_inception_is_skipped \
  || bad non_inception_is_skipped "a build task was treated as an inception: $(grep '^BUILD_RESULT' "$OUT")"

# Control: the file is never rewritten by a scoring pass. True with or without
# the guard (nothing writes these fields), which is precisely why it is a
# control and not evidence of stickiness — see the note by STICKY_CASES.
grep -q '^BYTES_SAME True$' "$OUT" \
  && ok file_is_never_rewritten \
  || bad file_is_never_rewritten "a scoring pass rewrote the task file"

n=$(grep -m1 '^SCORES_N' "$OUT" | awk '{print $2}')
if [ -n "$n" ] && [ "$n" -ge 4 ] 2>/dev/null; then ok estimator_still_produces_scores
else bad estimator_still_produces_scores "scoring broke entirely (SCORES_N=$n) — reds elsewhere would be meaningless"; fi

echo
echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
