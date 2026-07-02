---
id: T-487
name: "Research KCP (Knowledge Context Protocol) — evaluate for T-477 governance declaration
  layer"
description: >
  Thor Henning Hetland (Cantara) pointed to KCP as prior art for the machine-readable
  declaration layer T-477 is designing. Evaluate: (1) Does KCP's manifest format solve
  what T-477 needs? (2) 284 pre-built CLI manifests — useful starting point? (3) Spec
  v0.10 federation/query — relevant for multi-agent? (4) MIT licensed — can we adopt/adapt?
  GitHub: github.com/Cantara/knowledge-context-protocol

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-14T16:13:49Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-14T16:28:33Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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

# T-487: Research KCP (Knowledge Context Protocol) — evaluate for T-477 governance declaration layer

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

- [x] KCP spec (v0.10) analyzed — manifest format, authority model, compliance model documented
- [x] kcp-commands (289 CLI manifests) evaluated — schema, samples, operational phases
- [x] Relevance to T-477 assessed — overlaps, gaps, and borrowable patterns identified
- [x] Research report written to `docs/reports/T-487-kcp-research.md`

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

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

### 2026-03-14T16:15:47Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-14T16:16:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T16:24:14Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-03-14T16:28:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c9e3085
- **Timestamp:** 2026-06-02T15:03:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
