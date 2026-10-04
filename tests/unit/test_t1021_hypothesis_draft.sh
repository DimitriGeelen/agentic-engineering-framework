#!/bin/bash
# T-867 (arc-004) — teeth for hypothesis drafting.
#
# WHAT IT DEFENDS. S1 gates a GO on a hypothesis. Measured before S2 was built: of
# 14 active inceptions, ~11 are delivery-shaped and NONE carried one — so the gate
# alone stands in front of eleven tasks belonging to the person who said writing
# these is hard. The drafter is the ramp.
#
# THE ONE RULE. The drafter must not invent a success clause. A plausible invented
# metric is WORSE than a blank: it satisfies the gate, reads as considered, and
# commits the project to a claim nobody made. So when the task's own text offers
# nothing checkable, the third clause must carry [NEEDS YOU] and S1 must still
# refuse it. The drafter marks the hole; the gate holds the line; neither pretends
# the task is ready.
#
# TWO MUTATIONS, because the two ways of breaking that rule are independent:
#   --mutation            the drafter FABRICATES instead of marking the gap
#   --mutation-fragment   the trailing-stopword filter is removed
#
# The second is not hypothetical. It reproduces a defect this file's subject
# actually shipped for about ten minutes: the raw patterns returned "80% of the",
# a fragment that means nothing but CONTAINS a digit — so S1's gate would have
# accepted it. A drafter manufacturing signals that pass the gate while saying
# nothing is the fabrication failure arriving through a regex instead of through
# invention, and it was caught by looking at the output rather than by reasoning.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f "$ROOT/FRAMEWORK.md" ]; then FW_HOME="$ROOT"; else FW_HOME="$ROOT/.agentic-framework"; fi
cd "$ROOT" || { echo "REFUSING: cannot cd to $ROOT"; exit 2; }
SUBJECT="${SUBJECT:-$FW_HOME/agents/termlink/bvp-estimator/estimator.py}"
AUDIT="$FW_HOME/lib/task-audit.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t867.XXXXXX")"
trap 'rm -rf "$WORK"; rm -f "${MUT:-}"' EXIT
# T-1005: never write fixture rows into the real append-only sticky ledger (found
# 2026-10-03: two T-9993 rows had leaked into .context/telemetry/bvp-sticky.jsonl).
export FW_BVP_STICKY_TELEMETRY_PATH="$WORK/sticky-tel.jsonl"

PASS=0; FAIL=0
# needs_you_still_refused_by_gate is a CONTROL here, not an honesty case. It
# exercises S1's gate against a hand-built fixture and never touches the drafter,
# so mutating the drafter cannot kill it — the mutation run said so. Fifth time
# today a control set has corrected a classification rather than found a defect.
# It is kept because "the two halves agree" is worth pinning; it is just pinned
# on the gate's side of the seam, not the drafter's.
HONESTY_CASES="no_observable_yields_needs_you needs_you_is_explained_in_evidence"
FRAGMENT_CASES="fragment_is_not_offered_as_observable"
CONTROL_CASES="needs_you_still_refused_by_gate draft_has_three_parts observable_proposed_when_present human_hypothesis_is_sticky existing_prose_never_overwritten non_inception_skipped research_kind_skipped"

ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "$2"; }

grep -q "_draft_hypothesis" "$SUBJECT" || {
    echo "TEETH BROKEN — _draft_hypothesis not found in $SUBJECT."
    echo "This probe can no longer test what it claims to test. Not reporting a pass."
    exit 4; }

mkfix() { # $1=file $2=problem-statement text $3=extra frontmatter $4=hypothesis body
    { printf -- '---\nid: T-9993\nname: "Surface validator findings"\nworkflow_type: inception\n'
      [ -n "${3:-}" ] && printf '%s\n' "$3"
      printf -- '---\n\n# body\n\n## Problem Statement\n\n%s\n\n' "$2"
      [ -n "${4:-}" ] && printf '## Hypothesis\n\n%s\n\n' "$4"
      printf '## Assumptions\n\nnone\n'
    } > "$1"
}

NO_NUMBERS="The panel feels awkward and authors find it confusing to use."
WITH_NUMBERS="We wrote a validator and never showed it to authors; 40% of ERRORs go unseen."
FRAGMENT_BAIT="Adoption sits near 80% of the target for this quarter."

probe() { # $1=file -> prints DRAFT/EVIDENCE/PROTECTED lines
    PROJECT_ROOT="$ROOT" SUBJECT="$SUBJECT" FW_HYPOTHESIS_DRY_RUN=1 python3 - "$1" "$SUBJECT" <<'PYEOF'
import sys, json, importlib.util
from pathlib import Path
tp, subj = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("est", subj)
m = importlib.util.module_from_spec(spec); sys.modules["est"] = m; spec.loader.exec_module(m)
r = m.propose_hypothesis(Path(tp))
print("PROTECTED", r["protected"])
print("NEEDSYOU", r["needs_you"])
print("EVIDENCE", json.dumps(r["evidence"]))
print("DRAFT_START")
print(r["drafted"] or "")
print("DRAFT_END")
PYEOF
}

