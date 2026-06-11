---
id: T-2186
name: "Recalibrate inception workflow — make inceptions first-class + prioritizable
  (VoI scoring, disposition gate, park state)"
description: >
  Research inception: today's prioritization (horizon + arc-focus) does not rank inceptions
  against each other, and the task estimator scores inceptions as if they were build
  tasks (low blast_radius/tier/effort → LV/LC quadrant) — exactly backwards for the
  highest-leverage moves the framework makes. This inception recalibrates the workflow
  so inceptions are first-class and prioritizable via value-of-information (VoI) scoring,
  a disposition-rationale gate, and a Sovereign investment-decision park state. Seed
  prompt + open questions IW-1..IW-7 + deliverables live in docs/reports/T-2186-recalibrate-inception-workflow-seed.md.
  Producer≠judge principle is consumed
  here as given — its governance elevation is a separate spin-out. Step 0 (discovery
  prerequisite) must be done before any working conclusion is treated as fact. No
  build tasks before fw inception decide go.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [inception, workflow, prioritization, bvp, governance]
components: []
related_tasks: []
created: 2026-06-02T21:18:05Z
last_update: '2026-06-11T22:24:10Z'
date_finished: 2026-06-02T22:07:51Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-02T21:20:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T21:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
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
  - ts: '2026-06-02T21:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2186: Recalibrate inception workflow — make inceptions first-class + prioritizable (VoI scoring, disposition gate, park state)

## Problem Statement

Today's prioritization (horizon + arc-focus) does not rank inceptions against each other.
Worse, the BVP estimator scores inceptions as if they were build tasks — near-floor
cost (low blast_radius/tier/effort) + weak direct-directive support lands them in the
LV/LC "trivial" quadrant. That is exactly backwards: inceptions are among the
highest-leverage moves the framework makes, since they decide *whether and how* a
downstream class of work will help D1–D4. Without a way to rank inceptions, the
backlog mis-allocates discovery capacity.

**Full seed material:** [docs/reports/T-2186-recalibrate-inception-workflow-seed.md](../../docs/reports/T-2186-recalibrate-inception-workflow-seed.md)
— the human-supplied scope prompt with agent orientation, working conclusions to
pressure-test, Step 0 discovery prerequisite, the seven open questions (IW-1…IW-7),
deliverables, and constraints. Read the seed in full before any working conclusion is
treated as fact.

## Assumptions

The seed contains 8 working conclusions framed as "from prior reasoning — to be
confirmed, sharpened, or refuted." They MUST be pressure-tested by Step 0 against
ground truth, not assumed. Register each as a formal assumption with
`fw assumption add` once Step 0 names what to verify against. The eight in the seed:

- A1: Inception value is anticipatory (value-of-information), not intrinsic
- A2: `blast_radius` and `tier` flip from cost to value/risk for inceptions
- A3: Arc-anchored inceptions inherit arc BVP (Model B); orphan inceptions score by VoI
- A4: No new ceremony, no new "kind" — extend the existing workflow with a gate state
- A5: Gate is dispositions-with-rationale, not predicates ("answered/deferred/dissolved")
- A6: Producer ≠ judge — a separate entity scores; scrutiny scales with stakes
- A7: After the gate, fork to direct-build OR park in investment-decision state
- A8: `work-started` → `discovery-started` rename is implementation, not principle

## Exploration Plan

Time-boxed sequence (full detail in the seed):

1. **Step 0 — Discovery prerequisite.** Map the ACTUAL inception lifecycle (states,
   transitions, mandatory-vs-optional checks) in `010-TaskSystem`, `lib/`, `fw`
   inception verbs, `040-ValueDrivers`. Confirm or refute each assumption above.
   Output: Discovery note section A.
2. **Work IW-1…IW-7 to dispositions.** Each open question gets *answered* (with
   verifiable evidence), *deferred* (with reason + follow-up), or *dissolved*
   (question was malformed). Never binary "yes/no" — the §ACD discipline applies.
3. **Recalibrated lifecycle spec.** States, transitions, the gate, the park state,
   the rename. Contracts tight; judgments named with adjudicators, not predicates.
4. **Prioritization mechanism.** VoI math + inherit-vs-VoI routing + blast/tier
   sign-flip — slotted into 040 (math) and the inception doc (placement).
