---
id: T-893
name: "Fix Watchtower /config page — add .framework.yaml tier lookup"
description: >
  Fix Watchtower /config page — add .framework.yaml tier lookup

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/config.py]
related_tasks: []
created: 2026-04-05T13:23:29Z
last_update: 2026-04-05T13:24:52Z
date_finished: 2026-04-05T13:24:52Z
---

# T-893: Fix Watchtower /config page — add .framework.yaml tier lookup

## Context

Same bug as T-892 but in the Python Watchtower `/config` blueprint. `_get_config()` only checks env vars vs defaults, missing `.framework.yaml` values. Related: T-891 (added file tier to fw_config), T-892 (fixed bash registry).

## Acceptance Criteria

### Agent
- [x] `_get_config()` reads `.framework.yaml` values between env and default tiers
- [x] Source reported as `file` when value comes from `.framework.yaml`
- [x] Config page override count includes file-sourced values

## Verification

grep -q 'framework.yaml' web/blueprints/config.py
python3 -c "import ast; ast.parse(open('web/blueprints/config.py').read()); print('syntax ok')"

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

### 2026-04-05T13:23:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-893-fix-watchtower-config-page--add-framewor.md
- **Context:** Initial task creation

### 2026-04-05T13:24:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-91157a91
- **Timestamp:** 2026-06-02T15:05:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
