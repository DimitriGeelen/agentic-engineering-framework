---
id: T-2687
name: "promote origin-free band-feasibility to a corpus lint rule"
description: >
  Decide whether the origin-free band-feasibility interval (does ANY band origin place
  every node inside its own declared band, by interval algebra over stored aef:laneMeta
  heights) should graduate from a T-2686 test helper into a first-class fw corpus
  lint rule alongside lane-geometry. Two bounded design calls: (1) node-top vs node-centre
  resolution — 832's laneAtY uses centreY, so the rule must pick a convention or accept
  both; (2) re-baselining the whole corpus against a strictly stronger rule, since
  ordered non-overlapping spans are necessary for feasibility but not sufficient,
  so maps currently clean under lane-geometry may fail this.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-29T21:58:24Z
last_update: 2026-07-29T22:24:31Z
date_finished: 2026-07-29T22:24:31Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-29T22:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T22:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2687: promote origin-free band-feasibility to a corpus lint rule

## Problem Statement

Full artifact: `docs/reports/T-2687-band-feasibility-lint.md`.

T-2686 wrote an origin-free "does any band origin satisfy this declaration" check as a
repair oracle, and it produced the best evidence in that task (an EMPTY interval proves the
declaration unsatisfiable for *every* origin — the evidence class T-2684's rejected band
model could not produce). It currently benefits only two draft maps. Should it graduate into
a `fw corpus lint` rule, and in what relationship to the shipped `lane-geometry` rule?

Why now: 832 said at rail 335 they intend to mirror a geometry-vs-declaration check and want
it to be "a first-class check, not a rendering of the existing rule set". The shape settled
here is the shape handed to them (their T-312).

## Assumptions

- **A-1 (FALSIFIED):** feasibility is strictly stronger than the shipped ordering rule.
  Disproven by measurement — `aef-session-lifecycle` is ordering-DIRTY and
  closed-feasibility-CLEAN, because closed-interval containment lets a node on a shared band
  boundary belong to both adjacent bands. This assumption had already been stated in
  T-2686's Decisions and to 832 at rail 336; both are now retracted (rail 338).
- **A-2 (held):** the check needs no renderer constant. True for the *ordering* rule; **not**
  true for the capacity rule the exploration actually recommends, which needs the node box
  height. That is why the recommendation is gated on 832 rather than on us.
- **A-3 (held):** a corpus-wide survey before relying on a geometric result is worth its
  cost. Second consecutive task where it caught a wrong-but-convincing model.

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: does the rule resolve a node's band from its stored top-y or from its centre,
  and does the choice change any verdict?** 832's `laneAtY` uses `centreY`, so their
  renderer and a top-y rule disagree by the node half-height. A uniform offset shifts the
  feasibility interval without emptying a non-empty one, so it cannot flip a PASS to a
  FAIL — but it can change *which* origins are feasible, and it matters if the rule ever
  reports the interval to a human as advice.
  confidence: 3
  disposition: dissolved
  rationale: reframed by F1 — centre-vs-top is a uniform offset and cannot flip a verdict;
    the verdict-changing choice is open-vs-half-open boundary semantics, which I had not
    considered at filing. The live unknown is node height H (F4), asked of 832 at rail 338.

- **IW-2: how many currently-clean corpus maps fail the stricter check?** Ordered
  non-overlapping spans are necessary for feasibility but not sufficient, so this rule is
  a superset of `lane-geometry`. The survey is cheap (11 maps) and decides whether this is
  a drop-in tightening or a re-baselining exercise with its own repair backlog.
  confidence: 3
  disposition: answered
  rationale: zero — half-open feasibility and ordering agree on all 11 store maps (F2:
    9 clean/feasible, 2 dirty/infeasible). No re-baseline, no repair backlog, and no
    detection gain on the crossing class either.

- **IW-3: does feasibility replace `lane-geometry` or sit beside it?** They report
  different things: `lane-geometry` names an extremal witness *pair* of nodes (actionable —
  it is what resolved v8 to exactly two nodes), while feasibility yields an *interval* and
  no witness. Strictly stronger detection with strictly weaker diagnostics is a real
  trade-off, not an obvious upgrade.
  confidence: 3
  disposition: answered
  rationale: sit beside, as a distinct rule (proposed `lane-overflow`). Replacement is
    disproven — it gains nothing on the crossing class (F2) and would trade an actionable
    witness pair for a bare interval. The value is the orthogonal capacity class (F3).

