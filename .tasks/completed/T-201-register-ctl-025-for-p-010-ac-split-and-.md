---
id: T-201
name: "Register CTL-025 for P-010 AC split and update risk scores"
description: >
  Register CTL-025 for P-010 AC split and update risk scores

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T21:29:43Z
last_update: 2026-02-19T21:31:37Z
date_finished: 2026-02-19T21:31:37Z
---

# T-201: Register CTL-025 for P-010 AC split and update risk scores

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] CTL-025 added to controls.yaml with correct schema
- [x] R-002 updated with CTL-025 in controls list and residual_notes
- [x] OE test for CTL-025 added to audit.sh (oe-daily section)
- [x] controls.yaml parses cleanly

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/controls.yaml')); assert any(c['id']=='CTL-025' for c in d['controls']), 'CTL-025 missing'"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/risks.yaml')); r2=[r for r in d['risks'] if r['id']=='R-002'][0]; assert 'CTL-025' in r2.get('controls',[]), 'R-002 missing CTL-025'"
grep -q 'CTL-025' agents/audit/audit.sh
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

### 2026-02-19T21:29:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-201-register-ctl-025-for-p-010-ac-split-and-.md
- **Context:** Initial task creation

### 2026-02-19T21:31:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
