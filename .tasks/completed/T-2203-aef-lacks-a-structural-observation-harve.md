---
id: T-2203
name: "AEF lacks a structural-observation harvester from dispatched workers back to
  the framework repo"
description: >
  Workers dispatched via fw termlink dispatch can observe framework-level gaps (T-2200:
  corrupted-config diagnostic buried; T-2202: FRAMEWORK_ROOT env-leak), but there
  is no mechanism for those observations to bubble back to /opt/999-Agentic-Engineering-Framework.
  fw pickup primitives exist but are generic message bus, not wired to upstream-framework-tagged
  observations. Inception: harvester contract — workers file local inception, parent
  polls; OR workers fw pickup send; OR dispatch contract changes.

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-04T07:57:58Z
last_update: 2026-06-08T07:44:40Z
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
  - ts: '2026-06-04T08:00:03Z'
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
cost_estimate_proposed:
  - ts: '2026-06-04T08:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2203: AEF lacks a structural-observation harvester from dispatched workers back to the framework repo

## Problem Statement

Workers dispatched via `fw termlink dispatch` operate inside consumer projects (`/opt/fan-dashboard`, `/opt/832-Workflow-designer`, etc.) and can observe framework-level gaps as they work. T-2200's worker hit a corrupted `/root/.claude.json` diagnostic that the dispatch surface should have caught; T-2202's worker hit a `FRAMEWORK_ROOT` env-leak from the parent that the dispatch contract should have scrubbed. Both observations are valuable structural-improvement signal, but **there is no mechanism for them to bubble back to `/opt/999-Agentic-Engineering-Framework`**.

In this session, the bubble-up happened only because the parent (this agent) was alive, attentive, and tailing the workers' `result.jsonl`. Once the parent session ends, anything a worker observes in `/opt/<consumer>/.tasks/active/*upstream-framework*` will sit there indefinitely — no harvester polls it, no cron picks it up, no human will see it unless they happen to walk into that consumer's repo.

**For whom:** every framework maintainer (today: the operator + this agent class) who wants worker-side framework-blindness observations to feed the inception backlog.

**Why now:** two worker-side observations landed in one session (T-2200 + T-2202). The pattern is repeating. The `fw pickup` primitives exist but aren't wired to "upstream-framework" semantics; my worker prompt (T-2200's brief) ASKED workers to file local inceptions tagged `upstream-framework`, which is structurally hollow — nothing harvests them.

## Assumptions

- A1: `fw pickup send|process|list` covers the cross-project transport layer (text payload, recipient project, deliverable artefact). What's missing is the *what-to-send* contract for structural observations, not the transport. Verify: `bin/fw pickup --help` and read `lib/pickup.sh`.
- A2: Workers can `cd` and run fw commands inside the framework repo via `--remote` SSH dispatch from the consumer's TermLink session. If true, the worker can directly file an inception in the framework repo without a separate harvester step. Verify: try `fw dispatch send --host localhost --task T-XXX ...` from a worker context.
- A3: The volume of structural observations from workers will be low (~0-5 per worker run, only when framework gaps surface). A polled harvester would be overkill; event-driven bus or direct fw-pickup is sufficient. Test: observe T-2200 + T-2202 workers' final reports; count `upstream-framework`-class observations.

## Open Questions

- **IW-1: Which side files the inception — worker files local + parent harvests, OR worker directly sends via `fw pickup` (or `fw dispatch send`) to the framework repo?**
  confidence: 1
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-2: If "worker files local + parent harvests", what's the harvester trigger — cron, `fw pickup process` manual, dispatch-end event, OR `fw doctor` advisory?**
  confidence: 0
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-3: What's the structural-observation envelope — frontmatter tag (`upstream-framework`), prefix on inception name (`UPSTREAM:`), separate file class (`.context/observations/`), OR existing `fw note` observation primitive?**
  confidence: 2
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-4: Should the dispatch contract REQUIRE workers to write a `## Framework Observations` section in their final-report blob (even if empty), making the absence-of-signal explicit and the presence-of-signal greppable?**
  confidence: 2
  disposition: <decide-time>
  rationale: <decide-time>

