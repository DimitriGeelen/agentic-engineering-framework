---
id: T-527
name: "README additions — prerequisites, troubleshooting, fw update/vendor docs"
description: >
  Three documentation gaps found by agent evaluation: (1) No prerequisites section (bash 4.4+, python3, PyYAML, macOS note), (2) No troubleshooting section for common errors, (3) fw update and fw vendor completely undocumented. All high priority for new user experience.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T23:14:43Z
last_update: 2026-03-17T23:21:05Z
date_finished: null
---

# T-527: README additions — prerequisites, troubleshooting, fw update/vendor docs

## Context

Agent evaluation reports at `/tmp/fw-agent-docs-gaps.md` and `/tmp/fw-agent-readme-eval.md`.

## Acceptance Criteria

### Agent
- [x] Prerequisites section exists in README with bash 4.4+, python3, PyYAML, git requirements
- [x] macOS note about `brew install bash` included
- [x] `fw update` and `fw update --check` documented in README
- [x] Vendored model (.agentic-framework/) explained in Updating section
- [x] Troubleshooting section with top 5 common errors and fixes
- [x] `install.sh --local` documented in README install section

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

### 2026-03-17T23:14:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-527-readme-additions--prerequisites-troubles.md
- **Context:** Initial task creation

### 2026-03-17T23:21:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