gate() { # $1=file -> rc of the S1 gate
    ( set +e; source "$AUDIT" 2>/dev/null
      audit_inception_hypothesis "$1" go >/dev/null 2>&1; echo "RC=$?" )
}

# ── mutations ───────────────────────────────────────────────────────────────
run_mut() { # $1=label $2=tag $3=must_die $4=must_live
    MUT="$(dirname "$SUBJECT")/.t867-mutated-$$.py"
    python3 - "$SUBJECT" "$MUT" "$2" <<'PYEOF'
import sys
src, dst, tag = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(src).read()
if tag == "fabricate":
    needle = "    signal = obs[0] if obs else _HYPOTHESIS_NEEDS_YOU\n"
    if needle not in t:
        sys.exit("mutation anchor not found — the NEEDS-YOU fallback was restructured")
    # Fabricate instead of marking the gap. Note this now also breaks the evidence
    # line, which is the point: evidence is derived from the value, so a mutant
    # that changes the value cannot leave the provenance claiming otherwise.
    t = t.replace(needle,
                  '    signal = obs[0] if obs else "a measurable improvement in adoption"  # MUTANT\n', 1)
elif tag == "fragment":
    needle = "            while words and words[-1].lower().strip(\".,;:\") in _OBS_TRAILING_STOPWORDS:\n                words.pop()\n"
    if needle not in t:
        sys.exit("mutation anchor not found — the stopword trim was restructured")
    t = t.replace(needle, "            pass  # MUTANT: stopword trim removed\n", 1)
else:
    sys.exit("unknown tag")
open(dst, "w").write(t)
PYEOF
    [ -s "$MUT" ] || { echo "MUTATION SETUP FAILED: no mutant"; exit 1; }
    python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$MUT" \
        || { echo "MUTATION SETUP FAILED: mutant does not parse"; exit 1; }
    echo "=== T-867 MUTATION RUN ($1) ==="
    local out; out=$(SUBJECT="$MUT" bash "${BASH_SOURCE[0]}" 2>&1)
    printf '%s\n' "$out" | sed 's/^/  | /'
    echo
    local broken="" survivors="" c
    for c in $4; do printf '%s' "$out" | grep -q "PASS  $c\$" || broken="$broken $c"; done
    if [ -n "$broken" ]; then
        echo "MUTATION SETUP BROKEN — cases independent of this mutation also failed:$broken"
        echo "The mutant is not blind, it is broken. Every red above is false."
        rm -f "$MUT"; exit 1
    fi
    for c in $3; do printf '%s' "$out" | grep -q "PASS  $c\$" && survivors="$survivors $c"; done
    rm -f "$MUT"
    [ -n "$survivors" ] && { echo "MUTATION FAILED — pass without the behaviour:$survivors"; exit 1; }
    echo "MUTATION OK ($1) — controls green, every dependent case went red."
}

if [ "${1:-}" = "--mutation" ]; then
    run_mut "drafter fabricates instead of marking the gap" fabricate \
            "$HONESTY_CASES" "$CONTROL_CASES $FRAGMENT_CASES"; exit 0
fi
if [ "${1:-}" = "--mutation-fragment" ]; then
    run_mut "trailing-stopword filter removed" fragment \
            "$FRAGMENT_CASES" "$CONTROL_CASES"; exit 0
fi

echo "=== T-867 hypothesis-drafting teeth ==="
echo "subject: $SUBJECT"
echo

# ── HONESTY: the rule this module exists for ────────────────────────────────
mkfix "$WORK/plain.md" "$NO_NUMBERS"
out=$(probe "$WORK/plain.md")
if printf '%s' "$out" | grep -q '^NEEDSYOU True' && printf '%s' "$out" | grep -q 'NEEDS YOU'; then
    ok no_observable_yields_needs_you
else bad no_observable_yields_needs_you "a body with nothing checkable produced a signal anyway — that is a claim nobody made: $(printf '%s' "$out" | grep -A3 DRAFT_START | tr '\n' '/')"; fi

# The two halves must AGREE. A drafter that marks the gap while the gate accepts
# it would leave the hole invisible at exactly the moment it matters.
mkfix "$WORK/needs.md" "$NO_NUMBERS" "" "We believe that x,
we will achieve y.
We will know that we are successful when we see $(printf '%s' '[NEEDS YOU: name something checkable]')."
if printf '%s' "$(gate "$WORK/needs.md")" | grep -q 'RC=1'; then
    ok needs_you_still_refused_by_gate
else bad needs_you_still_refused_by_gate "S1 accepted a draft whose success clause is an open TODO"; fi


# The evidence must SAY why the gap is there. A marker with no reason reads as a
# bug in the drafter rather than as an honest refusal to invent, and an author
# who thinks it is a bug will paper over it.
out=$(probe "$WORK/plain.md")
if printf '%s' "$out" | grep -q 'signal<-NEEDS-YOU'; then
    ok needs_you_is_explained_in_evidence
