---
id: T-528
name: "Fix install.sh and FRAMEWORK.md stale claims"
description: >
  Agent evaluation found: (1) install.sh reset --hard on update with no dirty-check, (2) PyYAML uses warn() but is fatal, (3) bash version check inconsistency (install.sh=4.4 vs preflight.sh=4.0), (4) FRAMEWORK.md claims automatic updates but vendoring broke that, (5) bin/fw error message references removed framework_path field.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T23:14:47Z
last_update: 2026-03-17T23:20:40Z
date_finished: null
---

# T-528: Fix install.sh and FRAMEWORK.md stale claims

## Context

Agent evaluation report at `/tmp/fw-agent-install-eval.md`. Five code/doc fixes across install.sh, preflight.sh, FRAMEWORK.md, and bin/fw.

## Acceptance Criteria

### Agent
- [x] install.sh update path has dirty-check before reset --hard (warns user)
- [x] PyYAML check uses error() not warn() since it's fatal
- [x] Bash version check aligned between install.sh and preflight.sh (both 4.4+)
- [x] FRAMEWORK.md "automatic updates" claim corrected for vendored model
- [x] bin/fw error message no longer references removed framework_path field

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

### 2026-03-17T23:14:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-528-fix-installsh-and-frameworkmd-stale-clai.md
- **Context:** Initial task creation

### 2026-03-17T23:20:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
