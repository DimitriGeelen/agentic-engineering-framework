---
id: T-1108
name: "Watchtower inception page: render ## Structural Upgrade section (G-036)"
description: >
  Bug fix — web/blueprints/inception.py hardcoded section allowlist at lines 205-214 filters out the ## Structural Upgrade section added per T-1105 chokepoint+invariant-test discipline. T-1100..T-1106 all have Structural Upgrade sections in their task files, but Watchtower's /inception/T-XXX page skips them. Human reviewing via 'fw task review' cannot see the upgrade (the whole point of the structural discipline pass). Fix: (1) add 'structural_upgrade': _md(_extract_section(task_body, 'Structural Upgrade')) to sections dict, (2) add {% if sections.structural_upgrade %} block to inception_detail.html between recommendation and decision. Verify by curling /inception/T-1106 and grep-checking the heading. Related: T-1105 (chokepoint discipline), T-1100..T-1106 (inceptions missing section). Estimated 10 lines, 2 files.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T14:39:18Z
last_update: 2026-04-11T14:41:04Z
date_finished: 2026-04-11T14:41:04Z
---

# T-1108: Watchtower inception page: render ## Structural Upgrade section (G-036)

## Context

`web/blueprints/inception.py:205-214` has a hardcoded section allowlist. The `## Structural Upgrade` section (added to T-1100..T-1106 per T-1105 chokepoint+invariant-test discipline) is NOT in the allowlist, so Watchtower's `/inception/T-XXX` page silently drops it. Humans reviewing via `fw task review` cannot see the structural upgrade — the whole point of the discipline pass is invisible to them. Verified via `curl -sf http://localhost:3003/inception/T-1100 | grep -c "Structural Upgrade"` → 0 (across T-1100..T-1106).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py` sections dict includes `"structural_upgrade": _md(_extract_section(task_body, "Structural Upgrade"))`
- [x] `web/templates/inception_detail.html` renders `{% if sections.structural_upgrade %}` block between `recommendation` and `decision`
- [x] Watchtower restarted to reload templates
- [x] `curl -sf http://localhost:3003/inception/T-1106 | grep -c "Structural Upgrade"` returns >= 1 (returns 2)
- [x] Same check passes for T-1100, T-1101, T-1102, T-1103, T-1104 (all return 2)
- [x] Existing sections (Problem Statement, Assumptions, Recommendation, etc.) still render — no regression

## Verification

curl -sf http://localhost:3003/inception/T-1106 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1100 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1101 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1102 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1103 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1104 | grep -q "Structural Upgrade"
curl -sf http://localhost:3003/inception/T-1106 | grep -q "Recommendation"

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

### 2026-04-11T14:39:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1108-watchtower-inception-page-render--struct.md
- **Context:** Initial task creation

### 2026-04-11T14:39:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Fixing inception renderer to show Structural Upgrade section

### 2026-04-11T14:41:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
