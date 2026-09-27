---
id: T-3524
name: "separate the judge from the producer: a BVP scoring reviewer agent and an arc-driver
  reviewer agent"
description: >
  Operator proposal 2026-09-27, responding to the producer-not-judge waiver recorded
  in D-661/T-3523: 'we should use the external reviewer for that, right? We should
  then have a BVP agent for that. A BVP and an ArcScopeDriver agent or two agents.'
  THE PROBLEM IT SOLVES: D-661 legs 1+2 let an agent confirm its own task's value
  scores and tune its arc's driver weights. Taking the human out of the path removed
  the only party that was not the producer. An independent reviewer AGENT restores
  the separation without putting the operator back in the loop — the human keeps the
  sticky override (T-3523) rather than the approval step. WHAT ALREADY EXISTS, so
  this is not built from nothing: (a) agents/termlink/bvp-estimator/ PROPOSES task
  scores by heuristic; (b) lib/arc-driver-review.sh is an external value-driver reviewer
  but a STATIC check, answering scorable/distinct/distinguishes — it never judges
  whether a score is RIGHT; (c) T-1951 established the isolated-reviewer-as-TermLink-worker
  pattern (fw reviewer --dispatch). So the missing party is a JUDGE, and the pattern
  for running one already ships. THE SHARP QUESTION, and the reason this is an inception
  and not a build: if ONE agent both approves the drivers (the yardstick) and scores
  tasks against them (the measurement), it is judging with a yardstick it made — the
  same defect one level up. Two agents preserve that separation; one agent is cheaper
  to maintain and shares the rubric. Scope is >3 new files and a new subsystem, so
  G-020 requires inception.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [bvp, arc, agents, producer-not-judge]
components: []
related_tasks: [T-3523, T-3429, T-1951, T-3410]
created: 2026-09-27T19:20:38Z
last_update: 2026-09-27T19:53:05Z
date_finished: 2026-09-27T19:53:05Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-27T19:22:36Z'
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
cost_estimate_proposed:
  - ts: '2026-09-27T19:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=177,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3524: separate the judge from the producer: a BVP scoring reviewer agent and an arc-driver reviewer agent

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## The four parties, and which one is missing

| party | exists? | what it does |
|---|---|---|
| **producer** | yes | the agent doing the work, which under D-661 also confirms its own scores |
| **proposer** | yes — `agents/termlink/bvp-estimator/` | heuristic, writes `bvp_scores_proposed:` / `cost_estimate_proposed:` |
| **driver quality checker** | yes — `lib/arc-driver-review.sh` (T-3429) | STATIC: scorable / distinct / distinguishes. Never asks whether a score is *right* |
| **judge** | **NO** | nothing independently reviews a proposed score and confirms it |

The operator keeps a fifth role that is not a party to the judgement: the **sticky
override** (T-3523). That is deliberate — it is a veto after the fact, not an approval
step in the path.

## The argument for TWO agents rather than one

A scoped driver is the **yardstick**. A task score is the **measurement**. One agent
holding both is judging with a yardstick it made — producer-not-judge reproduced one
level up, which is the exact defect this proposal exists to close.

Cost of two: two AGENT.md prompts, two dispatch paths, some duplicated rubric
knowledge. Cost of one: the separation this is being built for.

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

All five answered by the operator on 2026-09-27; recorded as **D-662**.

- **IW-1: One agent or two?**
  confidence: 3
  disposition: answered
  rationale: **TWO.** Operator: *"On one, two agents."* Confirms the leaning — a
  scoped driver is the yardstick and a task score is the measurement, so one agent
  holding both would judge with a yardstick it made.

- **IW-2: Does the judge get to REFUSE a score, or only flag it?**
  confidence: 3
  disposition: answered
  rationale: **It can refuse, and the verdict is THREE-STATE, not binary.** Operator:
  *"Yes, a judge can refuse. If it's not green, then it's amber or red. The [producer]
  needs to adjust, but the reviewer also needs to give guidance on what to do."*
  So: green / amber / red, and **a non-green verdict must carry actionable guidance**,
  not just a rejection. That second half is the part that matters — it is the
  difference between this and the `[REVIEWER]` adoption failure (7 against 412), where
  a verdict with nothing to act on got routed around.
  Wording note, not silently resolved: the operator said *"the dictator needs to
  adjust"*. Read as **the producer**, since nothing else in the design dictates a
  score. Worth confirming if amber/red routing turns out to depend on who adjusts.

- **IW-3: What does the judge judge AGAINST?**
  confidence: 3
  disposition: answered
  rationale: **Two things, and the second is the one that dissolves my objection.**
  Operator: *"the acceptance criteria we have defined in the create inception task or
  complete inception task. I think we already have quality criteria, right? So we look
  at is it there, and we also do a quality assessment whether we find it's good enough
  or not. And we should map that either against the task goal and objective, or the arc
  goal or objective, or the project goal and objective."*
  So the judge assesses (a) **presence** — are the acceptance/quality criteria there —
  and (b) **sufficiency** — are they good enough; then maps the work to the **goal
  hierarchy at the right level**: task → arc → project objective.
  **This answers the objection I raised.** I had argued a judge needs a readable
  yardstick and the rubric's detectors cannot supply one (D2 no-signal 83% over 3,350
  tasks, T-3408). The operator's answer is that the yardstick is not the detector table
  — it is the goal hierarchy the work is supposed to serve, which is written down and
  readable. That makes the judge buildable WITHOUT waiting on T-3410, and reframes
  T-3410 as an improvement to the proposer rather than a prerequisite for the judge.