- **IW-4: is a lane-height defect distinguishable from a node-placement defect?** An empty
  interval says the declaration is unsatisfiable but not *why* — a wrong
  `aef:laneMeta height` and a mis-placed node produce the same emptiness. If the rule
  cannot separate them it will point authors at the wrong fix, which is worse than the
  ordering rule's narrower but correctly-aimed finding.
  confidence: 3
  disposition: answered
  rationale: partly, and better than feared — a per-lane span-vs-height comparison
    localises the defect to one lane and states the shortfall in pixels (−253 on
    draft-knowledge-leveling agent), which points at the height. It cannot decide between
    a taller lane and tighter placement, so the message must name both and prescribe
    neither.

- **IW-5 (raised during exploration, not at filing): is our own detection layer exposed to
  the prose-in-bytes class 832 hit in their T-311?** They preserved doc comments, which put
  prose into exported bytes for the first time, and two of their harnesses broke by counting
  element names quoted inside doc blocks — with the false-GREEN half being the real danger.
  confidence: 3
  disposition: answered
  rationale: BPMN-side checks are immune (corpus_lint and the transition-table rail parse
    via parse_map/ET.fromstring, never regex document text). But 2 of 4 vocabulary-set
    rails admit comment prose into the enforced enum — measured by comment-only injection:
    aef-inception-flow admits 'maybe', aef-audit-cron admits '3'. Latent today, preventive,
    registered as OBS-103. Separating property: immune rails anchor on structural literals,
    exposed rails match loose word patterns.

## Exploration Plan

All four spikes ran; results in the artifact's Findings section.

1. **Corpus survey** (done) — run ordering vs feasibility over all 11 store maps. Produced
   F1 (the falsification) and F2 (the agreement table).
2. **Boundary-semantics comparison** (done) — closed vs half-open containment across the same
   11 maps. Isolated the mechanism at a specific coordinate rather than inferring it.
3. **Blindness proof** (done) — construct a map the ordering rule cannot see and confirm
   feasibility catches it. Produced F3 plus the live −253px instance.
4. **Constant audit** (done) — enumerate every renderer constant the rule would need. Produced
   F4 and the single question to 832 at rail 338.

Unplanned fifth spike, prompted by 832's T-311 report mid-exploration: audit our own
detection layer for the prose-in-bytes class. Produced IW-5 and OBS-103.

## Scope Fence

**IN:** whether the feasibility check becomes a corpus rule; what its boundary semantics must
be; its relationship to `lane-geometry`; what constants it needs and from whom.

