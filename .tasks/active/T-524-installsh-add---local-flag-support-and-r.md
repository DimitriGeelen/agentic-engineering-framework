---
id: T-524
name: "install.sh: add --local flag support and reject unknown flags"
description: >
  install.sh silently ignores unknown flags (--local was passed but had no effect). The update path always does git fetch origin. Fix: (1) add argument parsing that rejects unknown flags, (2) support --local <path> to install/update from a local repo instead of origin.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T23:00:31Z
last_update: 2026-03-17T23:00:31Z
date_finished: null
---

# T-524: install.sh: add --local flag support and reject unknown flags

## Context

Discovered during T-522 E2E install test — `install.sh --local /path` silently ignored the flag because no arg parsing existed.

## Acceptance Criteria

### Agent
- [x] install.sh has `parse_args` function with `--local`, `--branch`, `--install-dir`, `--help` support
- [x] Unknown flags cause fatal error (not silent ignore)
- [x] `--local <path>` validates path is a git repo
- [x] Update path uses local repo as remote when `--local` specified
- [x] Fresh install clones from local repo when `--local` specified

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

### 2026-03-17T23:00:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-524-installsh-add---local-flag-support-and-r.md
- **Context:** Initial task creation
