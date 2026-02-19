---
id: T-199
name: "R-023 remediation — hook config validator in fw doctor"
description: >
  Build a hook configuration validator as part of fw doctor. Parses .claude/settings.json and verifies: hook structure is correct (nested format), all expected hooks are present, matcher patterns are valid, referenced scripts exist and are executable. R-023 (hook config fails silently, score 10 HIGH) has no control. Reference: Phase 2c recommendation.

status: captured
workflow_type: build
owner: claude-code
horizon: now
tags: [assurance, risk-remediation, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:26Z
last_update: 2026-02-19T19:29:26Z
date_finished: null
---

# T-199: R-023 remediation — hook config validator in fw doctor

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

## Verification

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

### 2026-02-19T19:29:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-199-r-023-remediation--hook-config-validator.md
- **Context:** Initial task creation
