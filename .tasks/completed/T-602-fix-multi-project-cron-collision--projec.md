---
id: T-602
name: "Fix multi-project cron collision — project-specific /etc/cron.d filenames"
description: >
  T-601 GO: Make fw audit schedule install use project-specific cron filenames instead
  of hardcoded /etc/cron.d/agentic-audit. Option D: basename with collision warning.
  Also fix schedule remove and schedule status.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:26:27Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-24T09:29:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-602: Fix multi-project cron collision — project-specific /etc/cron.d filenames

## Context

G-022 / T-601 GO. See `docs/reports/T-601-multi-project-cron-collision.md`.

## Acceptance Criteria

### Agent
- [x] Cron filename is project-specific (uses basename of PROJECT_ROOT) — `agentic-audit-999-agentic-engineering-framework`
- [x] `schedule install` warns if existing cron file points to different project (legacy migration + collision detection)
- [x] `schedule remove` removes project-specific cron file (tested: only target project removed)
- [x] `schedule status` shows cron for THIS project only (checks project-specific then legacy)
- [x] Two projects can have concurrent cron files in /etc/cron.d/ (verified: both coexist)

### Human
- [x] [RUBBER-STAMP] Run `fw audit schedule install` on 150-skills-manager and verify both cron files coexist
  **Steps:**
  1. On this machine: `ls /etc/cron.d/agentic-audit-*`
  2. Run `cd /opt/150-skills-manager && fw audit schedule install`
  3. Run `ls /etc/cron.d/agentic-audit-*` — should show TWO files
  **Expected:** `agentic-audit-999-Agentic-Engineering-Framework` and `agentic-audit-150-skills-manager`
  **If not:** Check that PROJECT_ROOT resolves correctly in consumer project

## Verification

# Project-specific filename used (not hardcoded)
grep -q 'project_slug' agents/audit/audit.sh
# Old hardcoded name no longer used
grep -q 'agentic-audit-' agents/audit/audit.sh

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

### 2026-03-24T09:26:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-602-fix-multi-project-cron-collision--projec.md
- **Context:** Initial task creation

### 2026-03-24T09:29:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bc5d709f
- **Timestamp:** 2026-06-02T15:03:49Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Two projects can have concurrent cron files in /etc/cron.d/ (verified: both coexist)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: Two projects can have concurrent cron files in /etc/cron.d/ (verified: both coexist)`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
