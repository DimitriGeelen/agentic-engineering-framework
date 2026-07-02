---
id: T-1503
name: "Pickup: Watchtower /inception/decide returns 500 on partial-complete success
  + decision-record happens before AC gate (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-131. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/inception.sh, tests/unit/inception_decide_atomicity.bats]
related_tasks: []
created: 2026-04-26T11:13:29Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T12:07:43Z
source_task_id_in_origin: T-131
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1503: Pickup: Watchtower /inception/decide returns 500 on partial-complete success + decision-record happens before AC gate (from 003-NTB-ATC-Plugin)

## Context

**SCOPE-NARROWED:** P-010 reported two coupled bugs. Per "one bug = one task," T-1503 now covers **Problem 1 only** (decision-record-before-AC-gate ordering). Problem 2 (false 500 on partial-complete success in `web/blueprints/inception.py:411`) split into a separate task.

**Problem 1 — atomicity violation in `do_inception_decide`:**
Current flow (lib/inception.sh:382→454):
1. Write `## Decision` section to task body
2. `tick_inception_decide_acs` (only ticks @auto-tick / pattern-matched ACs, leaves custom Agent ACs alone)
3. Append `### timestamp — inception-decision` Updates entry
4. Call `update-task.sh --status work-completed` → P-010 AC gate

If a task has CUSTOM Agent ACs that aren't auto-tick (e.g. inception body adapted from a build-task pickup, or template extended with bug-specific checks), step 4 blocks. But steps 1-3 already happened. Result: task body has `Decision: GO` but `status: started-work`. Retry compounds Updates entries (Decision is idempotent per T-1262, Updates is not).

Live evidence (003-NTB-ATC-Plugin T-131 watchtower.log):
> stdout=...ERROR: Cannot complete — 5/5 agent AC unchecked... POST /inception/T-131/decide HTTP/1.1 500

**Fix (preflight pattern):** re-order — run `tick_inception_decide_acs` first, then count remaining unchecked Agent ACs. If any remain, abort BEFORE writing Decision/Updates. Either everything succeeds, or the body is untouched.

Mirrors update-task.sh:73-105 AC counting logic; no new behavior, just early validation.

## Acceptance Criteria

### Agent
- [x] `do_inception_decide` invokes `tick_inception_decide_acs` BEFORE writing Decision section / Updates entry
- [x] After ticking, if any Agent AC is still unchecked, abort with clear error citing which ACs (no mutation of task body)
- [x] Bats regression: inception task with one custom unticked Agent AC + go decision → fails fast, task body unchanged (no Decision section, no Updates entry)
- [x] Bats regression: inception task with all-auto-tick or all-checked Agent ACs → full success (Decision written, Updates appended, status work-completed)
- [x] Existing inception tests still pass (T-1262 idempotent Decision writer, T-1324 tick-before-gate semantics, T-1492 emit_review pipefail)

## Verification

bash -n lib/inception.sh
bats tests/unit/inception_decide_atomicity.bats

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

### 2026-04-26T11:13:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1503-pickup-watchtower-inceptiondecide-return.md
- **Context:** Initial task creation

### 2026-04-26T12:05:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d87ad34
- **Timestamp:** 2026-06-02T14:57:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T12:07:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
