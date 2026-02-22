---
id: T-249
name: "Refine D5 lifecycle anomaly detection to reduce false positive rate"
description: >
  D5 lifecycle anomaly detection flags legitimate human admin tasks at roughly half FP rate. Needs refinement: filter by workflow_type or add owner: agenthuman plus fast-completion as expected pattern. GO criterion was under 20 pct FP. Research: docs/reports/T-200-discovery-layer-design.md Phase 3. Related: T-200, T-239.

status: work-completed
workflow_type: build
owner:
horizon: later
tags: []
components: [C-004]
related_tasks: []
created: 2026-02-22T09:42:05Z
last_update: 2026-02-22T14:39:47Z
date_finished: 2026-02-22T14:39:47Z
---

# T-249: Refine D5 lifecycle anomaly detection to reduce false positive rate

## Context

D5 in `agents/audit/audit.sh` flagged 8 human-owned tasks as lifecycle anomalies (fast completion). All 8 were false positives — legitimate quick work. Research: `docs/reports/T-200-discovery-layer-design.md` Phase 3.

## Acceptance Criteria

### Agent
- [x] D5 filters out test/specification/decommission workflow types (inherently fast)
- [x] D5 filters out tasks with 2+ commits (proves substantive work)
- [x] D5 still only flags human-owned tasks (agent fast-completion is normal)
- [x] Audit D5 output drops from 8 to <=1 anomalies
- [x] Remaining flag (T-203) is a genuine signal (0 commits, 0.5min throwaway)

## Verification

# D5 filters are present (no fw audit — causes CTL-013 recursion)
grep -q "owner != .human" agents/audit/audit.sh
# Filters present in code
grep -q "FAST_TYPES" agents/audit/audit.sh
grep -q "count_commits" agents/audit/audit.sh

## Decisions

### 2026-02-22 — FP filtering strategy
- **Chose:** Three-filter approach: workflow_type allowlist + commit count >=2 + human-only scope
- **Why:** Eliminates all 8 FPs while keeping genuine signals. Commit count is the strongest signal — tasks with real work have commits.
- **Rejected:** Lowering threshold to <2min (still misses T-021 at 3.1min); using last_update as start time (unreliable, doesn't reflect actual work)

## Updates

### 2026-02-22T09:42:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-249-refine-d5-lifecycle-anomaly-detection-to.md
- **Context:** Initial task creation

### 2026-02-22T14:33:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-22T14:39:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
