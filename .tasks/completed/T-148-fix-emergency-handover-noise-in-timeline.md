---
id: T-148
name: "Fix emergency handover noise in timeline and pre-compact"
description: >
  Fix emergency handover noise in timeline and pre-compact

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T11:25:04Z
last_update: 2026-02-18T11:27:50Z
date_finished: 2026-02-18T11:27:50Z
---

# T-148: Fix emergency handover noise in timeline and pre-compact

## Context

Sprechloop Watchtower timeline had 23 entries, 18 of which were emergency handovers (82%). A burst of 14 compactions in 13 minutes during heavy building created noise. Root cause: `handover.sh --emergency` auto-commits, and `pre-compact.sh` called it unconditionally on every compaction.

## Acceptance Criteria

- [x] Timeline collapses consecutive emergency handovers into a single summary entry
- [x] Collapsed entry shows count and time range
- [x] Isolated emergency handovers show individually with visual badge
- [x] pre-compact.sh deduplicates: skips commit if last commit was emergency handover within 5 minutes

## Verification

python3 -c "import py_compile; py_compile.compile('web/blueprints/timeline.py', doraise=True)"
grep -q "_collapse_emergency_runs" web/blueprints/timeline.py
grep -q "is_emergency" web/templates/timeline.html
grep -q "SKIP_COMMIT" agents/context/pre-compact.sh

## Decisions

### 2026-02-18 — Emergency handover commit strategy
- **Chose:** Deduplicate (skip commit if last commit was emergency within 5 min)
- **Why:** Emergency handovers must commit for safety (context survival), but rapid-fire compactions create noise. Deduplication preserves the first commit per burst while eliminating duplicates.
- **Rejected:** --no-commit always (undermines emergency handover safety purpose)

## Updates

### 2026-02-18T11:25:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-148-fix-emergency-handover-noise-in-timeline.md
- **Context:** Initial task creation

### 2026-02-18T11:27:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
