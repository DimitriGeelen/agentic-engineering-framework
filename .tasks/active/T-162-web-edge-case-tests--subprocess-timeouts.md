---
id: T-162
name: "Web edge case tests — subprocess timeouts, error parsing, malformed YAML"
description: >
  Extend test_app.py with: subprocess.TimeoutExpired handling for all 18 fw CLI calls, stderr error parsing, malformed YAML input (corrupt assumptions.yaml, gaps.yaml), missing .context directories, empty task files. Ref: T-158, /tmp/T-158-web-audit.md

status: captured
workflow_type: test
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:49Z
last_update: 2026-02-18T13:30:49Z
date_finished: null
---

# T-162: Web edge case tests — subprocess timeouts, error parsing, malformed YAML

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

### 2026-02-18T13:30:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-162-web-edge-case-tests--subprocess-timeouts.md
- **Context:** Initial task creation
