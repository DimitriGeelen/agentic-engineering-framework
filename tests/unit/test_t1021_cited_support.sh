#!/bin/bash
# T-868 (arc-004 S3) — teeth for hypothesis-cited support scores.
#
# WHAT IT DEFENDS. In the source BVP method a support score is an ARGUMENT ABOUT A
# STATED CLAIM: "support 5 on Legal/Regulatory" means something only because the
# hypothesis says what success looks like. Ours matched the task body and emitted
# a number, so it could rank but could not be wrong. Citing the claim is what
# makes a score correctable.
#
# THE DESIGN THIS SUITE EXISTS TO PIN. Citation counts ONLY for a human-written
# hypothesis. After S2 most hypotheses are machine DRAFTS, and a score citing a
# draft is the machine citing itself — indirection that READS as grounded while
# the claim was also machine-made, with an evidence line indistinguishable from
# the real thing. So an unconfirmed draft must NOT be cited, and the evidence
# must say why rather than going quiet.
#
# THE CONTROL THAT MATTERS MOST is scores_unchanged_by_citation. A slice that
# quietly re-ranked the corpus while claiming to add provenance would be the
# worst outcome here, and it is the one nobody would notice: the numbers would
# still look plausible. Measured directly — 483 driver evaluations, 0 score
# differences between the cited and uncited paths.
#
# THE MUTATION DISABLES BOTH READS of hypothesis_source, not one. T-865 shipped a
# guard that lived in two functions; disabling one left the case that mattered
# green and the run correctly refused. Same shape here: declarative_matches does
# the citing, score_declarative writes the basis line.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f "$ROOT/FRAMEWORK.md" ]; then FW_HOME="$ROOT"; else FW_HOME="$ROOT/.agentic-framework"; fi
cd "$ROOT" || { echo "REFUSING: cannot cd to $ROOT"; exit 2; }
SUBJECT="${SUBJECT:-$FW_HOME/agents/termlink/bvp-estimator/estimator.py}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t868.XXXXXX")"
trap 'rm -rf "$WORK"; rm -f "${MUT:-}"' EXIT

PASS=0; FAIL=0
CITE_CASES="human_clause_is_cited basis_names_human_hypothesis"
CONTROL_CASES="draft_is_not_cited no_hypothesis_says_no_claim scores_unchanged_by_citation driver_still_scores"

ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "$2"; }

