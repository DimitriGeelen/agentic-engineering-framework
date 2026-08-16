---
id: T-067
name: Plugin onboarding audit — task-awareness check for new plugins
description: >
  When new Claude Code plugins are enabled, there is no process to check whether they
  are task-aware or whether their workflows conflict with the framework's core principle.
  Create a plugin onboarding checklist/script that: (1) scans new plugin skill files
  for task-system references, (2) flags TASK-SILENT and TASK-BYPASSING skills, (3)
  recommends integration wrappers or CLAUDE.md amendments, (4) optionally auto-generates
  a compatibility report. Predecessor: T-061 investigation. Should run whenever a
  plugin is added to settings.json.
status: work-completed
workflow_type: specification
owner: human
created: 2026-02-15T08:35:49Z
last_update: '2026-08-16T22:24:18Z'
date_finished: 2026-02-15T09:13:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-067: Plugin onboarding audit — task-awareness check for new plugins

## Context

- Predecessor: T-061 (task-first bypass investigation)
- Design: docs/plans/2026-02-15-plugin-audit-design.md

## Updates

### 2026-02-15T08:35:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-067-plugin-onboarding-audit--task-awareness-.md
- **Context:** Initial task creation

### 2026-02-15T09:03:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-15T09:10:00Z — implementation [claude-code]
- **Action:** Built plugin task-awareness audit tool (Approach C: doctor check + standalone audit)
- **Output:**
  - Created `agents/audit/plugin-audit.sh` — scans enabled plugins for TASK-AWARE/SILENT/BYPASSING skills
  - Added `fw plugin-audit` route to `bin/fw`
  - Added Check 7 (plugin task-awareness) to `fw doctor`
  - Design doc at `docs/plans/2026-02-15-plugin-audit-design.md`
- **Verification:**
  - `fw plugin-audit` correctly identifies 9 AWARE, 17 SILENT, 2 BYPASSING across 10 enabled plugins
  - `fw doctor` shows WARN with pointer to `fw plugin-audit` when bypassing skills exist
  - `--doctor-check` flag returns count + appropriate exit code

### 2026-02-15T09:13:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8270fcc0
- **Timestamp:** 2026-06-02T14:54:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
