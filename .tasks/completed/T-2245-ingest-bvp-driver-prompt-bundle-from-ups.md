---
id: T-2245
name: "ingest BVP driver prompt bundle from upstream pickup (2026-06-06)"
description: >
  Captured upstream pickup INGESTION-bvp-driver-prompt-bundle-2026-06-06. Document
  filed at docs/reports/ per §7 step 2 (reversible). CLI verb build work is inception
  territory per the doc itself §3 + §8 + G-020 — needs operator direction.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-06-07T21:57:06Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-08T05:27:56Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-07T22:00:03Z'
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
  - ts: '2026-06-11T22:24:12Z'
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
  - ts: '2026-06-07T22:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2245: ingest BVP driver prompt bundle from upstream pickup (2026-06-06)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Should the bundle file contents (`policy/prompts/README.md`, `bvp-driver-session.md`, 6× references) be authored by this agent from the §6 design specs, OR held until operator pastes the actual file contents from the upstream session?**
  confidence: 4
  disposition: answered
  resolved_at: 2026-06-08
  resolution: Path B — agent authors bundle from §6 design specs. Operator answered "b" 2026-06-08 in direct response to surfaced A/B/C options.
  rationale: Operator selected Path B after surfaced trade-offs (Path A clean but operator never pasted bundle contents; Path B derives ~1490 LoC of bundle text from §6 dialogue+decisions; Path C holds). Execution moves to sibling build task; T-2245 itself awaits Sovereign Watchtower decide-go (CLAUDECODE blocks `fw inception decide`).

- **IW-2: Should HANDOFF-value-prioritisation-2026-05-15 v2 revision (per §5) be drafted by this framework agent, OR returned to the original researcher (Claude + Dimitri jointly) for revision?**
  confidence: 2
  disposition: deferred
  rationale: §5 lists five concrete additions (T-NEW-16..T-NEW-20). Framework agent can draft mechanically but the original researcher has the design context. Per CLAUDE.md Authority Model — this is a strategic call belonging to the operator, not initiative.

- **IW-3: Should the CLI verb build inception (per §3 — `fw bvp driver suggest|create|recompute|init`) be filed now as captured-and-held, OR wait until the v2 handoff lands?**
  confidence: 2
  disposition: deferred
  rationale: §7 step 5 explicit: "Do not auto-build the v2 handoff or the inception. That requires human direction." Filing the build inception now would skip the v2 handoff step the doc itself flags as a prerequisite.

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

**Recommendation:** GO — Path B (agent-authored bundle from §6)

**Rationale:** Operator answered "b" 2026-06-08 in direct response to surfaced A/B/C options for IW-1, authorizing agent to author bundle contents from §6 design specs (~1490 LoC across 8 files). This consummates §7 step 2 of the pickup ("file the bundle into `policy/prompts/`... reversible"). The §6 dialogue + decisions ledger + rejected paths give enough material to derive coherent prose; canonical upstream-session bundle was never pasted. Bundle is documentation/prompt material; no executable code; reversible. Authoring proceeds under a sibling build task (G-020 threshold satisfied — operator is the explicit authority). T-2245 itself partial-completes once authoring lands; Sovereign Watchtower decide-go formalizes the inception (CLAUDECODE blocks agent-side decide).

**Out of scope (still operator-only per pickup §7 step 5 + §8):**
- HANDOFF-value-prioritisation-2026-05-15 v2 revision (IW-2 still deferred)
- CLI verb build inception (`fw bvp driver suggest|create|recompute|init`) — IW-3 still deferred
- New audit log `.context/bvp-recompute-log.jsonl` (CLI scope)

**Evidence:**
- Operator pivot to "focus on bvp driver prompt bundl" repeated twice in this session
- Operator explicit "b" reply 2026-06-08 to surfaced Path A/B/C question
- Pickup doc §7 step 2: "file the bundle into `policy/prompts/`... reversible"
- Pickup doc §1: 8 files listed, ~1490 LoC total

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

**Rationale**: Operator answered "b" 2026-06-08 in direct response to surfaced A/B/C options for IW-1, authorizing agent to author bundle contents from §6 design specs (~1490 LoC across 8 files). This consummates §7 step 2 of the pickup ("file the bundle into `policy/prompts/`... reversible"). The §6 dialogue + decisions ledger + rejected paths give enough material to derive coherent prose; canonical upstream-session bundle was never pasted. Bundle is documentation/prompt material; no executable code; reversible. Authoring proceeds under a sibling build task (G-020 threshold satisfied — operator is the explicit authority). T-2245 itself partial-completes once authoring lands; Sovereign Watchtower decide-go formalizes the inception (CLAUDECODE blocks agent-side decide).

**Date**: 2026-06-08T05:27:56Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-07T22:04:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-06-08T05:27:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator answered "b" 2026-06-08 in direct response to surfaced A/B/C options for IW-1, authorizing agent to author bundle contents from §6 design specs (~1490 LoC across 8 files). This consummates §7 step 2 of the pickup ("file the bundle into `policy/prompts/`... reversible"). The §6 dialogue + decisions ledger + rejected paths give enough material to derive coherent prose; canonical upstream-session bundle was never pasted. Bundle is documentation/prompt material; no executable code; reversible. Authoring proceeds under a sibling build task (G-020 threshold satisfied — operator is the explicit authority). T-2245 itself partial-completes once authoring lands; Sovereign Watchtower decide-go formalizes the inception (CLAUDECODE blocks agent-side decide).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d9fc539
- **Timestamp:** 2026-06-08T05:27:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T05:27:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