# Hermetic policy: the probe brings its own declarative driver (832's F4, verbatim), so the
# result does not depend on which drivers the host project happens to declare.
PROJ="$(mktemp -d)"; trap 'rm -rf "$WORK" "$PROJ"; rm -f "${MUT:-}"' EXIT
mkdir -p "$PROJ/policy"
cat > "$PROJ/policy/value-drivers.yaml" <<'POLICYEOF'
version: 3
free_drivers:
- id: F4
  name: V_WORKFLOW_ROUTING
  weight: 9
  protected: false
  rationale: 'operator directive 2026-08-16: anything improving workflow routing /
    clean workflows'
  polarity: positive
  rubric:
    0: No routing or workflow-shape concern touched.
    1: Mentions routing structure (lane, pool, gateway, sequence flow) incidentally.
    2: Changes how one workflow routes or renders, single map or single rule.
    3: Fixes or adds a routing RULE that applies corpus-wide -- validator check, layout
      rule, lane/pool resolution.
    4: Closes a routing loop -- unroutable input is detected and refused rather than
      silently reassigned, or clean-layout is enforced rather than nudged.
    5: Extends the routing substrate itself -- new node/edge semantics, a new routing
      dimension, or cross-workflow dependency routing.
  guardrails: 'Score ROUTING UPLIFT, not "this file happens to be a workflow". Editing
    a map''s content is L0-L1; the value is in rules that hold across the corpus.

    '
  scoring:
    kind: signals
    strip_template: true
    levels:
      1:
        keywords:
        - lane
        - pool
        - gateway
        - sequence flow
        - flownoderef
      2:
        keywords:
        - cleanlayout
        - clean layout
        - mapmessiness
        - routing
        - lane band
        - swimlane
        paths:
        - examples/aef-processes/*.workflow.yaml
        - examples/app-processes/*
      3:
        keywords:
        - workflow validator
        - validator rule
        - layout rule
        - lane resolution
        - pool resolution
        - dialect-relative
      4:
        keywords:
        - silently reassigns
        - unresolvable flownoderef
        - refuses to route
        - routing gate
      5:
        keywords:
        - workflow fabric
        - process-dependency graph
        - new node type
        - callactivity
        - routing substrate
POLICYEOF

grep -q '_cite' "$SUBJECT" || {
    echo "TEETH BROKEN — the citation helper is gone from $SUBJECT."
    echo "This probe can no longer test what it claims to test. Not reporting a pass."
    exit 4; }

HYP='We believe that we add an import guard for lane and pool structure,
we will achieve rejection of malformed BPMN at the designer boundary.
We will know that we are successful when we see 0 fabricated lanes across 24 maps.'

mkfix() { # $1=file $2=extra frontmatter $3=hypothesis body (empty for none)
    { printf -- '---\nid: T-9995\nname: "Fix the importer"\nworkflow_type: inception\n'
      [ -n "${2:-}" ] && printf '%s\n' "$2"
      printf -- '---\n\n# body\n\n'
      [ -n "${3:-}" ] && printf '## Hypothesis\n\n%s\n\n' "$3"
      printf '## Assumptions\n\nnone\n'
    } > "$1"
}

probe() { # $1=file -> prints F4 score + evidence
    PROJECT_ROOT="$PROJ" python3 - "$1" "$SUBJECT" <<'PYEOF'
import sys, importlib.util
from pathlib import Path
tp, subj = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("est", subj)
m = importlib.util.module_from_spec(spec); sys.modules["est"] = m; spec.loader.exec_module(m)
fm, body = m.parse_task(Path(tp))
sp = m._load_driver_specs().get("F4")
if not sp:
    print("NOSPEC"); raise SystemExit(0)
sc, ev = m.score_declarative(sp, fm, body, [])
print("SCORE", sc)
for e in ev:
    print("EV", e)
PYEOF
}

# ── mutation ────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--mutation" ]; then
    MUT="$(dirname "$SUBJECT")/.t868-mutated-$$.py"
    python3 - "$SUBJECT" "$MUT" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
needles = [
    ('    hyp_human = str(fm.get("hypothesis_source") or "").strip().lower() == "human"\n',
     '    hyp_human = False  # MUTANT: citation disabled\n'),
    ('    _src = str(fm.get("hypothesis_source") or "").strip().lower()\n',
     '    _src = "none"  # MUTANT: basis never reports a human hypothesis\n'),
]
missing = [n for n, _ in needles if n not in t]
if missing:
    sys.exit(f"mutation anchor not found — a hypothesis_source read was restructured: {missing}")
for n, r in needles:
    t = t.replace(n, r, 1)
open(dst, "w").write(t)
PYEOF
    [ -s "$MUT" ] || { echo "MUTATION SETUP FAILED: no mutant"; exit 1; }
    python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$MUT" \
        || { echo "MUTATION SETUP FAILED: mutant does not parse"; exit 1; }
    echo "=== T-868 MUTATION RUN (citation disabled at both reads) ==="
    out=$(SUBJECT="$MUT" bash "${BASH_SOURCE[0]}" 2>&1)
    printf '%s\n' "$out" | sed 's/^/  | /'
    echo
    broken=""
    for c in $CONTROL_CASES; do
        printf '%s' "$out" | grep -q "PASS  $c\$" || broken="$broken $c"
    done
    if [ -n "$broken" ]; then
        echo "MUTATION SETUP BROKEN — cases independent of citation also failed:$broken"
        echo "The mutant is not blind, it is broken. Every red above is false."
        exit 1
    fi
    survivors=""
    for c in $CITE_CASES; do
        printf '%s' "$out" | grep -q "PASS  $c\$" && survivors="$survivors $c"
    done
    [ -n "$survivors" ] && { echo "MUTATION FAILED — pass without citation:$survivors"; exit 1; }
    echo "MUTATION OK — controls green, every citation case went red."
    exit 0
fi

echo "=== T-868 cited-support teeth ==="
echo "subject: $SUBJECT"
echo

mkfix "$WORK/human.md" "hypothesis_source: human" "$HYP"
mkfix "$WORK/draft.md" "" "$HYP"
mkfix "$WORK/none.md"  "" ""

out=$(probe "$WORK/human.md")
printf '%s' "$out" | grep -q '@hypothesis:' \
  && ok human_clause_is_cited \
  || bad human_clause_is_cited "a human hypothesis was not cited — the score stays a number with no referent: $(printf '%s' "$out" | grep '^EV' | head -3 | tr '\n' '/')"

printf '%s' "$out" | grep -q 'basis: human hypothesis' \
  && ok basis_names_human_hypothesis \
  || bad basis_names_human_hypothesis "the evidence does not say what the score is an argument about"

out=$(probe "$WORK/draft.md")
if printf '%s' "$out" | grep -q 'unconfirmed DRAFT' && ! printf '%s' "$out" | grep -q '@hypothesis:'; then
    ok draft_is_not_cited
else bad draft_is_not_cited "a machine draft was cited as though it were a claim — that is the machine citing itself while looking like provenance"; fi

out=$(probe "$WORK/none.md")
printf '%s' "$out" | grep -q 'no claim to be wrong about' \
  && ok no_hypothesis_says_no_claim \
  || bad no_hypothesis_says_no_claim "a score with no hypothesis behind it did not say so"

# THE CONTROL THAT MATTERS: citation must be purely additive to evidence. A
# slice that quietly re-ranked while claiming to add provenance is the one
# failure nobody would notice, because the numbers would still look plausible.
moved=$(PROJECT_ROOT="$PROJ" python3 - "$SUBJECT" <<'PYEOF'
import sys, glob, importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location("est", sys.argv[1])
m = importlib.util.module_from_spec(spec); sys.modules["est"] = m; spec.loader.exec_module(m)
specs = m._load_driver_specs()
moved = n = 0
for f in sorted(glob.glob(".tasks/active/*.md")):
    fm, body = m.parse_task(Path(f))
    for did in ("F1", "F3", "F4"):
        sp = specs.get(did)
        if not sp:
            continue
        a, _ = m.score_declarative(sp, dict(fm, hypothesis_source="human"), body, [])
        b, _ = m.score_declarative(sp, dict(fm, hypothesis_source=None), body, [])
        n += 1
        moved += (a != b)
print(f"{moved} {n}")
PYEOF
)
if [ "$(printf '%s' "$moved" | awk '{print $1}')" = "0" ] \
   && [ "$(printf '%s' "$moved" | awk '{print $2}')" -gt 100 ]; then
    ok scores_unchanged_by_citation
else bad scores_unchanged_by_citation "citation moved a score (moved/total: $moved) — this slice must add provenance, not re-rank"; fi

out=$(probe "$WORK/human.md")
s=$(printf '%s' "$out" | grep -m1 '^SCORE' | awk '{print $2}')
if [ -n "$s" ] && [ "$s" -ge 1 ] 2>/dev/null; then ok driver_still_scores
else bad driver_still_scores "the driver stopped scoring entirely (SCORE=$s) — reds elsewhere would be meaningless"; fi

echo
echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
