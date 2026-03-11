---
id: T-422
name: "Fix blueprint circular dep and complete gaps.yaml migration cleanup (A5+A6)"
description: >
  A5: Move load_scan() from cockpit.py to shared.py — core.py imports from cockpit creating circular dep risk. A6: Remove gaps.yaml fallback in core.py:42-44 and discovery.py — T-397 migrated to concerns.yaml but fallback code remains. Add audit rule to fail if old gaps.yaml/risks.yaml exist. Directive score: A5=7, A6=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, python, watchtower, reliability]
components: [C-004, web/blueprints/cockpit.py, web/blueprints/core.py, web/shared.py]
related_tasks: [T-397, T-411]
created: 2026-03-10T21:03:22Z
last_update: 2026-03-11T08:01:51Z
date_finished: 2026-03-11T08:01:51Z
---

# T-422: Fix blueprint circular dep and complete gaps.yaml migration cleanup (A5+A6)

## Context

Refactoring finding A5 (score 7) + A6 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**A5 — Blueprint circular dependency (core→cockpit):**
core.py:12 imports load_scan from cockpit.py. If cockpit later imports from core, silent circular
dependency. load_scan is a utility, not cockpit-specific.
See research artifact § "ARCHITECTURE" row A5.

**A6 — Incomplete migration (gaps.yaml fallback):**
T-397 migrated to concerns.yaml but core.py:42-44 and discovery.py still have fallback:
`if not concerns_path.exists(): concerns_path = gaps.yaml`. Old files may still exist.
See research artifact § "ARCHITECTURE" row A6.

## Acceptance Criteria

### Agent
- [x] load_scan() moved from cockpit.py to shared.py
- [x] Both cockpit.py and core.py import from shared.py (no cross-blueprint import)
- [x] gaps.yaml fallback removed from core.py and discovery.py
- [x] Audit rule added: fail if gaps.yaml or risks.yaml exist in .context/project/

### Human
<!-- No human verification needed for this refactoring -->

## Verification

# No module-level cross-blueprint import (lazy import inside function is OK)
! grep -q '^from web.blueprints.cockpit' web/blueprints/core.py
! grep -q 'gaps.yaml' web/blueprints/discovery.py
python3 -c "from web.blueprints.core import bp; print('OK')"

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

### 2026-03-10T21:03:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-422-fix-blueprint-circular-dep-and-complete-.md
- **Context:** Initial task creation

### 2026-03-11T07:55:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T08:01:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