**OUT:** implementing the rule (a GO authorises a separate build slice); repairing
`aef-session-lifecycle` (positions, needs an authority call); repairing
`draft-knowledge-leveling` v8 (two-node membership call plus the newly-found overflow, both
the operator's); fixing OBS-103's vocabulary-rail exposure (own task — different subsystem,
different fix, and it is latent).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- The check detects a defect class the shipped `lane-geometry` rule is structurally unable to
  see — proven by construction, not argued
- At least one real instance of that class exists in the corpus (otherwise it is a rule
  looking for a problem)
- Its verdict does not depend on any renderer constant we would have to guess, or the
  constant has a named owner who can state it

**NO-GO if:**
- It merely re-detects what `lane-geometry` already catches (redundant), or catches less
  (regressive)
- It requires guessing a renderer constant — that is the exact T-2684 band-model error and
  the reason 7 phantom findings nearly shipped
- Its findings cannot be localised well enough for an author to act on

## Recommendation

**Recommendation:** GO — for a **different rule than this task proposed.** Not "promote
feasibility as a stronger `lane-geometry`" (that premise is dead) but "ship a new
`lane-overflow` rule for the capacity class, half-open, once 832 states the node height."

**Rationale:** the original premise failed both ways under measurement — feasibility was
*weaker* than the shipped rule under closed boundary semantics (it passes
`aef-session-lifecycle`, which `lane-geometry` correctly flags, because a node on a shared
band boundary satisfies both adjacent bands), and *redundant* under half-open semantics (the
two rules agree on all 11 maps). What survived is orthogonal and real: the ordering rule
compares lanes against each other and is therefore structurally blind to a lane whose own
members span more than its declared height. Proven on a synthetic map, and the corpus already
holds an instance — `draft-knowledge-leveling`'s agent lane overflows by **253px**, on the v8
promotion candidate, a defect the ordering rule never named because it cannot see it. All
three GO criteria are met; the one open input (node box height) has a named owner and is
already asked. This is GO on completed evidence, not a hedge — the class is proven by
construction, the instance measured, the unknown isolated.

**Evidence:**
- Artifact `docs/reports/T-2687-band-feasibility-lint.md` — F1 falsification traced to a
  specific coordinate (band boundary at `y=100`, three nodes on it, bands computed not
  inferred), F2 full 11-map agreement table across both boundary conventions, F3 synthetic
  blindness proof plus the −253px live instance, F4 the single unknown constant
- 5 open questions disposed (1 dissolved with a reframe, 4 answered), including IW-5 raised
  mid-exploration from 832's T-311 report
- OBS-103 registered: 2 of 4 vocabulary-set rails admit comment prose into the enforced enum
  (measured by comment-only injection), the same authority-lie shape one layer over
- Rail traffic: retraction sent at 338 with the counterexample; lane predicate handed to 832
  for their T-312 at 339

**What a GO authorises:** one build slice implementing `lane-overflow` (half-open, per-lane
span-vs-height, message naming the shortfall and both fix options), blocked until 832 answers
the node-height question. It does **not** authorise touching the two maps with live findings —
both are your calls.

**Operator-facing consequence you may want before the promotion decision:**
`draft-knowledge-leveling` v8's agent lane overflows its declared height by 253px. That is a
second, previously unnamed defect on the map awaiting your taste GO, and it is a different fix
from the two-node authority call already routed to you.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** The check is already written and already earned its keep: it produced the only proof-grade evidence in T-2686 (an EMPTY origin interval proves no band origin can satisfy the declaration, versus the shipped ordering rule which is merely necessary). It currently lives in tests/unit/test_t2686_laneset_order.py where only two maps benefit. GO rather than DEFER because the evidence is complete — what remains is two bounded design calls, not missing knowledge. 832 was invited to mirror it at rail 336, so the cross-project shape is already in motion.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: the original premise failed both ways under measurement — feasibility was
*weaker* than the shipped rule under closed boundary semantics (it passes
`aef-session-lifecycle`, which `lane-geometry` correctly flags, because a node on a shared
band boundary satisfies both adjacent bands), and *redundant* under half-open semantics (the
two rules agree on all 11 maps). What survived is orthogonal and real: the ordering rule
compares lanes against each other and is therefore structurally blind to a lane whose own
members span more than its declared height. Proven on a synthetic map, and the corpus already
holds an instance — `draft-knowledge-leveling`'s agent lane overflows by **253px**, on the v8
promotion candidate, a defect the ordering rule never named because it cannot see it. All
three GO criteria are met; the one open input (node box height) has a named owner and is
already asked. This is GO on completed evidence, not a hedge — the class is proven by
construction, the instance measured, the unknown isolated.

**Date**: 2026-07-29T22:24:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-29T22:01:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-07-29T22:24:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** the original premise failed both ways under measurement — feasibility was
*weaker* than the shipped rule under closed boundary semantics (it passes
`aef-session-lifecycle`, which `lane-geometry` correctly flags, because a node on a shared
band boundary satisfies both adjacent bands), and *redundant* under half-open semantics (the
two rules agree on all 11 maps). What survived is orthogonal and real: the ordering rule
compares lanes against each other and is therefore structurally blind to a lane whose own
members span more than its declared height. Proven on a synthetic map, and the corpus already
holds an instance — `draft-knowledge-leveling`'s agent lane overflows by **253px**, on the v8
promotion candidate, a defect the ordering rule never named because it cannot see it. All
three GO criteria are met; the one open input (node box height) has a named owner and is
already asked. This is GO on completed evidence, not a hedge — the class is proven by
construction, the instance measured, the unknown isolated.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fed61ef3
- **Timestamp:** 2026-07-29T22:24:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-b66ae6d2
- **Timestamp:** 2026-07-29T22:24:32Z
- **Overall:** CONFIRMED
- **Claims:** 3

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2687-band-feasibility-lint.md` | file | ✓ pass |
| `T-311` | task | ✓ pass |
| `T-312` | task | ✓ pass |

### 2026-07-29T22:24:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
