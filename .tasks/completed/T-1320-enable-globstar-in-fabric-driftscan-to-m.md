---
id: T-1320
name: "Enable globstar in fabric drift/scan to match recursive watch-patterns (T-1319 GO)"
description: >
  Enable globstar in fabric drift/scan to match recursive watch-patterns (T-1319 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T22:03:55Z
last_update: 2026-04-18T22:22:03Z
date_finished: 2026-04-18T22:22:03Z
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