5. **Constituent build-task slices** as runnable `fw task create` invocations —
   filed only after `fw inception decide go`.

## Technical Constraints

This is a research inception — no platform/network/hardware constraints. The relevant
constraints are framework-internal:

- §ACD (Arc Completion Discipline) — the gate proposal MUST embody evidence-or-
  justified-absence, not a checkbox a "yes" can satisfy
- Producer ≠ judge — consumed as given; do NOT re-legislate (separate spin-out owns
  governance elevation)
- Inception 2-commit exploration limit — `fw inception decide` is mandatory before
  any build-task slice fires
- The recalibration MUST fit the existing inception lifecycle's mandatory-vs-optional
  pattern (Step 0 names this) — no parallel ceremony

## Scope Fence

**IN scope:**
- Inception workflow recalibration (states, gate, park state, rename)
- Inception scoring (VoI math, blast/tier sign-flip for `workflow_type: inception`)
- Inherit-vs-VoI routing for arc-anchored vs orphan inceptions
- 040 ↔ inception-doc ownership seam
- Documentation home recommendation (IW-7)
- Constituent build-task slices (filed only after `decide go`)

**OUT of scope:**
- Producer ≠ judge governance elevation (separate spin-out — see seed §"The seed")
- Build-task workflow changes (only inceptions are being recalibrated)
- Arc scoring changes (arc BVP stays as Model B; this inception consumes it)
- Estimator implementation rewrites (proposal layer only; build slices follow `decide go`)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — Step 0 confirmed LV/LC clustering on T-2186 itself (BVP=24/175 = 14%, cost ≈ 1.2); rubric-mechanism floor + blast_radius=0 structural floor are the real pathologies. Evidence: `docs/reports/T-2186-recalibrate-inception-workflow-seed.md` §"Step 0 Findings" F0.5, F0.6
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested — 8 working conclusions mapped to CONFIRMED / PARTIALLY-REFUTED / REFUTED / CARRY in Step 0 verdict table (3 need sharpening: A2 tier-side, A7 already-deployed redundancy, A8 terminology error). Evidence: seed §"Step 0 verdict on the seed's 8 working conclusions"
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale — see ## Recommendation below

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
- Step 0 identifies the actual mechanism behind LV/LC mis-categorisation (✓ done: blast_radius=0 structural floor + value-rubric mechanism-rewarding floor)
- IW-1..7 each reach a defensible disposition with verifiable rationale (✓ done; see seed §"IW-1..7 Dispositions")
- Constituent build-task slices are bounded and individually fits-one-session-sized (✓ done; 8 slices listed in seed §"Constituent Build-Task Slices")
- Producer ≠ judge pattern is REUSED, not re-invented (✓ done; recalibration slots into existing reviewer-agent + bvp confirm + $CLAUDECODE=1 lockout layers)

**NO-GO if:**
- The blast_radius=0 floor turns out NOT to be the dominant mis-scoring driver (would require fresh measurement across more inceptions)
- IW-2 non-circularity claim fails when verified against `lib/arc.sh` BVP rollup (carries blocking risk for Model B)
- The Sovereignty call on IW-7 (own-doc vs 010-section) cannot be made without further dialogue

## Verification

# Inception verification: confirm the seed/research artifact carries the
# evidence the Recommendation cites. L-387-safe: here-string, no pipe.
test -f docs/reports/T-2186-recalibrate-inception-workflow-seed.md
out=$(cat docs/reports/T-2186-recalibrate-inception-workflow-seed.md); grep -q "Step 0 Findings" <<<"$out"
out=$(cat docs/reports/T-2186-recalibrate-inception-workflow-seed.md); grep -q "IW-1..7 Dispositions" <<<"$out"
out=$(cat docs/reports/T-2186-recalibrate-inception-workflow-seed.md); grep -q "Constituent Build-Task Slices" <<<"$out"
out=$(cat docs/reports/T-2186-recalibrate-inception-workflow-seed.md); grep -q "Dialogue Log" <<<"$out"

## Recommendation

**Recommendation:** GO (with one pending Sovereignty call on IW-7 — own-doc vs 010-section)

