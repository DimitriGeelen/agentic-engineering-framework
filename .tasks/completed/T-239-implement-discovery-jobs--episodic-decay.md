---
id: T-239
name: "Implement discovery jobs — episodic decay, review queue, handover quality"
description: >
  Implement top-scoring omission detection discoveries from T-200 inception. Three jobs:
  D1 (episodic quality decay, score 25), D2 (human review queue aging, score 20),
  D8 (handover quality decay, score 20). These run as cron-compatible scripts that
  output YAML findings. Research: docs/reports/T-200-discovery-layer-design.md

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [discovery, omission]
components: [C-004]
related_tasks: [T-200, T-194, T-238]
created: 2026-02-21T23:38:55Z
last_update: 2026-02-22T00:10:34Z
date_finished: 2026-02-22T00:10:34Z
---

# T-239: Implement discovery jobs — episodic decay, review queue, handover quality

## Context

Implement the three highest-scoring omission detection discoveries from T-200. These detect things that are wrong but not violations — gaps in quality that no existing check catches.

**Research:** `docs/reports/T-200-discovery-layer-design.md` — see "Phase 1a: Discovery Capability Catalog"
**Origin:** T-194 Phase 4 inception → T-200 GO decision
**Depends on:** T-238 (time-series storage) for historical comparison (optional — these can work point-in-time too)

### Discovery D1: Episodic Quality Decay (Score 25 — highest priority)
- **Problem:** 135/234 episodics (58%) have [TODO] placeholders — completely invisible until now
- **Detection:** Scan `.context/episodic/T-*.yaml` for `[TODO]` strings. Report total count, percentage, and list of affected task IDs
- **Threshold:** WARN if >20% have TODOs, FAIL if >50%
- **Data:** episodic YAML files
- **Frequency:** Every 30 min (fast)

### Discovery D2: Human Review Queue Aging (Score 20)
- **Problem:** 4 tasks waiting on human ACs, oldest 34h (T-227). No alert exists for aging human review items
- **Detection:** Scan `.tasks/active/` for `status: work-completed` + `owner: human`. Calculate age from `date_finished`
- **Threshold:** INFO at 24h, WARN at 48h, FAIL at 72h
- **Data:** active task files
- **Frequency:** Every 30 min (fast)

### Discovery D8: Handover Quality Decay (Score 20)
- **Problem:** Pre-compact handovers are skeletons with [TODO] sections. S-2026-0222-0011 was stale — fixed this session
- **Detection:** Scan `.context/handovers/LATEST.md` and recent handovers for `[TODO]` strings
- **Threshold:** WARN if LATEST.md has any [TODO], FAIL if >3 [TODO] sections
- **Data:** handover files
- **Frequency:** Every 30 min (fast)

## Acceptance Criteria

### Agent
- [x] Discovery script/module created (bash or python) with D1, D2, D8 implementations
- [x] Each discovery outputs structured YAML findings (level, check, detail, evidence)
- [x] D1 correctly detects episodic TODO percentage (verified against known 58% rate)
- [x] D2 correctly identifies human-owned work-completed tasks with age calculation
- [x] D8 correctly detects [TODO] in handover files
- [x] Integrated into audit.sh as new section (e.g., `discovery-omission`)
- [x] Cron schedule updated to include discovery section
- [x] Existing audit tests pass

## Verification

# Discovery section exists in audit.sh
grep -q 'should_run_section "discovery"' agents/audit/audit.sh
# D1 check exists
grep -q "D1: Episodic quality" agents/audit/audit.sh
# D2 check exists
grep -q "D2: Human review queue" agents/audit/audit.sh
# D8 check exists
grep -q "D8: Handover quality" agents/audit/audit.sh
# Cron schedule includes discovery
grep -q "discovery" agents/audit/audit.sh
# Discovery section runs without error (exit 0-2 all valid)
fw audit --section discovery --quiet 2>/dev/null; test $? -le 2

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

### 2026-02-21T23:38:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-239-implement-discovery-jobs--episodic-decay.md
- **Context:** Initial task creation

### 2026-02-22T00:06:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-22T00:10:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
