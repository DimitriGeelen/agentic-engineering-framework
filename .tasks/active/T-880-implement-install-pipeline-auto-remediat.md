---
id: T-880
name: "Implement install pipeline auto-remediation — git hooks, identity, baseline, messaging (T-877)"
description: >
  Implement install pipeline auto-remediation — git hooks, identity, baseline, messaging (T-877)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-05T06:47:22Z
last_update: 2026-04-05T06:51:57Z
date_finished: 2026-04-05T06:51:57Z
---

# T-880: Implement install pipeline auto-remediation — git hooks, identity, baseline, messaging (T-877)

## Context

Implements the 5 fixable failure modes from T-877 inception research. See `docs/reports/T-877-install-pipeline.md`.

## Acceptance Criteria

### Agent
- [x] F2: install.sh post-install messaging includes `cd` guidance
- [x] F3: fw init auto-installs git hooks
- [x] F4: fw init inherits git identity from global config
- [x] F5: fw init auto-creates enforcement baseline
- [x] F6: Post-init message mentions onboarding tasks and agent startup
- [x] Vendored copies synced
- [x] Integration tests pass (3/3)

### Human
- [ ] [RUBBER-STAMP] Run installer on a test directory and verify improved messaging
  **Steps:**
  1. `cd /tmp && mkdir test-install-877 && cd test-install-877 && git init`
  2. `cd /opt/999-Agentic-Engineering-Framework && bin/fw init /tmp/test-install-877`
  3. `cd /tmp/test-install-877 && bin/fw doctor`
  **Expected:** No WARN for git hooks, git identity (if global exists), or enforcement baseline
  **If not:** Check lib/init.sh for the auto-remediation code
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

### 2026-04-05T06:47:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-880-implement-install-pipeline-auto-remediat.md
- **Context:** Initial task creation

### 2026-04-05T06:51:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
