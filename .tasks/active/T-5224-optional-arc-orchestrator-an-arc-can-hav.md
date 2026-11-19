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
step_entered_at: '2026-11-19T13:31:14Z'
revisit_at: 2026-11-26
waiting_on: operator
created: 2026-11-18T09:15:42Z
last_update: 2026-11-19T13:31:14Z
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
  confidence: 3
  disposition: answered
  rationale: B. 1409's fresh-agent load test (210 agents): 7/10 right next step on the records as they were, 10/10 with decision lines at the unit; every wrong action came from a decision not written into the arc. Resume costs ~16-18K tokens. Operator ruling 2026-11-19: "1" (B). docs/reports/T-5224-arc-orchestrator.md §Dialogue Log.
- **IW-2: What is the per-arc record? A journal of what was tried, decided and next, kept beside the arc YAML. Who writes it (the owner at each step, the framework at task status changes), and what makes it enough to resume from?**
  confidence: 2
  disposition: answered
  rationale: Append-only journal per arc beside its YAML. Entries: tried (and result), decided (with reason), next (step, owner, deadline), outside decisions. Writers: the framework automatically on task start/close/issues inside the arc; the on-duty agent and any outside decider through one command. A resumability check flags no next step, a next step older than the latest event, or a red check with no decision; the woken agent runs it first. Basis: 1409 load tests (wrong actions all from unrecorded outside decisions; stale next worse than none). Operator ruling 2026-11-19: "1".
- **IW-3: How does it plug in? An optional `orchestrator:` field on the arc, `fw arc handover <id>` / `fw arc resume <id>`, a wake on task status changes inside the arc (sidecar notice, as in T-5211), and which parts stay project-side (1409's timer, pool, judgment rules).**
  confidence: 2
  disposition: answered
  rationale: Opt-in per arc (one setting in the arc YAML naming the owner role and how it is woken; arcs without it unchanged). Verbs: `fw arc journal <arc> tried|decided|next` and `fw arc resume <arc>` (resumability check plus a brief: latest decisions, next step with owner and deadline, open tasks); no separate handover verb, because the journal is written as things happen. Wake on task status changes inside the arc and on a passed "next" deadline, by idle-aware sidecar notice (T-5211/T-5222) or a fresh TermLink worker, chosen per arc. Project-side: timer, work pool, judgement rules, model per step, when a unit is due. Operator ruling 2026-11-19: "1".
- **IW-4: Governance for an agent that owns an arc across sessions and models: focus (arc focus vs task focus), the task gate, the budget gate, and review of the owner's decisions.**
  confidence: 2
  disposition: answered
  rationale: The owner role is initiative, not authority: arc close, inception decide, Tier 0 and Human criteria stay the operator's. `fw arc resume` sets arc context and focuses the next step's task; every change still needs an active task (journal writes allowed like other framework memory). Each wake is a fresh agent with its own budget (brief ~16-18K); a per-arc wake limit (e.g. per day) stops a self-waking loop and tells the operator, like T-3253's continuous-run limits. Routine decisions (template's next step) are journalled without review; consequential ones (skip a step, accept a failed check, defer, change scope) are marked and need operator approval or a green independent-reviewer verdict, per project; the resumability check flags one with neither. Operator ruling 2026-11-19: "1".
- **IW-5: Later runs of the same unit (1409 fb6c390d; their operator decided per-run new step instances in the same arc, built from the template valid at that time). Does `fw arc instantiate` instantiate into an existing arc as a new run (run number, predecessor link, template version recorded), what is carried over (findings yes, assumptions marked, judgements and check results no), and does arc completion become per run?**
  confidence: 2
  disposition: answered
  rationale: Adopt 1409's operator rules (msgs fb6c390d, da96da3b, 72b696d8, d9c814d1): versions per STEP, not per run. A never-started step task is re-rendered in place from the newer template, same id (needs T-5247 date_started). A started step that is redone gets a NEW task from the template valid then, template version recorded, linked both ways (supersedes / superseded_by); new tasks only for the resumed step and later steps as they come up; the whole sequence is copied only when a check says earlier results no longer hold. Carry over findings and information, assumptions marked as assumptions; never judgements or check results. A template change names the steps it affects; "results no longer hold" marks those step instances outdated across arcs, and a gate refuses downstream acceptance over an outdated step. Arc complete = every step's latest instance finished and not outdated. Each new instance is also a journal entry (IW-2). AEF needs `fw arc instantiate` into an existing arc from a given step. Operator ruling 2026-11-19: "1".
- **IW-6: Grain at scale: one task per step is about 142,000 task files for one pass over 10,953 units (1409). Is a per-unit step task the right grain at that size, or do steps become journal entries inside a per-unit task or arc? Evidence: 1409's fw command timings at 10k / 50k / 142k files (pending).**
  confidence: 2
  disposition: answered
  rationale: The grain stays one task per step: 1409's operator ruled a step version IS a task in the unit's arc ("one system of governance"; msg bbf3f214), IW-5 builds on it, and governance, review and the close gate all work per task. Volume (~142,000 files plus redone steps, msg 72b696d8; work-on 31-105 s at 10,000, over 600 s at 142,000, msg bb07ad3f) is carried by the derived task index T-5246, measured with 1409's generator; if T-5246 misses its targets this question returns with numbers. Plus a slim template for generated step tasks (13 step files = 378 KB per unit, of which 5 KB run notes). Operator ruling 2026-11-19: "1".

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

**Recommendation:** GO

**Scope agreed with the operator, question by question (2026-11-19, docs/reports/T-5224-arc-orchestrator.md §Dialogue Log):**
1. Owner model B: the owner is a role; a fresh agent per event reads and writes the arc's journal (IW-1).
2. An append-only journal per arc (tried, decided with reason, next with owner and deadline, outside decisions), written by the framework on task status changes and by any actor through one command, with a resumability check every woken agent runs first (IW-2).
3. Opt-in per arc; `fw arc journal` and `fw arc resume`; wake on task status changes and passed deadlines, by idle-aware sidecar notice or a fresh TermLink worker; timer, pool, judgement rules and model choice stay project-side (IW-3).
4. No extra authority for the owner; work under a task; a per-arc wake limit as the brake; consequential decisions need operator approval or a green reviewer verdict (IW-4).
5. Per-step instances inside the arc: re-render in place if never started (needs T-5247), new linked task if redone, carry-over rule, outdated mark across arcs with a downstream gate, arc complete when every step's latest instance is done (IW-5).
6. One task per step stays the grain; the task index T-5246 carries the volume; a slim template for generated step tasks (IW-6).

Suggested build order: journal + resume check (2) → opt-in setting and verbs (3) → wake and wake limit (3, 4) → consequential-decision review (4) → step instances (5, after T-5247) → slim step template (6). The index is T-5246's own track.

**Rationale (evidence):** 1409 measured that 43% of their units (56 of 129) stood at a judgement step nobody started, because what had been tried lived only in ended orchestrator sessions. Their fresh-agent load test (210 agents) showed a fresh agent continues correctly from the arc's record alone once every decision, including outside ones, is written at the unit: 7/10 right next step before, 10/10 after, three models agreeing. A resume costs about 16-18K tokens.

Earlier recommendations, kept for the record: DEFER (filing, pending 1409's measurements), then EXPLORING (T-5228 triage, 6 questions open). Earlier rationale:

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

### 2026-11-19T13:31:14Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: peer → operator
- **Revisit:** 2026-11-26
