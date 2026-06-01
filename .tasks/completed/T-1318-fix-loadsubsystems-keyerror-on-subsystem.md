---
id: T-1318
name: "Fix _load_subsystems KeyError on subsystems.yaml entries with name only (T-1314 GO)"
description: >
  Fix _load_subsystems KeyError on subsystems.yaml entries with name only (T-1314 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T21:16:06Z
last_update: 2026-04-18T22:00:18Z
date_finished: 2026-04-18T22:00:18Z
---

# T-1318: Fix _load_subsystems KeyError on subsystems.yaml entries with name only (T-1314 GO)

## Context

Build sibling to T-1314 inception (GO). Source: termlink T-1129 pickup (P-036). One-line fix in `web/blueprints/fabric.py:_load_subsystems` to normalize list-of-dict entries by filling `id` from `name` when missing. Research artifact at `docs/reports/T-1314-fabric-keyerror-id.md`.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/fabric.py:_load_subsystems` normalizes list-of-dict entries — fills `id` from `name` when `id` is missing
- [x] New pytest regression in `tests/web/test_fabric_loader.py` covers both shapes (id-present and name-only) plus dict-of-dicts, mixed, garbage, and missing-file edge cases — 6 tests
- [x] `pytest tests/web/test_fabric_loader.py -q` passes (6/6)
- [x] Existing `/fabric` page still returns HTTP 200 against the running watchtower (no regression on framework's own `.fabric/subsystems.yaml`)

## Verification

cd "$PROJECT_ROOT" && python3 -c "from web.blueprints.fabric import _load_subsystems; print('import-ok')"
cd "$PROJECT_ROOT" && pytest tests/web/test_fabric_loader.py -q --tb=short

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

### 2026-04-18T21:16:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1318-fix-loadsubsystems-keyerror-on-subsystem.md
- **Context:** Initial task creation

### 2026-04-18T22:00:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
