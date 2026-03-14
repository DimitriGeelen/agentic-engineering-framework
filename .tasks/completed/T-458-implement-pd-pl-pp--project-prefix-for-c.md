---
id: T-458
name: "Implement PD-/PL-/PP- project prefix for consumer knowledge items"
description: >
  When PROJECT_ROOT != FRAMEWORK_ROOT, knowledge-adding commands (add-learning, add-decision, add-pattern, promote) use project prefix: PD-XXX, PL-XXX, PP-XXX. Framework keeps D-/L-/P-. Update ID generation in context agent, ID parsing in audit/healing/fabric, and any display logic. Prevents collision when fw upgrade later syncs framework updates.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [init, isolation, numbering]
components: []
related_tasks: []
created: 2026-03-12T17:00:44Z
last_update: 2026-03-14T08:19:20Z
date_finished: 2026-03-14T08:19:20Z
---

# T-458: Implement PD-/PL-/PP- project prefix for consumer knowledge items

## Context

When `PROJECT_ROOT != FRAMEWORK_ROOT` (consumer project), knowledge-adding commands should use project prefixes (PD-/PL-/PP-) to prevent ID collisions with framework items (D-/L-/P-) during future `fw upgrade` syncs. Patterns (FP-/SP-/WP-) are already type-namespaced and left unchanged.

## Acceptance Criteria

### Agent
- [x] `learning.sh` generates PL-XXX IDs when PROJECT_ROOT != FRAMEWORK_ROOT, L-XXX otherwise
- [x] `decision.sh` generates PD-XXX IDs when PROJECT_ROOT != FRAMEWORK_ROOT, D-XXX otherwise
- [x] `promote.sh` generates PP-XXX IDs when PROJECT_ROOT != FRAMEWORK_ROOT, P-XXX otherwise
- [x] Framework repo itself still generates L-/D-/P- IDs (backward compatible)
- [x] All three files parse cleanly (bash -n / python3 -c)

## Verification

# learning.sh generates PL- in consumer mode
grep -q 'PL-' agents/context/lib/learning.sh
# decision.sh generates PD- in consumer mode
grep -q 'PD-' agents/context/lib/decision.sh
# promote.sh generates PP- in consumer mode
grep -q 'PP-' lib/promote.sh
# All detect consumer mode via PROJECT_ROOT != FRAMEWORK_ROOT
grep -q 'PROJECT_ROOT.*FRAMEWORK_ROOT' agents/context/lib/learning.sh
grep -q 'PROJECT_ROOT.*FRAMEWORK_ROOT' agents/context/lib/decision.sh
grep -q 'framework_root' lib/promote.sh
# Syntax checks
bash -n agents/context/lib/learning.sh
bash -n agents/context/lib/decision.sh
bash -n lib/promote.sh

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

### 2026-03-12T17:00:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-458-implement-pd-pl-pp--project-prefix-for-c.md
- **Context:** Initial task creation

### 2026-03-14T08:17:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T08:19:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
