---
id: T-1312
name: "Pickup: Ship watchtower.service systemd template — fixes restart races without
  WSGI-server swap (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1122. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-18T20:23:09Z
last_update: '2026-08-16T22:24:28Z'
date_finished: 2026-04-22T05:21:15Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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
  - ts: '2026-08-16T22:24:28Z'
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

# T-1312: Pickup: Ship watchtower.service systemd template — fixes restart races without WSGI-server swap (from termlink)

## Problem Statement

Termlink T-1122 proposes shipping a `watchtower.service` systemd template that fixes Watchtower restart races without swapping the WSGI server. **Already captured locally as T-1309** — `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md` exists with the same proposal. This pickup is a duplicate.

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
- [x] Problem statement validated (duplicate of T-1309)
- [x] Assumptions tested (artifact exists at docs/reports/T-1309-...)
- [x] Recommendation written with rationale (DEFER as duplicate)

### Human
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

## Recommendation

**Recommendation:** DEFER (duplicate)

**Rationale:** This pickup proposes the same change already captured locally as T-1309. Closing this duplicate keeps the inception queue lean. The actual design + decision lives at T-1309 / `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md`.

**Evidence:**
- T-1309 exists in `.tasks/active/`
- Proposal artifact `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md` already on disk
- Same source task referenced (termlink T-1122)

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

**Rationale**: Recommendation: DEFER (duplicate)

Rationale: This pickup proposes the same change already captured locally as T-1309. Closing this duplicate keeps the inception queue lean. The actual design + decision lives at T-1309 / `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md`.

Evidence:
- T-1309 exists in `.tasks/active/`
- Proposal artifact `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md` already on disk
- Same source task referenced (termlink T-1122)

**Date**: 2026-04-18T22:48:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T21:04:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:48:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (duplicate)

Rationale: This pickup proposes the same change already captured locally as T-1309. Closing this duplicate keeps the inception queue lean. The actual design + decision lives at T-1309 / `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md`.

Evidence:
- T-1309 exists in `.tasks/active/`
- Proposal artifact `docs/reports/T-1309-watchtower-systemd-from-termlink-T-1122.md` already on disk
- Same source task referenced (termlink T-1122)

### 2026-04-22T05:21:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bf4d3600
- **Timestamp:** 2026-06-02T14:56:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
