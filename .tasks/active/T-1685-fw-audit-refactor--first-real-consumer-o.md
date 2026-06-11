---
id: T-1685
name: "fw audit refactor — first real consumer of the orchestrator, route slow analytical
  checks through fw termlink dispatch"
description: >
  Inception: fw audit refactor — first real consumer of the orchestrator, route slow
  analytical checks through fw termlink dispatch

status: captured
workflow_type: inception
owner: human
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-05-02T18:50:52Z
last_update: '2026-06-11T22:23:24Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
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
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
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
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1685: fw audit refactor — first real consumer of the orchestrator, route slow analytical checks through fw termlink dispatch

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

**Recommendation:** NO-GO

**Rationale:** Phase 1 spike showed `fw audit` is bash/git/IO bound (2m18s wall-clock; sys 2m7s = fork/exec + git ops + file I/O), with ZERO LLM-amenable workload in any check. Refactoring through the orchestrator would inject LLM cost + non-determinism + external dependencies into a deterministic pipeline that costs zero today. The premise — "audit has slow analytical checks that would benefit from typed routing" — does not survive investigation.

**Evidence:**
- Full Phase 1 spike at `docs/reports/T-1685-audit-refactor.md`
- Audit timing: 2m18s wall, 2m7s sys (fork/exec + git ops dominant)
- Section-by-section workload review: every check is regex/grep/structural-count, none synthesis-shaped
- T-1688 sibling survey confirms the same finding across all 18 autonomous workloads

**Implications:** This NO-GO is structural confirmation of G-064 — the framework's existing autonomous workload is not LLM-amenable. Closure of G-064 needs either a NEW autonomous consumer (T-1684 cron health-check, escalation-scan v0.5) or explicit acceptance of opt-in-only orchestrator. T-1685 does not block any closure path; it cleanly rules out audit refactor as a candidate.

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

**Decision**: DEFER

**Rationale**: Recommendation: NO-GO

Rationale: Phase 1 spike showed `fw audit` is bash/git/IO bound (2m18s wall-clock; sys 2m7s = fork/exec + git ops + file I/O), with ZERO LLM-amenable workload in any check. Refactoring through the orchestrator would inject LLM cost + non-determinism + external dependencies into a deterministic pipeline that costs zero today. The premise — "audit has slow analytical checks that would benefit from typed routing" — does not survive investigation.

Evidence:
- Full Phase 1 spike at `docs/reports/T-1685-audit-refactor.md`
- Audit timing: 2m18s wall, 2m7s sys (fork/exec + git ops dominant)
- Section-by-section workload review: every check is regex/grep/structural-count, none synthesis-shaped
- T-1688 sibling survey confirms the same finding across all 18 autonomous workloads

Implications: This NO-GO is structural confirmation of G-064 — the framework's existing autonomous workload is not LLM-amenable. Closure of G-064 needs either a NEW autonomous consumer (T-1684 cron health-check, escalation-scan v0.5) or explicit acceptance of opt-in-only orchestrator. T-1685 does not block any closure path; it cleanly rules out audit refactor as a candidate.

**Date**: 2026-05-03T07:09:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-02T18:55:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-03T07:09:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: NO-GO

Rationale: Phase 1 spike showed `fw audit` is bash/git/IO bound (2m18s wall-clock; sys 2m7s = fork/exec + git ops + file I/O), with ZERO LLM-amenable workload in any check. Refactoring through the orchestrator would inject LLM cost + non-determinism + external dependencies into a deterministic pipeline that costs zero today. The premise — "audit has slow analytical checks that would benefit from typed routing" — does not survive investigation.

Evidence:
- Full Phase 1 spike at `docs/reports/T-1685-audit-refactor.md`
- Audit timing: 2m18s wall, 2m7s sys (fork/exec + git ops dominant)
- Section-by-section workload review: every check is regex/grep/structural-count, none synthesis-shaped
- T-1688 sibling survey confirms the same finding across all 18 autonomous workloads

Implications: This NO-GO is structural confirmation of G-064 — the framework's existing autonomous workload is not LLM-amenable. Closure of G-064 needs either a NEW autonomous consumer (T-1684 cron health-check, escalation-scan v0.5) or explicit acceptance of opt-in-only orchestrator. T-1685 does not block any closure path; it cleanly rules out audit refactor as a candidate.

### 2026-05-15T19:54:39Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: preserved at started-work (T-1589 shipping evidence)
- **Reason:** T-1865 sweep: DEFER limbo recovery

### 2026-05-15T19:55:15Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: later → later
- **Reason:** T-1865 sweep: DEFER limbo recovery
