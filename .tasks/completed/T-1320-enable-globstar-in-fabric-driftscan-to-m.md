---
id: T-1320
name: "Enable globstar in fabric drift/scan to match recursive watch-patterns (T-1319
  GO)"
description: >
  Enable globstar in fabric drift/scan to match recursive watch-patterns (T-1319 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-18T22:03:55Z
last_update: '2026-08-16T22:24:29Z'
date_finished: 2026-04-18T22:22:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1320: Enable globstar in fabric drift/scan to match recursive watch-patterns (T-1319 GO)

## Context

Build sibling to T-1319 (GO). Source: termlink T-1130 pickup (P-037). Two-line fix: enable `shopt -s globstar nullglob` in `do_drift` (drift.sh) and `do_scan` (register.sh) so recursive `**` patterns from `.fabric/watch-patterns.yaml` match the same files as `fw audit`'s Python glob does. Research artifact: `docs/reports/T-1319-fabric-globstar-divergence.md`.

## Acceptance Criteria

### Agent
- [x] `agents/fabric/lib/drift.sh:do_drift` enables `shopt -s globstar nullglob 2>/dev/null || true` before its glob loop
- [x] `agents/fabric/lib/register.sh:do_scan` enables `shopt -s globstar nullglob 2>/dev/null || true` before its glob loop
- [x] Bats regression test in `tests/unit/fabric_globstar.bats` covers source invariants, behavior contract for shopt, and integration (fabric scan registers deeply-nested file, fabric drift reports it) — 6 tests
- [x] `bats tests/unit/fabric_globstar.bats` passes (6/6)
- [x] Existing `tests/unit/fabric.bats` still passes (10/10)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

cd "$PROJECT_ROOT" && grep -q 'shopt -s globstar' agents/fabric/lib/drift.sh
cd "$PROJECT_ROOT" && grep -q 'shopt -s globstar' agents/fabric/lib/register.sh
cd "$PROJECT_ROOT" && bats tests/unit/fabric_globstar.bats

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-18T22:03:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1320-enable-globstar-in-fabric-driftscan-to-m.md
- **Context:** Initial task creation

### 2026-04-18T22:22:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3d18d1a3
- **Timestamp:** 2026-06-02T14:56:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `cd "$PROJECT_ROOT" && bats tests/unit/fabric_globstar.bats`
