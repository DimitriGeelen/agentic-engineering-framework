---
id: T-202
name: "Risk register cleanup — update control statuses and map existing controls"
description: >
  Risk register cleanup — update control statuses and map existing controls

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T21:32:16Z
last_update: 2026-02-19T21:33:56Z
date_finished: 2026-02-19T21:33:56Z
---

# T-202: Risk register cleanup — update control statuses and map existing controls

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] R-010 control_status updated to implemented (CTL-021/022/023 built in T-194)
- [x] R-011 control_status updated to implemented
- [x] R-028 mapped to existing budget controls (CTL-003, CTL-018, CTL-019)
- [x] All control_status fields accurate (no "decided-build" for implemented controls)
- [x] risks.yaml parses cleanly

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/risks.yaml')); print('OK')"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/risks.yaml')); r10=[r for r in d['risks'] if r['id']=='R-010'][0]; assert r10['control_status']=='implemented', f'R-010: {r10[\"control_status\"]}'"

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

### 2026-02-19T21:32:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-202-risk-register-cleanup--update-control-st.md
- **Context:** Initial task creation

### 2026-02-19T21:33:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
