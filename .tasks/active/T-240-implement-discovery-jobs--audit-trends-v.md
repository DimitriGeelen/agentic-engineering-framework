---
id: T-240
name: "Implement discovery jobs — audit trends, velocity trends, lifecycle anomalies"
description: >
  Implement temporal trend and insight discoveries from T-200 inception. Three jobs:
  D4 (audit trend regression, score 20), D5 (task lifecycle anomalies, score 20),
  D3/D7 (commit velocity anomalies and bunching, score 16 each). These require
  time-series data from T-238. Research: docs/reports/T-200-discovery-layer-design.md

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [discovery, trends, temporal]
components: []
related_tasks: [T-200, T-194, T-238]
created: 2026-02-21T23:38:59Z
last_update: 2026-02-21T23:38:59Z
date_finished: null
---

# T-240: Implement discovery jobs — audit trends, velocity trends, lifecycle anomalies

## Context

Implement temporal trend and insight discoveries from T-200. These detect patterns only visible across time — comparing current data against historical baselines. Requires T-238 (time-series storage) for historical data.

**Research:** `docs/reports/T-200-discovery-layer-design.md` — see "Phase 1a: Discovery Capability Catalog"
**Origin:** T-194 Phase 4 inception → T-200 GO decision
**Depends on:** T-238 (time-series storage) — MUST be completed first

### Discovery D4: Audit Trend Regression (Score 20)
- **Problem:** Current `check_audit_regression` only compares N vs N-1 (two-point). Cannot detect slow drift where each step is "only 1 worse" (GAP-T2)
- **Detection:** Compare 7-day rolling average of warn/fail counts against previous 7-day window. Detect upward trends
- **Threshold:** WARN if warn_avg increased >50% week-over-week, FAIL if fail_count > 0 for 3+ consecutive audits
- **Data:** metrics-history.yaml (T-238)
- **Frequency:** Daily

### Discovery D5: Task Lifecycle Anomalies (Score 20)
- **Problem:** T-151 went captured→completed in 2 min — triggered entire T-194 inception. No detection exists (GAP-T4)
- **Detection:** Scan completed tasks for created-to-finished < 5 min with owner:human. Also detect tasks with >7 day cycle time
- **Threshold:** WARN if any task completed in <5 min by agent with human owner
- **Data:** completed task files (created, date_finished, owner, workflow_type)
- **Frequency:** Hourly

### Discovery D3/D7: Commit Velocity Anomalies and Bunching (Score 16 each)
- **Problem:** 19-153 commits/day range. 5+ commits in 10 min = budget pressure signal. No detection exists
- **Detection:** D3: Compare daily commit count against 7-day moving average (>2x = spike, <0.3x = drop). D7: Scan git log for 5+ commits within any 10-minute window
- **Threshold:** D3: WARN if >2x or <0.3x average. D7: INFO for each bunching event detected
- **Data:** git log timestamps
- **Frequency:** D3: Daily. D7: Hourly

## Acceptance Criteria

### Agent
- [ ] Discovery script/module with D4, D5, D3, D7 implementations
- [ ] D4 reads from metrics-history.yaml and computes rolling averages
- [ ] D5 scans completed tasks for lifecycle anomalies (validated against T-151 data)
- [ ] D3 computes daily commit velocity against 7-day moving average
- [ ] D7 detects commit bunching (5+ in 10 min window) from git log
- [ ] Each discovery outputs structured YAML findings
- [ ] Integrated into audit.sh as new section (e.g., `discovery-trends`)
- [ ] Existing audit tests pass

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

### 2026-02-21T23:38:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-240-implement-discovery-jobs--audit-trends-v.md
- **Context:** Initial task creation
