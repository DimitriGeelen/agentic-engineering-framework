---
id: T-2333
name: "arc-011 milestone-split decision — M1 (single-host AEF-only) vs cross-repo-bound
  monolithic arc"
description: >
  Inception: arc-011 milestone-split decision — M1 (single-host AEF-only) vs cross-repo-bound
  monolithic arc

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-2303, T-2325, T-2326, T-2323, T-2324]
arc_id: arc-011
created: 2026-06-11T15:46:00Z
last_update: '2026-06-11T22:24:16Z'
date_finished: 2026-06-11T16:19:55Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-11T15:48:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2333: arc-011 milestone-split decision — M1 (single-host AEF-only) vs cross-repo-bound monolithic arc

## Problem Statement

arc-011 (parallel-execution-aef) as currently scoped binds closure to substrate
primitives that have not shipped and whose ETA is partly outside this repo's
control. The §9 collaboration-seam invariant ("AEF signs off each delivered
primitive as actually usable") forces arc-011 to stay open until TermLink-side
substrate primitives land — even though six AEF-side workstreams identified by
T-2325 §3 + concretized by T-2326 are buildable on a single host today, with
no substrate dependency.

The operator has three answers to this binding (T-2326 §intent):

1. **REJECT the split.** Keep arc-011 monolithic, substrate-bound.
2. **RESCOPE the split.** Approve some workstreams, defer others.
3. **APPROVE the split.** Treat arc-011 as a two-milestone arc — M1 (single-host
   AEF-only, closeable without substrate) + M2 (multi-host substrate-bound,
   separate sibling arc or post-M1 phase).

This inception forces the decision into a structured GO/NO-GO/DEFER instead of
letting arc-011 drift indefinitely while T-2325/T-2326 artifacts stay un-actioned.

**For whom:** the operator (sovereign on arc structure) + future agents who
will scope downstream inceptions (IC-3/IC-4/IC-5 currently parked because
they presuppose substrate primitives).

**Why now:** T-2325 § primary_targets answers are filed and pushed; T-2326 M1
sketch is filed and pushed; the milestone-split is the next structural
decision the arc needs and the only one the operator can act on with the
artifacts already in place.

## Assumptions

- **A1.** The six substrate-free workstreams identified by T-2326 §1-§6 are
  genuinely AEF-only (no hidden TermLink primitive consumption). Evidence:
  T-2326 §dependencies block. Confidence: 3 (verified by re-reading each
  workstream's file-touch list).
- **A2.** The headline_mechanic on `.context/arcs/parallel-execution-aef.yaml:10-15`
  fires on single-host alone (two `claude -p` subprocesses on one box +
  shared local git tree replaces hub integration queue). Evidence: T-2326 §4
  workstream's exit criterion explicitly traces to the headline_mechanic
  string. Confidence: 3.
- **A3.** A sibling M2 arc (or post-M1 milestone within arc-011) can be filed
  later when TermLink substrate primitives ship; nothing about M1 closure
  precludes or pre-litigates M2's shape. Confidence: 2 (depends on M1
  closure narrative not over-claiming "parallel execution shipped" when
  only single-host did).

## Open Questions

- **IW-1: Does the operator accept the T-2325 §1 sharpening recommendation
  (strike "against shared substrate" from headline_mechanic)?**
  confidence: 2
  disposition: deferred
  rationale: out of scope for milestone-split decision; can be a separate
  Sovereign arc YAML edit AFTER the split lands. Referencing T-2325 §1
  recommendation.

- **IW-2: If APPROVE, what is the build sequencing? File 6 tasks in one
  batch (T-2326 §dependencies sequence) or per-workstream as operator
  prioritises?**
  confidence: 2
  disposition: deferred
  rationale: filing strategy is operator's call post-GO; T-2326 §dependencies
  block already names recommended sequencing (T-2327 § 3 disjoint validator
  FIRST). The build-batch shape can be decided in the first build slice.

- **IW-3: If APPROVE, does M2 become a sibling arc or a milestone within
  arc-011?**
  confidence: 2
  disposition: deferred
  rationale: structural placement of M2 is a follow-up arc-grooming decision;
  T-2325 §4 recommends sibling-arc but operator has not confirmed.

- **IW-4: If RESCOPE, which workstreams are MVP vs deferred?**
  confidence: 1
  disposition: deferred
  rationale: operator's tactical call given budget; T-2326 §dependencies
  block ranks §3 (disjoint validator) as foundational so it would survive
  any RESCOPE.

- **IW-5: If REJECT, what's the next move for arc-011? Park in-progress
  indefinitely, or close NO-GO and re-file when substrate ships?**
  confidence: 1
  disposition: deferred
  rationale: REJECT decision triggers a separate inception (arc-011 wind-down
  strategy); out of scope here.

All IW-N entries are intentionally `disposition: deferred` because this
inception is itself the disposition gate for the operator's choice. The
operator's decision on GO/NO-GO determines whether the IWs become
build-scope, arc-grooming-scope, or moot.

## Exploration Plan

**No new spikes.** The exploration is already done — T-2325 (4 grill responses)
and T-2326 (M1 sketch with 6 concretized workstreams + sequencing DAG) are
the spike artifacts. This inception ratifies (or rejects) their conclusions.

**Time-box:** one operator review session (~30 minutes to walk T-2325 §3 + §4 +
T-2326 §dependencies + this Recommendation block; decide GO/NO-GO/DEFER).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN scope:**
- Decision on arc-011 milestone-split (REJECT/RESCOPE/APPROVE)
- Cross-link existing T-2325/T-2326 artifacts as evidence
- Recommendation = APPROVE with rationale (already filed at task creation)

**OUT of scope:**
- Filing build tasks for any workstream (T-2326 §dependencies notes these
  must NOT pre-empt the operator's decision — cluster-bombing anti-pattern)
- Sharpening the headline_mechanic wording (T-2325 §1 recommendation, separate
  operator-only Sovereign arc YAML edit)
- M2 (multi-host substrate-bound) sibling-arc filing — deferred to post-M1
- Resolving the AEF ADR §6 open questions (those are T-2323/T-2324 inception
  scope; both currently parked captured/later)
- TermLink-side substrate primitive validation — explicitly cross-repo scope

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
- Operator accepts T-2325 §3+§4 analysis that M1 (single-host) is genuinely
  substrate-independent
- Operator accepts T-2326's 6-workstream concretization as buildable
- Operator agrees M2 (multi-host substrate-bound) is structurally separate
  enough to be a sibling arc/milestone rather than a hidden dependency
- Outcome: 6 build tasks become fileable (T-2334+ if sequenced per T-2326
  §dependencies); arc-011 closes M1-only when those land; M2 sibling-arc
  files later when substrate primitives ship

**NO-GO if:**
- Operator wants arc-011 to remain monolithic and wait for substrate (REJECT)
- Operator believes the M1 framing under-states substrate coupling (false
  independence claim)
- Cost of the 6 M1 workstreams exceeds operator's capacity given current
  arc backlog

**DEFER if:**
- Operator wants more dialogue on the M1/M2 boundary before committing
- Operator wants T-2325 §1 sharpening recommendation resolved first
- Operator wants T-2323/T-2324 unparking decisions made first (they would
  cleanly fold into M1 if approved per T-2326 §2 + §3)

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

**Rationale:**

T-2325 §3 + T-2326 §dependencies identified 6 substrate-free workstreams that close M1 without TermLink primitives + a milestone-split that avoids the §9 closure-binding problem. Operator's three answers (REJECT/RESCOPE/APPROVE) need a structured GO/NO-GO surface — this inception is it. Recommendation = GO because the headline_mechanic passes §ACD on consumer side, the 6 workstreams are AEF-only-buildable, and M2 (substrate-bound) becomes a clean sibling arc rather than a hidden cross-repo binding.

**Evidence:**

- **T-2325 grill responses** (`docs/reports/arc-011-grill-me-responses.md`,
  committed at `8e42a8f3b`): answers all 4 arc-011.yaml `grill_me.primary_targets`
  in 369 lines. §1 verdicts headline_mechanic CONSUMER-SIDE (passes §ACD/G-062).
  §2 sharpens wire-evidence-X with 3 falsifiable test scenarios (1A/1B/1C). §3
  enumerates 6 substrate-free workstreams. §4 names the milestone-split as the
  structural counter to cross-repo binding.
- **T-2326 M1 sketch** (`docs/reports/arc-011-m1-single-host-sketch.md`,
  committed at `d21768ab7`): concretizes T-2325 §3's 6 workstreams in 385 lines.
  Each workstream has Files-touched / Size / Cost-rationale / Exit-criterion /
  Headline_mechanic-traceability. §dependencies block ranks §3 (disjoint
  validator, S) as the foundation. Total M1 estimate: 4-7 build sessions.
- **arc-011 yaml** (`.context/arcs/parallel-execution-aef.yaml`): `status:
  in-progress`, `demo_evidence: null`, `grill_me.primary_targets` lists the 4
  questions T-2325 answered. Operator's milestone-split decision either
  validates or rejects the answers.
- **T-2303 scoping inception** (`.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md`):
  IW-3 (parallel-execution-strategy-spike) deferred at GO; M1 split path
  re-opens it as workstream §1 in T-2326.
- **T-2323 + T-2324** (currently parked captured/later by operator): downstream
  inceptions for yield-point granularity + disjoint-write-set policy. T-2326 §2 + §3
  show how each collapses to M1-scope on GO.

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

**Rationale**: Recommendation: GO

Rationale:

T-2325 §3 + T-2326 §dependencies identified 6 substrate-free workstreams that close M1 without TermLink primitives + a milestone-split that avoids the §9 closure-binding problem. Operator's three answers (REJECT/RESCOPE/APPROVE) need a structured GO/NO-GO surface — this inception is it. Recommendation = GO because the headline_mechanic passes §ACD on consumer side, the 6 workstreams are AEF-only-buildable, and M2 (substrate-bound) becomes a clean sibling arc rather than a hidden cross-repo binding.

Evidence:

- T-2325 grill responses (`docs/reports/arc-011-grill-me-responses.md`,
  committed at `8e42a8f3b`): answers all 4 arc-011.yaml `grill_me.primary_targets`
  in 369 lines. §1 verdicts headline_mechanic CONSUMER-SIDE (passes §ACD/G-062).
  §2 sharpens wire-evidence-X with 3 falsifiable test scenarios (1A/1B/1C). §3
  enumerates 6 substrate-free workstreams. §4 names the milestone-split as the
  structural counter to cross-repo binding.
- T-2326 M1 sketch (`docs/reports/arc-011-m1-single-host-sketch.md`,
  committed at `d21768ab7`): concretizes T-2325 §3's 6 workstreams in 385 lines.
  Each workstream has Files-touched / Size / Cost-rationale / Exit-criterion /
  Headline_mechanic-traceability. §dependencies block ranks §3 (disjoint
  validator, S) as the foundation. Total M1 estimate: 4-7 build sessions.
- arc-011 yaml (`.context/arcs/parallel-execution-aef.yaml`): `status:
  in-progress`, `demo_evidence: null`, `grill_me.primary_targets` lists the 4
  questions T-2325 answered. Operator's milestone-split decision either
  validates or rejects the answers.
- T-2303 scoping inception (`.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md`):
  IW-3 (parallel-execution-strategy-spike) deferred at GO; M1 split path
  re-opens it as workstream §1 in T-2326.
- T-2323 + T-2324 (currently parked captured/later by operator): downstream
  inceptions for yield-point granularity + disjoint-write-set policy. T-2326 §2 + §3
  show how each collapses to M1-scope on GO.

**Date**: 2026-06-11T16:19:55Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-11T15:48:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e1dea92d
- **Timestamp:** 2026-06-11T16:19:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-11T16:19:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

T-2325 §3 + T-2326 §dependencies identified 6 substrate-free workstreams that close M1 without TermLink primitives + a milestone-split that avoids the §9 closure-binding problem. Operator's three answers (REJECT/RESCOPE/APPROVE) need a structured GO/NO-GO surface — this inception is it. Recommendation = GO because the headline_mechanic passes §ACD on consumer side, the 6 workstreams are AEF-only-buildable, and M2 (substrate-bound) becomes a clean sibling arc rather than a hidden cross-repo binding.

Evidence:

- T-2325 grill responses (`docs/reports/arc-011-grill-me-responses.md`,
  committed at `8e42a8f3b`): answers all 4 arc-011.yaml `grill_me.primary_targets`
  in 369 lines. §1 verdicts headline_mechanic CONSUMER-SIDE (passes §ACD/G-062).
  §2 sharpens wire-evidence-X with 3 falsifiable test scenarios (1A/1B/1C). §3
  enumerates 6 substrate-free workstreams. §4 names the milestone-split as the
  structural counter to cross-repo binding.
- T-2326 M1 sketch (`docs/reports/arc-011-m1-single-host-sketch.md`,
  committed at `d21768ab7`): concretizes T-2325 §3's 6 workstreams in 385 lines.
  Each workstream has Files-touched / Size / Cost-rationale / Exit-criterion /
  Headline_mechanic-traceability. §dependencies block ranks §3 (disjoint
  validator, S) as the foundation. Total M1 estimate: 4-7 build sessions.
- arc-011 yaml (`.context/arcs/parallel-execution-aef.yaml`): `status:
  in-progress`, `demo_evidence: null`, `grill_me.primary_targets` lists the 4
  questions T-2325 answered. Operator's milestone-split decision either
  validates or rejects the answers.
- T-2303 scoping inception (`.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md`):
  IW-3 (parallel-execution-strategy-spike) deferred at GO; M1 split path
  re-opens it as workstream §1 in T-2326.
- T-2323 + T-2324 (currently parked captured/later by operator): downstream
  inceptions for yield-point granularity + disjoint-write-set policy. T-2326 §2 + §3
  show how each collapses to M1-scope on GO.

### 2026-06-11T16:19:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
