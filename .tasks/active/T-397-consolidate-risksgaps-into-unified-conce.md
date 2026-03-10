---
id: T-397
name: "Consolidate risks+gaps into unified concerns register (Option D)"
description: >
  Merge risks.yaml + gaps.yaml into concerns.yaml with type: gap|risk. Delete issues.yaml. Update controls.yaml backlinks. Update audit, handover, CLAUDE.md references. Update web routes and templates. Parent: T-396.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: [C-004, agents/handover/handover.sh, lib/init.sh, C-003, web/blueprints/risks.py, web/templates/risks.html]
related_tasks: []
created: 2026-03-09T20:07:48Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-10T06:59:34Z
---

# T-397: Consolidate risks+gaps into unified concerns register (Option D)

## Context

Parent: T-396. Research: docs/reports/T-396-risk-management-disposition.md

## Acceptance Criteria

### Agent
- [x] concerns.yaml created with merged gaps + risks (type field)
- [x] risks.yaml and issues.yaml archived to docs/archive/
- [x] All code references updated (audit, handover, discovery, init, CLAUDE.md)
- [x] /risks page renders unified concerns view with heatmap
- [x] fw audit passes (concerns register checks work)
- [x] Backward-compatible fallback (concerns.yaml → gaps.yaml)

### Human
- [ ] [RUBBER-STAMP] /risks page looks correct in browser
  **Steps:**
  1. Open http://localhost:3000/risks
  2. Check watching concerns show gaps (blue) and risks (orange)
  3. Check heatmap renders risk entries
  **Expected:** Unified view with type badges, heatmap has data points
  **If not:** Note which section is broken

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
curl -sf http://localhost:3000/risks | grep -q "Concerns"
grep -q "concerns.yaml" agents/audit/audit.sh
grep -q "concerns.yaml" agents/handover/handover.sh

## Decisions

### 2026-03-09 — Consolidation approach
- **Chose:** Option D — merge gaps.yaml + risks.yaml into concerns.yaml with type field
- **Why:** Scored 8.2/10 on weighted matrix (4 directives + practical criteria)
- **Rejected:** A (archive, 7.9), B (slim, 5.4), C (full integration, 6.5)

## Updates

### 2026-03-09T20:07:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-397-consolidate-risksgaps-into-unified-conce.md
- **Context:** Initial task creation

### 2026-03-10T06:59:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
