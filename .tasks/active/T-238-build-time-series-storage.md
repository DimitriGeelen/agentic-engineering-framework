---
id: T-238
name: "Build time-series storage for audit metrics"
description: >
  Foundation for all temporal analysis (GAP-T1 from T-200 research). Create a lightweight
  time-series store that appends summary metrics from each audit/cron run. Prerequisite
  for D4 (audit trends), D6 (velocity trends), D9 (control drift), D12 (bypass trends).
  Research: docs/reports/T-200-discovery-layer-design.md

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [discovery, temporal, infrastructure]
components: []
related_tasks: [T-200, T-194]
created: 2026-02-21T23:38:47Z
last_update: 2026-02-21T23:59:43Z
date_finished: null
---

# T-238: Build time-series storage for audit metrics

## Context

Foundation for all temporal discovery analysis (T-200 Phase 1a, GAP-T1). The framework has 234 cron audit files but nothing aggregates them into a queryable time series — each audit is an isolated island. This task creates a lightweight append-only metrics store that enables trend detection (D4, D6, D9, D12).

**Research:** `docs/reports/T-200-discovery-layer-design.md` — see "Temporal Infrastructure Gap Analysis" section.
**Origin:** T-194 Phase 4 inception → T-200 GO decision.
**Blocking:** T-239 (omission discoveries), T-240 (trend discoveries) depend on this for historical data.

**Design:**
- Single YAML file: `.context/project/metrics-history.yaml`
- Auto-append from `audit.sh` at end of each audit run
- Schema per entry: timestamp, pass_count, warn_count, fail_count, active_tasks, completed_tasks, velocity, traceability_pct, episodic_quality_pct, open_gaps, open_risks
- 30-day rolling retention (prune older entries)
- Must be machine-readable for discovery jobs and Watchtower charts (GAP-T8)

## Acceptance Criteria

### Agent
- [x] `.context/project/metrics-history.yaml` created with documented schema
- [x] `audit.sh` appends a metrics entry on each run (all audit modes)
- [x] Schema includes: timestamp, pass, warn, fail, active_tasks, completed_tasks, velocity, traceability_pct, episodic_quality_pct, open_gaps
- [x] 30-day retention: entries older than 30 days are pruned on append
- [x] Python helper function to read and query the time series (for Watchtower/discovery jobs)
- [x] Existing audit tests pass
- [x] At least 3 historical entries exist after running audit 3 times

## Verification

# metrics-history.yaml exists and parses
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/metrics-history.yaml')); assert 'entries' in d"
# Python helper loads without error
python3 -c "import sys; sys.path.insert(0,'.'); from web.metrics_history import load_entries, latest, field_series, rolling_average, compare_windows"
# audit.sh contains metrics append block
grep -q "METRICS HISTORY APPEND" agents/audit/audit.sh
# metrics-history has at least 1 entry after audit
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/metrics-history.yaml')); assert len(d.get('entries',[])) >= 1, f'Only {len(d.get(\"entries\",[]))} entries'"

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

### 2026-02-21T23:38:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-238-build-time-series-storage.md
- **Context:** Initial task creation

### 2026-02-21T23:59:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
