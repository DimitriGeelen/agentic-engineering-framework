---
id: T-170
name: "Audit remediation — promote L-034, L-013, update G-008"
description: >
  Audit remediation — promote L-034, L-013, update G-008

status: work-completed
workflow_type: refactor
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T17:56:38Z
last_update: 2026-02-18T17:57:40Z
date_finished: 2026-02-18T17:57:40Z
---

# T-170: Audit remediation — promote L-034, L-013, update G-008

## Context

Address 2 audit warnings + 1 gap from `fw audit` run on 2026-02-18.

## Acceptance Criteria

- [x] L-034 promoted to practice (P-011: Validate AC before closure)
- [x] L-013 promoted to practice (P-012: Structural enforcement over markdown)
- [x] G-008 updated with Playwright evidence (3rd instance), status → decided-build
- [x] L-054 recorded: Playwright snapshot context explosion pattern
- [x] Temp Playwright screenshots cleaned up

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/practices.yaml'))"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/gaps.yaml')); g8=[g for g in d['gaps'] if g['id']=='G-008'][0]; assert g8['status']=='decided-build', f'G-008 status: {g8[\"status\"]}'"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); assert any(l['id']=='L-054' for l in d['learnings'])"

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

### 2026-02-18T17:56:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-170-audit-remediation--promote-l-034-l-013-u.md
- **Context:** Initial task creation

### 2026-02-18T17:57:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
