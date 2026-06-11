---
id: T-1434
name: "add vendored-drift check to fw doctor (prevent T-1432/T-1433 class)"
description: >
  add vendored-drift check to fw doctor (prevent T-1432/T-1433 class)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:51:33Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T15:59:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1434: add vendored-drift check to fw doctor (prevent T-1432/T-1433 class)

## Context

T-1432 and T-1433 fixed drift between framework source (`lib/*.sh`, `agents/context/*.sh`) and vendored copies (`.agentic-framework/lib/*.sh`, etc.). L-257 captured the principle: when editing source, sync the vendor. But it's a discipline rule — Level B. The systemic fix is Level C: a `fw doctor` check that fails when drift exists.

**Scope:** in the framework repo only (PROJECT_ROOT == FRAMEWORK_ROOT). Consumer projects don't have both copies — their `.agentic-framework/` IS the framework. Skip the check elsewhere.

**Watched paths:** `lib/*.sh`, `agents/context/*.sh`, `agents/task-create/*.sh` — these are all the script trees that have vendored copies today (sweep confirmed no others).

**Output:**
- OK: "No vendored-source drift"
- WARN: "Vendored drift: N file(s) — run fw vendor to sync" + list

Must not read-only-detect. `fw vendor` already exists to sync; the doctor check just surfaces the delta so it's visible.

## Acceptance Criteria

### Agent
- [x] `fw doctor` output includes a "Vendored-source drift" line after framework-installation checks
- [x] Check is skipped outside the framework repo (PROJECT_ROOT != FRAMEWORK_ROOT)
- [x] Drift detection uses the sweep pattern from T-1433: iterate `bin/fw`, `lib/*.sh`, `agents/context/*.sh`, `agents/task-create/*.sh`; diff each with its `.agentic-framework/` counterpart
- [x] When no drift: OK message, zero warnings added
- [x] When drift exists: WARN message names first 5 drifted files, increments warnings counter
- [x] A bats test creates synthetic drift and asserts the doctor output contains "Vendored-source drift" WARN line (3 tests in `tests/unit/fw_doctor_vendored_drift.bats`)

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

bats tests/unit/fw_doctor_vendored_drift.bats
DOC_OUT=$(bin/fw doctor 2>&1); echo "$DOC_OUT" | grep -qE "(No vendored-source drift|Vendored-source drift)"
# When no drift: must be clean
DOC_OUT=$(bin/fw doctor 2>&1); echo "$DOC_OUT" | grep -q "No vendored-source drift"

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

### 2026-04-24T15:51:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1434-add-vendored-drift-check-to-fw-doctor-pr.md
- **Context:** Initial task creation

### 2026-04-24T15:59:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9de58975
- **Timestamp:** 2026-06-02T14:57:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
