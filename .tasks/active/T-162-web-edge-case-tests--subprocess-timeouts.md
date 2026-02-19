---
id: T-162
name: "Web edge case tests — subprocess timeouts, error parsing, malformed YAML"
description: >
  Extend test_app.py with: subprocess.TimeoutExpired handling for all 18 fw CLI calls, stderr error parsing, malformed YAML input (corrupt assumptions.yaml, gaps.yaml), missing .context directories, empty task files. Ref: T-158, /tmp/T-158-web-audit.md

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:49Z
last_update: 2026-02-19T00:08:59Z
date_finished: null
---

# T-162: Web edge case tests — subprocess timeouts, error parsing, malformed YAML

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [x] Subprocess TimeoutExpired tests for task API endpoints (status, create, horizon, owner, type)
- [x] Subprocess non-zero exit code (stderr error) tests for task API endpoints
- [x] Malformed YAML handling: corrupt task files, corrupt project YAML (gaps, learnings, decisions)
- [x] Missing .context directories: pages render gracefully without .context/audits, handovers, etc.
- [x] Empty/minimal task files: task list and detail handle files with no frontmatter
- [x] All new tests pass

## Verification

python3 -m pytest web/test_app.py -v --tb=short -q 2>&1 | tail -5 | grep -q "passed"

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

### 2026-02-19T00:08:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
