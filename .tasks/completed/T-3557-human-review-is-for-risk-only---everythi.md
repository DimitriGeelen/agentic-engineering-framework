---
id: T-3557
name: "human review is for risk only - everything else goes to an independent agent
  reviewer that judges, not a script"
description: >
  Replace the D-626 regex classifier (which decides whether a Human criterion is mechanical
  enough to delegate) with an independent agent reviewer as the default, keeping the
  human for risk.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-3445, T-3554, T-3555, T-1443]
created: 2026-09-29T11:17:54Z
last_update: 2026-09-30T07:51:15Z
date_finished: 2026-09-30T07:51:15Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 5            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-09-29T11:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 8
    rationale: blast_radius=5 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=200,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-29T11:30:29Z'
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

# T-3557: human review is for risk only - everything else goes to an independent agent reviewer that judges, not a script

## Problem Statement

Operator, 2026-09-29 (full transcript in `docs/reports/T-3557-agent-reviewer-default.md`):

> *"we want to kick out the rubber stamping, it's just a lot of friction … click,
> click, click, and just pass up. … we want human in the loop for things that have
> high risk … That's all tier 0 or really big UX. But UX you can also test yourself
> … The expected result is a pass, because this and this is the external agent that
> has reviewed it … Or it says it's not good and this is what's needed to bring it to
> good. Or it says, nuclear, escalate to human … It's not binary. Almost never is.
> Interpretation is needed … That's why we want agent reviewer. … Agent, you do it.
> And if we can run scripts to assess parts … that's fine … but it's not only that."*

**Two things are wrong with today's model, and they compound.**

1. **The default is inverted.** D-626 (T-3445) routes a Human criterion to the
   reviewer only if a classifier proves it *deterministic*; everything else stays
   the operator's ("when in doubt, human"). Measured today: 353 open Human criteria
   on the operator's desk, of which **11** are tier-0/bypass. The rest are render
   (197), unclassified (62), act-in-the-world (22), sovereignty (22), taste (21),
   inception (18).
2. **The "reviewer" is a script.** `fw reviewer`, the BVP judge and the arc-driver
   judge all run static code; `--dispatch` runs the same code in an isolated worker.
   Nothing in the review path *interprets*. So "delegate to the reviewer" could only
   ever mean "delegate what a regex can settle" — which is why the classifier had to
   exist, and why its bugs (OBS-571, OBS-572) decided what the operator saw.

**What already exists and is reused, not rebuilt.**
- The verdict contract: `lib/judge_verdict.py` — green / amber / red / unknown;
  a non-green verdict *cannot be constructed* without guidance. That is the
  operator's three outcomes ("good because…", "not good, here's what's needed",
  "escalate") almost word for word; *unknown* is the escalation.
- The judging doctrine: **D-662** (operator, 2026-09-27) — separate parties, the
  judge can refuse, judged against the criteria *and the goal hierarchy*, open tasks
  only, same model allowed for now, multi-model panel deferred not rejected.
  This inception **extends D-662 from BVP scores and arc drivers to Human-criterion
  review**. It does not invent a second doctrine.
- Isolated execution: `lib/termlink_worker.py` (the `--dispatch` substrate).

**What this dissolves.** OBS-572 (the act-in-the-world regex misses "pi installed)"
and "live session") stops mattering: an interpreting reviewer reads T-1774, sees it
needs hardware it cannot operate, and returns *unknown → escalate*. The regex fix
would have patched the layer this inception removes. So A is not built as scoped.

## Assumptions

- **A-1:** most non-risk Human criteria can be judged by an agent that reads the
  artefacts and, where useful, runs scripts or drives the page (Playwright) — it does
  not need the operator's eyes to reach a defensible green/amber/red.
- **A-2:** `lib/judge_verdict.py` is sufficient as the review verdict contract without
  changes; the missing piece is only the interpreting agent behind it.