- **IW-4: New scores only, or the 3,350 already scored?**
  confidence: 3
  disposition: answered
  rationale: **Open tasks only; closed work is never rescored.** Operator: *"we don't
  need to rescore anything that's already done, that's closed. We can rescore things
  that are still outstanding, of course. That are still open, that are still on the
  horizon."*
  This kills the 3,350-item backlog risk outright — the reviewable population is open
  tasks, which is ~492 active and in practice the subset with a horizon. It also
  protects history: a closed task's score stays as the record of what was decided at
  the time, which is the same reasoning T-3068 used for not reinterpreting the
  fabricated zeros already in frontmatter.

- **IW-5: May the judge be the same MODEL as the producer?**
  confidence: 3
  disposition: answered
  rationale: **Yes for now; a multi-model panel is a named future option, explicitly
  not built.** Operator: *"Yes, the judge may be the same model as the producer.
  Although, we could also consider for high impact, high value, high cost things to use
  two or three judges with different models or even different providers. But we're not
  there yet, I think. Let's keep it simple for now."*
  Recorded so it is not lost: **a 2-3 judge panel across different models or providers,
  triggered by high impact / high value / high cost**, is deliberately deferred, not
  rejected. My caveat stands unresolved rather than dismissed — independence of party
  is not independence of judgement, and T-3408 measured two independent corpora landing
  within one point on the same blind spot. The panel is the mitigation for that; the
  operator's call is that it is not worth its cost yet, which is a scoping judgement,
  not a disagreement with the caveat.

## Exploration Plan

Settled by D-662; these are the build slices this inception would authorise on GO.

1. **S1 — the arc-driver judge agent.** Judges a scoped driver against the arc's goal
   and objective. Wraps, does not replace, the existing static
   `lib/arc-driver-review.sh` checks (scorable / distinct / distinguishes).
2. **S2 — the BVP score judge agent.** Judges a proposed task score against (a) the
   presence of acceptance/quality criteria and (b) their sufficiency, mapped to the
   goal hierarchy at the right level: task → arc → project.
3. **S3 — the three-state verdict and its guidance.** green / amber / red, where a
   non-green verdict MUST carry actionable guidance. The guidance is the deliverable,
   not the colour — a verdict with nothing to act on is what produced the 7-against-412
   `[REVIEWER]` adoption gap.
4. **S4 — population scoping.** Open tasks only; closed work is never rescored.
5. **S5 — dispatch wiring.** Reuse T-1951's isolated-reviewer-as-TermLink-worker
   pattern rather than inventing a second one.

**Explicitly OUT of scope** (named so it is not quietly built): the multi-model /
multi-provider judge panel from IW-5, and any change to the estimator's detectors
(that is T-3410, and IW-3's answer means the judge no longer waits on it).

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Rationale:** GO on the exploration, with a stated leaning: TWO agents, because a single agent that both defines the yardstick (arc-scoped drivers) and applies it (task scores) reproduces producer-not-judge one level up, which is precisely the defect the operator is trying to close. Evidence this is tractable rather than speculative: three of the four parties already exist — the estimator proposes (agents/termlink/bvp-estimator/), the static driver reviewer checks driver quality (lib/arc-driver-review.sh, T-3429), and T-1951 already runs a reviewer as an isolated TermLink worker with results on the fw bus. What is missing is the judging half and the handoff. Not a build task: >3 new files and a new subsystem, so G-020 requires scoping first, and the one-agent-or-two question changes the file layout materially.

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

**Rationale**: GO on the exploration, with a stated leaning: TWO agents, because a single agent that both defines the yardstick (arc-scoped drivers) and applies it (task scores) reproduces producer-not-judge one level up, which is precisely the defect the operator is trying to close. Evidence this is tractable rather than speculative: three of the four parties already exist — the estimator proposes (agents/termlink/bvp-estimator/), the static driver reviewer checks driver quality (lib/arc-driver-review.sh, T-3429), and T-1951 already runs a reviewer as an isolated TermLink worker with results on the fw bus. What is missing is the judging half and the handoff. Not a build task: >3 new files and a new subsystem, so G-020 requires scoping first, and the one-agent-or-two question changes the file layout materially.

**Date**: 2026-09-27T19:53:04Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-27T19:22:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-27T19:53:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO on the exploration, with a stated leaning: TWO agents, because a single agent that both defines the yardstick (arc-scoped drivers) and applies it (task scores) reproduces producer-not-judge one level up, which is precisely the defect the operator is trying to close. Evidence this is tractable rather than speculative: three of the four parties already exist — the estimator proposes (agents/termlink/bvp-estimator/), the static driver reviewer checks driver quality (lib/arc-driver-review.sh, T-3429), and T-1951 already runs a reviewer as an isolated TermLink worker with results on the fw bus. What is missing is the judging half and the handoff. Not a build task: >3 new files and a new subsystem, so G-020 requires scoping first, and the one-agent-or-two question changes the file layout materially.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1386f9ef
- **Timestamp:** 2026-09-27T19:53:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-9f346a6a
- **Timestamp:** 2026-09-27T19:53:07Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `T-3429` | task | ✓ pass |
| `T-1951` | task | ✓ pass |

### 2026-09-27T19:53:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