else bad needs_you_is_explained_in_evidence "the gap was marked but not explained: $(printf '%s' "$out" | grep EVIDENCE)"; fi

# ── FRAGMENT: the defect the subject actually shipped ───────────────────────
# Asserted against the extractor DIRECTLY rather than through a task fixture.
# The first version of this case fed prose to the whole draft path and failed —
# because "80% of the target for this quarter" ends on a content word and is a
# legitimate candidate. The bait was wrong, not the code. The real defect is
# narrower: a candidate whose tail is a function word ("80% of the") means
# nothing yet contains a digit, so S1's gate would accept it. Testing the filter
# at its own boundary pins exactly that and nothing else.
frag=$(PROJECT_ROOT="$ROOT" python3 - "$SUBJECT" <<'PYEOF'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("est", sys.argv[1])
m = importlib.util.module_from_spec(spec); sys.modules["est"] = m; spec.loader.exec_module(m)
# Each of these ends on a function word or is a bare number: none is an observation.
for s in ("we reached 80% of the", "coverage hit 43 of", "it moved to 12 in the"):
    got = m._candidate_observables(s)
    print(f"{s!r} -> {got}")
PYEOF
)
# `--` is load-bearing: the pattern starts with '-', and without it grep treats
# it as an option, exits non-zero, and the leading `!` turns that error into a
# PASS. Measured — this case went green on a grep usage error before the fix.
if ! printf '%s' "$frag" | grep -qE -- "-> \['"; then
    ok fragment_is_not_offered_as_observable
else bad fragment_is_not_offered_as_observable "a function-word-tailed fragment was offered as a success signal — it means nothing but contains a digit, so the gate would accept it: $(printf '%s' "$frag" | tr '\n' '/')"; fi

# ── CONTROLS ────────────────────────────────────────────────────────────────
out=$(probe "$WORK/plain.md")
n=$(printf '%s' "$out" | grep -c 'We believe that\|we will achieve\|We will know')
if [ "${n:-0}" -ge 3 ]; then ok draft_has_three_parts
else bad draft_has_three_parts "draft is not in the canonical form (matched $n of 3 clauses)"; fi

mkfix "$WORK/num.md" "$WITH_NUMBERS"
out=$(probe "$WORK/num.md")
if printf '%s' "$out" | grep -q '^NEEDSYOU False' && printf '%s' "$out" | grep -q 'ERRORs'; then
    ok observable_proposed_when_present
else bad observable_proposed_when_present "a real figure in the body was not offered — helpful where there is material is half the contract"; fi

mkfix "$WORK/human.md" "$WITH_NUMBERS" "hypothesis_source: human" "We believe that a human wrote this sentence,
we will achieve exactly what it says.
We will know that we are successful when we see 3 reviewers agree."
before=$(md5sum < "$WORK/human.md")
out=$(probe "$WORK/human.md")
after=$(md5sum < "$WORK/human.md")
if printf '%s' "$out" | grep -q '^PROTECTED True' && [ "$before" = "$after" ]; then
    ok human_hypothesis_is_sticky
else bad human_hypothesis_is_sticky "a human-written hypothesis was not protected (protected=$(printf '%s' "$out" | grep '^PROTECTED'), file changed=$([ "$before" = "$after" ] && echo no || echo YES))"; fi

# Sticky must hold on PROSE even without the flag: someone who typed a sentence
# here has said something, flag or no flag.
mkfix "$WORK/prose.md" "$WITH_NUMBERS" "" "Some earlier wording nobody flagged."
out=$(probe "$WORK/prose.md")
if printf '%s' "$out" | grep -q 'already has content'; then ok existing_prose_never_overwritten
else bad existing_prose_never_overwritten "unflagged existing prose would have been replaced — that is OBS-383 rebuilt in a new place"; fi

{ printf -- '---\nid: T-9994\nworkflow_type: build\n---\n\n# body\n'; } > "$WORK/build.md"
out=$(probe "$WORK/build.md")
if printf '%s' "$out" | grep -q '^NEEDSYOU False' && printf '%s' "$out" | grep -q 'DRAFT_START'; then
    d=$(printf '%s' "$out" | sed -n '/DRAFT_START/,/DRAFT_END/p' | sed '1d;$d' | tr -d '[:space:]')
    [ -z "$d" ] && ok non_inception_skipped || bad non_inception_skipped "a build task was drafted a hypothesis"
else bad non_inception_skipped "unexpected probe output for a build task"; fi

mkfix "$WORK/research.md" "$NO_NUMBERS" "inception_kind: research"
out=$(probe "$WORK/research.md")
if printf '%s' "$out" | grep -q 'inception_kind: research'; then ok research_kind_skipped
else bad research_kind_skipped "a declared research inception was drafted a claim it does not make"; fi

echo
echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