- **A-3:** operator feedback on UX *after* an agent green is worth more than a
  blocking operator gate before it — the operator said as much ("you just tell me it's
  good and I give you the feedback").

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

- **IW-1: What exactly is "risk" — the set that stays human?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, dialogue segment 3 — "On point 1, yes, that is correct." Stays human: Tier 0, irreversible external acts (publish, deploy, pay, credentials), sovereignty fields. UX moves to the agent reviewer with non-blocking operator feedback afterwards.

- **IW-2: Do inception go/no-go and arc closure move to the agent reviewer too?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, segment 3 — yes, both go to agents. Arc closures are agent-driven "just the same as task closures, unless it is a Tier 0". Inceptions go to agents too, but the reviewer must first judge whether THIS inception needs a human in the loop, on complexity, impact and uncertainty. This lifts T-1259 and T-1671 as default refusals; the build is where those gates are rewired, not this inception.

- **IW-3: How independent must the reviewer be from the builder?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, segment 3 — "the reviewer is not a creator or producer. That is our principle." Independence is a LADDER, not one floor: same agent with another lens, another TermLink agent, TermLink dispatch, a different model from the same vendor, a different vendor, an external agent via OpenRouter, several external agents. The rung is chosen by the impact-risk model (IW-7). This supersedes D-662 item 5's "panel deferred": the panel is now designed in as the top rungs, bought when impact warrants it.

- **IW-7: What is the impact-risk model that picks the review rung?**
  confidence: 2
  disposition: answered
  rationale: Operator 2026-09-29, segment 3 — "we need to have an impact risk model." Impact has two sides: the risk materialising, AND the value the change is meant to bring, so closing something as done without delivering it is itself a risk. The model sets how much to spend on the review, because external review costs money. Agent note: most inputs already exist per task — BVP value, blast_radius, tier, effort, inception voi_score and IW confidence. But the value axis is coarse (5 vectors cover 69% of 494 tasks), so a model leaning on value alone would barely separate tasks. Needs a design and a spend ceiling. ANSWERED 2026-09-30: two questions (must a human decide = hard gate; else impact = max(cost_if_wrong, value_at_stake) picks the rung), inputs all existing, weekly spend ceiling that degrades one rung and says so. Design: docs/reports/T-3557-agent-reviewer-default.md §IW-7.

- **IW-4: What happens to the ~350 open Human criteria already on the operator's desk?**
  confidence: 2
  disposition: answered
  rationale: Operator 2026-09-29, segment 4 — "4 +5 +6", read as assent to the agent's suggested answer, a one-off SWEEP of all open Human criteria through the reviewer (consistent with D-662 "open tasks only"; closed work is never re-reviewed). Reading stated back to the operator in chat; reversible if meant otherwise, and nothing is swept before the build task exists.

- **IW-5: What becomes of the D-626 classifier?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, segment 4 — assent. "deterministic" is dropped as the delegation test; the classifier keeps only the risk carve-outs (tier0, irreversible act-in-the-world, sovereignty) and routes those to the human. It no longer decides what the reviewer may judge, only what the human must.

- **IW-6: Where does an escalation or a red verdict land, so it is not lost?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, segment 4 — assent. Every non-green review verdict is recorded on the T-3555 refusal ledger (the operator's "negative recording"); unknown/escalate surfaces on /approvals; repeats feed the T-3555 recurrence detector.

## Exploration Plan

1. **Spike (≤2h):** point an interpreting reviewer at 5 real open Human criteria of
   different classes (render, unclassified, act-in-the-world) and record the verdicts
   it reaches, with reasons. Tests A-1 on real material, not fixtures.
2. **Measure:** re-cut the 353 by the IW-1 answer — how many stay human.
3. **Design note:** routing, verdict recording, escalation surface (IW-5, IW-6).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** who reviews what (the routing policy); an interpreting agent reviewer as the
default for non-risk Human criteria; reuse of `lib/judge_verdict.py` and D-662;
where non-green verdicts and escalations are recorded.

**OUT:** the multi-model judge panel (D-662: deferred, not rejected); changing the
sovereignty gates on `fw inception decide` / `fw arc close` unless IW-2 is answered
yes by the operator; rewriting existing tasks' criteria text.

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- The spike shows an interpreting reviewer reaching defensible verdicts, with reasons,
  on real criteria — including correctly escalating the ones it cannot verify
- IW-1 yields a bounded "stays human" set the operator agrees with

**NO-GO if:**
- The reviewer's verdicts on the spike set are not defensible (it ticks what it
  cannot have verified), i.e. we would be replacing click-through with auto-through

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

**Evidence (2026-09-30):**
- Escalation spike on 10 real open Human criteria across six classes. The answer key was
  written BEFORE the reviewer ran (docs/reports/T-3557-spike-answer-key.md); the verdicts
  are in docs/reports/T-3557-spike-verdicts.md. Result:
  - 3 of 3 risk criteria escalated (external publish, release-policy ruling, root deploy).
  - 0 of 4 routine criteria escalated.
  - Every green names its evidence: gate fired, live mutex smoke run, headless render,
    `gh pr view`.
  - 1 red found a real defect with a concrete fix.
  - 1 amber correctly kept `--none` human-only.
  - Both GO criteria are met: defensible verdicts with reasons, including correct
    escalation.
- Live use before the spike: 5 render criteria (T-3544, T-3552, T-3553, T-3571, T-3564)
  closed on independent verdicts. The reviewer caught 2 real defects the producer had
  missed (an invisible link, and a sticky bar that did not stick).
- IW-7 designed: docs/reports/T-3557-agent-reviewer-default.md §IW-7. All seven IW
  questions are disposed.
- Surface today: 352 criteria wait on the operator. 194 of them only because the task
  touches a render surface. 55 fall in the classes that stay human (tier0 11,
  act-in-the-world 22, sovereignty 22).

**Rationale:** Operator direction 2026-09-29: rubber-stamping is friction with no value; human-in-the-loop only for Tier 0 and high risk; everything else an independent agent reviewer evaluates interpretively (good+why / not good+what is needed / escalate). The verdict contract already exists (lib/judge_verdict.py green/amber/red/unknown, guidance mandatory on non-green); what is missing is an interpretive agent behind it - every current judge is a static script. Measured: 353 open Human criteria, of which only 11 are tier-0/bypass.

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

**Rationale**: Operator direction 2026-09-29: rubber-stamping is friction with no value; human-in-the-loop only for Tier 0 and high risk; everything else an independent agent reviewer evaluates interpretively (good+why / not good+what is needed / escalate). The verdict contract already exists (lib/judge_verdict.py green/amber/red/unknown, guidance mandatory on non-green); what is missing is an interpretive agent behind it - every current judge is a static script. Measured: 353 open Human criteria, of which only 11 are tier-0/bypass.

**Date**: 2026-09-30T07:51:14Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-29 — ruling applied before the build (operator, verbatim)
"as always use the external reviewer. These are not things I need to decide on review, right? That's low risk stuff. Why are we still using it and not applying our changed approach here?"
— Asked about T-3552/T-3553/T-3544, three render-only [REVIEW] criteria. The agent had routed them to the operator because the D-626 classifier still carves out render surfaces (T-1766) and `fw task delegate` has no route for them. IW-1 already rules UX/render out of the human set; the gap is that nothing applies it yet. Interim path per task: independent agent reviewer on live screenshots → report in docs/reports/T-3557-render-review-2026-09-29.md → on green, criterion moved to Agent with the verdict cited, owner → agent, close with a logged --skip-render-review naming this ruling. The build of T-3557 must remove the need for that bypass.

### 2026-09-30T07:51:14Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator direction 2026-09-29: rubber-stamping is friction with no value; human-in-the-loop only for Tier 0 and high risk; everything else an independent agent reviewer evaluates interpretively (good+why / not good+what is needed / escalate). The verdict contract already exists (lib/judge_verdict.py green/amber/red/unknown, guidance mandatory on non-green); what is missing is an interpretive agent behind it - every current judge is a static script. Measured: 353 open Human criteria, of which only 11 are tier-0/bypass.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5cf95f19
- **Timestamp:** 2026-09-30T07:51:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-ace1dea8
- **Timestamp:** 2026-09-30T07:51:16Z
- **Overall:** CONFIRMED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `T-3544` | task | ✓ pass |
| `T-3552` | task | ✓ pass |
| `T-3553` | task | ✓ pass |
| `T-3571` | task | ✓ pass |
| `T-3564` | task | ✓ pass |

### 2026-09-30T07:51:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
