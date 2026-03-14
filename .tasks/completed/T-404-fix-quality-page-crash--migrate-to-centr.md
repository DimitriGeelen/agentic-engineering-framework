---
id: T-404
name: "Fix quality page crash + migrate to centralized load_yaml"
description: >
  Fix quality page 500 error caused by unescaped double quotes in audit YAML output.
  Root cause: audit.sh writes mitigation strings with inner quotes that break YAML parsing.
  Also migrate quality.py to centralized load_yaml from shared.py (T-403 gap).

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [watchtower, bugfix]
components: []
related_tasks: [T-403]
created: 2026-03-10T13:42:00Z
last_update: 2026-03-12T12:41:20Z
date_finished: 2026-03-10T13:44:33Z
---

# T-404: Fix quality page crash + migrate to centralized load_yaml

## Context

Quality page (/quality) under Govern crashed with 500 due to unescaped double quotes in audit YAML.
Two fixes: (1) fix audit.sh YAML output to escape inner quotes, (2) migrate quality.py to shared load_yaml.

## Acceptance Criteria

### Agent
- [x] Fix unescaped quotes in `.context/audits/2026-03-10.yaml`
- [x] Fix audit.sh YAML writer to escape inner double quotes in check/mitigation strings
- [x] Migrate quality.py from raw `yaml.safe_load` to shared `load_yaml`
- [x] Quality page loads without error (`curl -sf http://localhost:3000/quality`)

### Human
- [x] [RUBBER-STAMP] Quality page renders correctly in browser
  **Steps:**
  1. Open http://localhost:3000/quality in browser
  2. Verify audit findings are listed with PASS/WARN/FAIL indicators
  3. Click "Run Audit" button and confirm results refresh
  **Expected:** Page loads with full audit results, no 500 error
  **If not:** Check Flask console for traceback

## Verification

curl -sf http://localhost:3000/quality > /dev/null
python3 -c "import yaml; yaml.safe_load(open('.context/audits/2026-03-10.yaml'))"
grep -q "load_yaml" web/blueprints/quality.py
! grep -q "import yaml" web/blueprints/quality.py

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

### 2026-03-10T13:42:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-404-fix-quality-page-crash--migrate-to-centr.md
- **Context:** Initial task creation

### 2026-03-10T13:44:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
