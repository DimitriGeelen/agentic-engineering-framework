---
id: T-5224
name: "Optional arc orchestrator: an arc can have an owner that holds the arc's context
  for its whole life and can be handed over and resumed from the arc's own record
  (possibly by a newer model) — 1409 request"
description: >
  Inception: Optional arc orchestrator: an arc can have an owner that holds the arc's
  context for its whole life and can be handed over and resumed from the arc's own
  record (possibly by a newer model) — 1409 request

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
step_entered_at: '2026-11-18T22:21:49Z'
revisit_at: 2026-11-25
waiting_on: peer
created: 2026-11-18T09:15:42Z
last_update: '2026-11-19T09:30:42Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-18T09:16:04Z'
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
  - ts: '2026-11-18T09:30:25Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=139,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-11-19T09:30:42Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=151,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5224: Optional arc orchestrator: an arc can have an owner that holds the arc's context for its whole life and can be handed over and resumed from the arc's own record (possibly by a newer model) — 1409 request

## Problem Statement

1409 (sidecar c87d0ee1, 2026-11-18), relaying their operator: "Can you work with AEF on this? Because that is something we need to integrate in the framework then for ARCs. That we have got an ARC orchestrator. Optional. Should not be everywhere. We need to really decide how we plug this in into the framework." Also: "when we exit we need to have a way to preload reload and orchestrate it just as much as we preload reload a session for an agent, as we do now with compact and resume. But then with a new model."

The need: an arc can have an owner (an orchestrator) for its whole life, who holds the context of what happened in it. When that owner ends (time limit, long wait, crash, full context), the arc is continued from its own record, the way a session is continued through handover and resume, possibly by a different, newer model. This is optional per arc.

The trigger at 1409: each municipality is one arc with 13 step tasks. On 13 Nov they replaced the per-unit orchestrator with "submit judgments to the pool, end, a deterministic timer continues". Since then, every outcome that needs judgment has no owner. 20 units are parked, and what each unit's search had tried lived only in the ended orchestrator's session.

What AEF has today (2026-11-18):
- The arc record has no owner field and no arc-level log. `fw arc` has create, instantiate (T-5221), start, focus, show, tag, close, review and abandon, but no handover or resume.
- Handover, resume, episodic memory and `fw bus` are scoped to a session or a task.
- Wake paths exist: sidecar notices (T-5211/T-5222), cron, and TermLink dispatch.

Research: docs/reports/T-5224-arc-orchestrator.md.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

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

- **IW-1: Which owner model: A (one orchestrator that stays and is resumed), B (the owner is a role; a fresh agent is woken per event, reads a per-arc handover and writes one back), or C (timer plus a driver, no owner)? Depends on 1409's load test: can a fresh agent continue from the arc's records alone?**
- **IW-2: What is the per-arc record? A journal of what was tried, decided and next, kept beside the arc YAML. Who writes it (the owner at each step, the framework at task status changes), and what makes it enough to resume from?**
- **IW-3: How does it plug in? An optional `orchestrator:` field on the arc, `fw arc handover <id>` / `fw arc resume <id>`, a wake on task status changes inside the arc (sidecar notice, as in T-5211), and which parts stay project-side (1409's timer, pool, judgment rules).**
- **IW-4: Governance for an agent that owns an arc across sessions and models: focus (arc focus vs task focus), the task gate, the budget gate, and review of the owner's decisions.**
- **IW-5: Later runs of the same unit (1409 fb6c390d; their operator decided per-run new step instances in the same arc, built from the template valid at that time). Does `fw arc instantiate` instantiate into an existing arc as a new run (run number, predecessor link, template version recorded), what is carried over (findings yes, assumptions marked, judgements and check results no), and does arc completion become per run?**
- **IW-6: Grain at scale: one task per step is about 142,000 task files for one pass over 10,953 units (1409). Is a per-unit step task the right grain at that size, or do steps become journal entries inside a per-unit task or arc? Evidence: 1409's fw command timings at 10k / 50k / 142k files (pending).**

## Exploration Plan

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** EXPLORING

Earlier filing-time recommendation (before T-5226): DEFER — rationale kept below.
Back to EXPLORING by T-5228 triage (6 IW questions not disposed). Waiting on: peer (1409) — their measurements, especially the five-unit load test.

**Rationale:**

Evidence gap, not a hedge: 1409 is measuring (1) how many units hit judgment outcomes and at which steps, (2) orchestrator token cost per unit and per reload, (3) a load test on five real units of whether a fresh agent can continue from the arc's records alone, (4) options A resumed orchestrator / B owner as a role woken per event with a per-arc handover / C timer plus driver. The recommendation between A, B and C depends on (3).

**Evidence:**

- 1409 timings (msg bb07ad3f, 2026-11-19, throwaway project): `fw work-on` 3-4 s at 2,900 task files, 31-105 s at 10,000, 201-596 s at 50,000, over 600 s at 142,000. Across 78 step tasks they found 0 decisions, 0 ticked criteria and 0 evolution entries; later runs redid 122 already-green steps (7.3 h); a short "taken over from <run>" block scored 18/18 in a reading test with 36 fresh readers. Feeds IW-5/IW-6; the volume half moved to T-5246 (index).
- 1409 operator ruling (msgs bbf3f214, 72b696d8, 2026-11-19), feeds IW-5: a step version IS a task in the unit's arc. A redone step gets a NEW task from the template valid then (version recorded); new tasks only for the resumed step and the steps after it as they come up; an unstarted step is re-rendered in place, same id; the whole sequence is copied only when a check before resuming says earlier results no longer hold. Requirements: (1) re-render an unstarted task from a newer template in place; (2) a new step instance links to its predecessor in the same arc; (3) arc completion copes with several instances of one step.

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-18T09:16:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-18T22:21:49Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: agent → peer
- **Revisit:** 2026-11-25
