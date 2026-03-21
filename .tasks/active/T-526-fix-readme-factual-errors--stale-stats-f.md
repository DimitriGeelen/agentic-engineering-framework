---
id: T-526
name: "Fix README factual errors — stale stats, fabricated counts, wrong thresholds"
description: >
  Agent evaluation found: (1) task count says 445/312, actual ~523/479, (2) Tier 0 count says 49, actual 13, (3) budget threshold says 85%, should be 90%, (4) traceability says 96%, actual 99%. These appear across multiple locations in README.md.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T23:14:40Z
last_update: 2026-03-17T23:20:56Z
date_finished: 2026-03-17T23:20:56Z
---

# T-526: Fix README factual errors — stale stats, fabricated counts, wrong thresholds

## Context

Agent evaluation report at `/tmp/fw-agent-readme-eval.md`. Stats hardcoded in multiple README locations.

## Acceptance Criteria

### Agent
- [x] Task counts updated to match `ls .tasks/completed/ | wc -l` and `ls .tasks/active/ | wc -l`
- [x] Tier 0 approval count matches `grep -c "commit:" .context/project/bypass-log.yaml`
- [x] Budget threshold in enforcement diagram changed from 85% to 90%
- [x] Traceability percentage updated to match actual
- [x] No occurrence of "445" or "312 completed" remains in README

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

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

### 2026-03-17T23:14:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-526-fix-readme-factual-errors--stale-stats-f.md
- **Context:** Initial task creation

### 2026-03-17T23:18:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-17T23:20:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
