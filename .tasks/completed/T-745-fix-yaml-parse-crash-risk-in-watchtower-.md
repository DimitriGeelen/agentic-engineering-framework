---
id: T-745
name: "Fix YAML parse crash risk in Watchtower — add try/except to unprotected yaml.safe_load calls"
description: >
  R-018/R-024: Four yaml.safe_load calls without try/except can crash Watchtower on invalid YAML: fabric.py _load_subsystems, inception.py _load_assumptions + inception_detail, timeline.py _timeline_task_content.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:37:54Z
last_update: 2026-03-29T23:46:20Z
date_finished: 2026-03-29T23:46:20Z
---

# T-745: Fix YAML parse crash risk in Watchtower — add try/except to unprotected yaml.safe_load calls

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] fabric.py `_load_subsystems()` has try/except around yaml.safe_load
- [x] inception.py `_load_assumptions()` has try/except around yaml.safe_load
- [x] inception.py `inception_detail()` has try/except around yaml.safe_load
- [x] timeline.py `_timeline_task_content()` has try/except around yaml.safe_load
- [x] All protected sites log warnings on parse failure
- [x] Watchtower smoke test passes (30/30)

## Verification

python3 -c "import py_compile; py_compile.compile('web/blueprints/fabric.py', doraise=True)"
python3 -c "import py_compile; py_compile.compile('web/blueprints/inception.py', doraise=True)"
python3 -c "import py_compile; py_compile.compile('web/blueprints/timeline.py', doraise=True)"
grep -q "except.*Exception" web/blueprints/inception.py

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

### 2026-03-29T23:37:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-745-fix-yaml-parse-crash-risk-in-watchtower-.md
- **Context:** Initial task creation

### 2026-03-29T23:46:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b9df7974
- **Timestamp:** 2026-06-02T15:04:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
