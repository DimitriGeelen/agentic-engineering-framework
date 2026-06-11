---
id: T-1686
name: "Watchtower /workflows management page — configurable workflow_type→(model,thinking_level,cost-cap)
  + per-workflow telemetry"
description: >
  Inception: Watchtower /workflows management page — configurable workflow_type→(model,thinking_level,cost-cap)
  + per-workflow telemetry

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-05-02T18:54:36Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-03T07:09:54Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
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
---

# T-1686: Watchtower /workflows management page — configurable workflow_type→(model,thinking_level,cost-cap) + per-workflow telemetry

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

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

**Recommendation:** GO — but with explicit honesty about what this does and does not solve.

**Rationale:** Real product feature. Real user request. Reversible. Modest scope (~880 LOC across 6 new + 2 modified files; 1.5–2 sessions). Two-phase split lets Phase 2a (schema + resolver + tests) ship independently of Phase 2b (page + telemetry). Makes the existing orchestrator substrate meaningfully more useful by giving it a configurable surface that today doesn't exist (today it can only learn what it observes; post-T-1686 an operator can pin "inception always uses opus" and observe per-workflow cost).

**Caveat (load-bearing):** Does NOT autonomously close G-064. T-1686 makes the substrate a configurable product; it does not make anything use the product autonomously. G-064 closure still requires either (a) a production caller emerging naturally (someone configures and `fw inception start` is wired to dispatch), OR (b) explicit acceptance that the orchestrator is opt-in only.

**Note (post-T-1687 Q2 collapse):** The original scope `(model, thinking_level, cost_cap)` table needs to expand post-CONTEXT.md collapse — the Agent IS the orchestrator, so the management page configures the *Delegation Envelope* schema (worker_kind, model, prompt template, context_pack composition, cwd), not just routing knobs. Phase 2a should reflect this broader scope.

**Evidence:**
- Full Phase 1 spike at `docs/reports/T-1686-workflow-management-page.md`
- Resolver-wiring approach: workflows.yaml consulted before route_cache (deterministic override beats learned defaults)
- LOC estimate based on existing `/orchestrator` blueprint (T-1647) as reference shape
- Two-phase split mirrors T-1647's incremental delivery (route_cache resolver shipped before the page)
- T-1688 sibling survey confirms management page is most concrete in-progress orchestrator-arc work after retrofit ruled out

**On dependencies:** GO on Phase 2a should not be blocked by T-1688 decision. Phase 2a is independently valuable regardless of which G-064 closure path the human picks.

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

**Rationale**: Recommendation: GO — but with explicit honesty about what this does and does not solve.

Rationale: Real product feature. Real user request. Reversible. Modest scope (~880 LOC across 6 new + 2 modified files; 1.5–2 sessions). Two-phase split lets Phase 2a (schema + resolver + tests) ship independently of Phase 2b (page + telemetry). Makes the existing orchestrator substrate meaningfully more useful by giving it a configurable surface that today doesn't exist (today it can only learn what it observes; post-T-1686 an operator can pin "inception always uses opus" and observe per-workflow cost).

Caveat (load-bearing): Does NOT autonomously close G-064. T-1686 makes the substrate a configurable product; it does not make anything use the product autonomously. G-064 closure still requires either (a) a production caller emerging naturally (someone configures and `fw inception start` is wired to dispatch), OR (b) explicit acceptance that the orchestrator is opt-in only.

Note (post-T-1687 Q2 collapse): The original scope `(model, thinking_level, cost_cap)` table needs to expand post-CONTEXT.md collapse — the Agent IS the orchestrator, so the management page configures the Delegation Envelope schema (worker_kind, model, prompt template, context_pack composition, cwd), not just routing knobs. Phase 2a should reflect this broader scope.

Evidence:
- Full Phase 1 spike at `docs/reports/T-1686-workflow-management-page.md`
- Resolver-wiring approach: workflows.yaml consulted before route_cache (deterministic override beats learned defaults)
- LOC estimate based on existing `/orchestrator` blueprint (T-1647) as reference shape
- Two-phase split mirrors T-1647's incremental delivery (route_cache resolver shipped before the page)
- T-1688 sibling survey confirms management page is most concrete in-progress orchestrator-arc work after retrofit ruled out

On dependencies: GO on Phase 2a should not be blocked by T-1688 decision. Phase 2a is independently valuable regardless of which G-064 closure path the human picks.

**Date**: 2026-05-03T07:09:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-02T18:55:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-03T07:09:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — but with explicit honesty about what this does and does not solve.

Rationale: Real product feature. Real user request. Reversible. Modest scope (~880 LOC across 6 new + 2 modified files; 1.5–2 sessions). Two-phase split lets Phase 2a (schema + resolver + tests) ship independently of Phase 2b (page + telemetry). Makes the existing orchestrator substrate meaningfully more useful by giving it a configurable surface that today doesn't exist (today it can only learn what it observes; post-T-1686 an operator can pin "inception always uses opus" and observe per-workflow cost).

Caveat (load-bearing): Does NOT autonomously close G-064. T-1686 makes the substrate a configurable product; it does not make anything use the product autonomously. G-064 closure still requires either (a) a production caller emerging naturally (someone configures and `fw inception start` is wired to dispatch), OR (b) explicit acceptance that the orchestrator is opt-in only.

Note (post-T-1687 Q2 collapse): The original scope `(model, thinking_level, cost_cap)` table needs to expand post-CONTEXT.md collapse — the Agent IS the orchestrator, so the management page configures the Delegation Envelope schema (worker_kind, model, prompt template, context_pack composition, cwd), not just routing knobs. Phase 2a should reflect this broader scope.

Evidence:
- Full Phase 1 spike at `docs/reports/T-1686-workflow-management-page.md`
- Resolver-wiring approach: workflows.yaml consulted before route_cache (deterministic override beats learned defaults)
- LOC estimate based on existing `/orchestrator` blueprint (T-1647) as reference shape
- Two-phase split mirrors T-1647's incremental delivery (route_cache resolver shipped before the page)
- T-1688 sibling survey confirms management page is most concrete in-progress orchestrator-arc work after retrofit ruled out

On dependencies: GO on Phase 2a should not be blocked by T-1688 decision. Phase 2a is independently valuable regardless of which G-064 closure path the human picks.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f8c299d7
- **Timestamp:** 2026-06-02T14:59:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T07:09:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