**Rationale:** Step 0 confirmed the seed's premise (inceptions cluster LV/LC) and sharpened the mechanism (it's `blast_radius=0` structural floor + value-driver mechanism-rewarding rubrics, not the seed's claimed tier/blast sign-flip — tier already costs more for inceptions). IW-1..7 each reached a defensible disposition; three of the seed's eight working conclusions needed refutation/sharpening but the *prescription* survives: an inception-aware VoI scoring exception in `policy/value-drivers.yaml` + a disposition gate in `update-task.sh` + reuse of the existing three-tier judge ladder. No new ceremony; 8 small build slices, each fits one session.

**Evidence:**
- **The pathology is real:** T-2186 itself (this very task) scores BVP=24/175 = 14% with cost ≈ 1.2 → LV/LC quadrant. Evidence: `agents/termlink/bvp-estimator/estimator.py:531` (COST_WORKFLOW_TIER), `:537` (score_blast_radius reads `components:`); `policy/value-drivers.yaml` driver rubrics.
- **Producer ≠ judge already shipped:** `lib/inception.sh:106` ($CLAUDECODE=1 lockout on decide), `lib/bvp.sh` (bvp confirm §ACD-gated), `lib/reviewer/static_scan.py` (T-1985 auto-tick), AC prefix ladder T-1811. The recalibration adds nothing new in principle — it reuses these.
- **Hardening pattern fits:** `agents/task-create/update-task.sh` already hosts 10 verb-gates with `--skip-<name>` + `FW_SKIP_*` bypass. The new disposition gate slots in identically.
- **Park state already exists:** DEFER + horizon:later (T-1865) + revisit_at/revisit_evidence_needed frontmatter. No new state needed.
- **A meta-finding emerged during execution:** the 2-commit inception exploration limit treated this task's filing+demote storage commits as exploration, blocking the Step 0 findings commit. Live evidence that commit-counting semantics need recalibration alongside the scoring. Captured in Step 0 commit `7fb0de956` and Dialogue Log.
- **Three seed working conclusions need correction in the spec:** A2 (sign-flip wrong on tier — tier already costs more), A7 (producer≠judge already widely deployed — reuse, don't invent), A8 (rename built on non-existent terminology — `started-work` not `work-started`). Spec reflects sharpened versions, not seed-verbatim.

**Pending human Sovereignty call:** IW-7 — own numbered system doc (`docs/system/050-Inceptions.md`) vs section of `010-TaskSystem.md`. Recommendation: own-doc (rationale in seed §"IW-7"); counter-argument fairly presented; this is the only IW question whose disposition is "recommend, human decides" rather than "answered".

**Constituent build-task slices:** 8 slices listed in seed §"Constituent Build-Task Slices" — each sized for one session. Filed ONLY after `fw inception decide T-2186 go`. The keystone is Slice 1 (doc), gated by IW-7 Sovereignty decision.

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

**Rationale**: Step 0 confirmed the seed's premise (inceptions cluster LV/LC) and sharpened the mechanism (it's `blast_radius=0` structural floor + value-driver mechanism-rewarding rubrics, not the seed's claimed tier/blast sign-flip — tier already costs more for inceptions). IW-1..7 each reached a defensible disposition; three of the seed's eight working conclusions needed refutation/sharpening but the *prescription* survives: an inception-aware VoI scoring exception in `policy/value-drivers.yaml` + a disposition gate in `update-task.sh` + reuse of the existing three-tier judge ladder. No new ceremony; 8 small build slices, each fits one session.

**Date**: 2026-06-02T21:58:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-02T21:20:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-06-02T21:24:02Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-02T21:25:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-06-02T21:25:46Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-02T21:33:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6b450018
- **Timestamp:** 2026-06-02T22:07:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-02T21:58:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Step 0 confirmed the seed's premise (inceptions cluster LV/LC) and sharpened the mechanism (it's `blast_radius=0` structural floor + value-driver mechanism-rewarding rubrics, not the seed's claimed tier/blast sign-flip — tier already costs more for inceptions). IW-1..7 each reached a defensible disposition; three of the seed's eight working conclusions needed refutation/sharpening but the *prescription* survives: an inception-aware VoI scoring exception in `policy/value-drivers.yaml` + a disposition gate in `update-task.sh` + reuse of the existing three-tier judge ladder. No new ceremony; 8 small build slices, each fits one session.

### 2026-06-02T22:07:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
