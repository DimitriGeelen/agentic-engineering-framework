---
id: T-511
name: "Write governance.yaml — predictability x blast-radius operation class declarations"
description: >
  Create governance.yaml declaring 12 operation classes mapped to the 2x2 matrix (predictability x blast-radius). Serves as architecture documentation and risk communication tool. From T-477 Spike 2 draft format.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [governance, architecture, D2]
components: []
related_tasks: []
created: 2026-03-17T11:34:11Z
last_update: 2026-03-17T11:38:33Z
date_finished: null
---

# T-511: Write governance.yaml — predictability x blast-radius operation class declarations

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `governance.yaml` exists at `.context/project/governance.yaml`
- [x] File parses as valid YAML
- [x] Contains 12 operation classes covering all 4 quadrants
- [x] Each class has: predictability, blast_radius, enforcement fields

### Human
- [ ] [REVIEW] Operation classes accurately reflect governance model
  **Steps:**
  1. Read `.context/project/governance.yaml`
  2. Check Q4 classes match CLAUDE.md autonomous mode boundaries
  **Expected:** Declaration captures the enforcement intent from T-477 research
  **If not:** Note which classes need adjustment

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/governance.yaml')); assert len(d.get('operation_classes',{})) >= 10"
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

### 2026-03-17T11:34:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-511-write-governanceyaml--predictability-x-b.md
- **Context:** Initial task creation

### 2026-03-17T11:38:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
