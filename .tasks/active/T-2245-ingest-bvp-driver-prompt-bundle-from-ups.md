---
id: T-2245
name: "ingest BVP driver prompt bundle from upstream pickup (2026-06-06)"
description: >
  Captured upstream pickup INGESTION-bvp-driver-prompt-bundle-2026-06-06. Document
  filed at docs/reports/ per §7 step 2 (reversible). CLI verb build work is inception
  territory per the doc itself §3 + §8 + G-020 — needs operator direction.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-07T21:57:06Z
last_update: 2026-06-07T22:04:00Z
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
  confidence: 1
  disposition: deferred
  rationale: Operator pivoted directive mid-session to "focus on bvp driver prompt bundle" but did not paste the bundle file contents. Authoring from §6 specs is feasible (~1490 LoC, the design dialogue gives enough material) but the upstream session may have authored canonical versions worth preserving. Hold for explicit operator direction.

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

**Recommendation:** DEFER

**Rationale:** Per the pickup document's own §7 step 5: 'Do not auto-build the v2 handoff or the inception. That requires human direction.' + §8 pickup safety: 'do not file build tasks for the new verbs without the v2 handoff revision and the inception decide-go transition.' Document filing itself is §3-reversible and is being done in this turn. CLI verb build work (4 new verbs: fw bvp driver suggest|create, fw bvp recompute, fw bvp init; 7+ new files under policy/prompts/; new audit log .context/bvp-recompute-log.jsonl) is G-020 inception territory. Bundle file CONTENTS not in the pickup message — only the ingestion document body. Waiting on operator direction to: (a) provide the bundle file contents, (b) revise HANDOFF-value-prioritisation-2026-05-15 to v2, (c) file the value-prioritisation inception with decide-go transition.

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

### 2026-06-07T22:04:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
