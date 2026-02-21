---
id: T-238
name: "Build time-series storage for audit metrics"
description: >
  Foundation for all temporal analysis (GAP-T1 from T-200 research). Create a lightweight
  time-series store that appends summary metrics from each audit/cron run. Prerequisite
  for D4 (audit trends), D6 (velocity trends), D9 (control drift), D12 (bypass trends).
  Research: docs/reports/T-200-discovery-layer-design.md

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [discovery, temporal, infrastructure]
components: []
related_tasks: [T-200, T-194]
created: 2026-02-21T23:38:47Z
last_update: 2026-02-21T23:38:47Z
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
- [ ] `.context/project/metrics-history.yaml` created with documented schema
- [ ] `audit.sh` appends a metrics entry on each run (all audit modes)
- [ ] Schema includes: timestamp, pass, warn, fail, active_tasks, completed_tasks, velocity, traceability_pct, episodic_quality_pct, open_gaps
- [ ] 30-day retention: entries older than 30 days are pruned on append
- [ ] Python helper function to read and query the time series (for Watchtower/discovery jobs)
- [ ] Existing audit tests pass
- [ ] At least 3 historical entries exist after running audit 3 times

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
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

## Updates

### 2026-02-21T23:38:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-238-build-time-series-storage.md
- **Context:** Initial task creation
