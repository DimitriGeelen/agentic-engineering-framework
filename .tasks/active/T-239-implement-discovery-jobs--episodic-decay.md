---
id: T-239
name: "Implement discovery jobs — episodic decay, review queue, handover quality"
description: >
  Implement top-scoring omission detection discoveries from T-200 inception. Three jobs:
  D1 (episodic quality decay, score 25), D2 (human review queue aging, score 20),
  D8 (handover quality decay, score 20). These run as cron-compatible scripts that
  output YAML findings. Research: docs/reports/T-200-discovery-layer-design.md

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [discovery, omission]
components: []
related_tasks: [T-200, T-194, T-238]
created: 2026-02-21T23:38:55Z
last_update: 2026-02-21T23:38:55Z
date_finished: null
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
- [ ] Discovery script/module created (bash or python) with D1, D2, D8 implementations
- [ ] Each discovery outputs structured YAML findings (level, check, detail, evidence)
- [ ] D1 correctly detects episodic TODO percentage (verified against known 58% rate)
- [ ] D2 correctly identifies human-owned work-completed tasks with age calculation
- [ ] D8 correctly detects [TODO] in handover files
- [ ] Integrated into audit.sh as new section (e.g., `discovery-omission`)
- [ ] Cron schedule updated to include discovery section
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

### 2026-02-21T23:38:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-239-implement-discovery-jobs--episodic-decay.md
- **Context:** Initial task creation