<!-- T-2190: every IW-N question must be disposed before --status work-completed. -->
-->

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

**Recommendation:** DEFER

**Rationale:** Genuine evidence gap, not a confidence gap (T-2144 author-time discipline). Four open questions (IW-1..IW-4) are untested — no spike has been run to confirm (a) whether workers can directly call `fw pickup send` from inside a consumer-side TermLink session back to the framework repo, (b) what cadence harvester is appropriate, (c) what envelope shape is greppable enough to be a structural signal, (d) whether the dispatch contract should mandate a `## Framework Observations` section in the final-report blob. The observable problem is real (T-2200 and T-2202 workers both produced structural-improvement signal that would sit unread without an active parent), but the fix surface (where the harvester lives + which side files) is unconstrained. DEFER until at least one of: (i) `fw pickup send` transport spike from inside a worker context succeeds and gives IW-1 a bias, (ii) a third worker-dispatch session produces a structural observation, raising signal volume above the "low frequency, parent-attentive" assumption (A3). Re-surface trigger: third worker incident OR completion of IW-1 transport spike.

**revisit_at:** 2026-06-18 (two weeks; matches the rough cadence of upstream-framework-observation worker incidents this session — 2 in 30 minutes; even a conservative re-rate of 1/week implies a third incident by then).

**revisit_evidence_needed:** EITHER (a) third worker-dispatch session producing an upstream-framework observation, OR (b) a 30-minute spike confirming `fw pickup send` works from inside a consumer-side TermLink session, OR (c) operator pushes a different harvester contract proposal.

**Evidence:**
- T-2200 worker (fan-dashboard) produced FRAMEWORK_ROOT env-leak observation — would sit unread without active parent.
- T-2202 worker (workflow-designer) produced same — second incident, same session.
- Worker brief in T-2200 asked workers to file local upstream-framework-tagged inceptions, but no harvester reads those (structurally hollow contract).
- `fw pickup` transport layer exists (`lib/pickup.sh`) but is not wired to upstream-framework semantics.
- No spike done on whether workers can `fw dispatch send` back to the framework repo from inside their TermLink session.
- All 4 IW-N questions filed at confidence 0-2 — disposition pending data.

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

**Rationale**: Genuine evidence gap, not a confidence gap (T-2144 author-time discipline). Four open questions (IW-1..IW-4) are untested — no spike has been run to confirm (a) whether workers can directly call `fw pickup send` from inside a consumer-side TermLink session back to the framework repo, (b) what cadence harvester is appropriate, (c) what envelope shape is greppable enough to be a structural signal, (d) whether the dispatch contract should mandate a `## Framework Observations` section in the final-report blob. The observable problem is real (T-2200 and T-2202 workers both produced structural-improvement signal that would sit unread without an active parent), but the fix surface (where the harvester lives + which side files) is unconstrained. DEFER until at least one of: (i) `fw pickup send` transport spike from inside a worker context succeeds and gives IW-1 a bias, (ii) a third worker-dispatch session produces a structural observation, raising signal volume above the "low frequency, parent-attentive" assumption (A3). Re-surface trigger: third worker incident OR completion of IW-1 transport spike.

**Date**: 2026-06-04T19:47:41Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-04T19:47:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Genuine evidence gap, not a confidence gap (T-2144 author-time discipline). Four open questions (IW-1..IW-4) are untested — no spike has been run to confirm (a) whether workers can directly call `fw pickup send` from inside a consumer-side TermLink session back to the framework repo, (b) what cadence harvester is appropriate, (c) what envelope shape is greppable enough to be a structural signal, (d) whether the dispatch contract should mandate a `## Framework Observations` section in the final-report blob. The observable problem is real (T-2200 and T-2202 workers both produced structural-improvement signal that would sit unread without an active parent), but the fix surface (where the harvester lives + which side files) is unconstrained. DEFER until at least one of: (i) `fw pickup send` transport spike from inside a worker context succeeds and gives IW-1 a bias, (ii) a third worker-dispatch session produces a structural observation, raising signal volume above the "low frequency, parent-attentive" assumption (A3). Re-surface trigger: third worker incident OR completion of IW-1 transport spike.
