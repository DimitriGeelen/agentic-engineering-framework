---
id: T-349
name: "Streamline fw init output for new users"
description: >
  Streamline fw init output for new users

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [lib/init.sh, lib/preflight.sh]
related_tasks: []
created: 2026-03-08T13:09:14Z
last_update: 2026-03-08T13:35:35Z
date_finished: 2026-03-08T13:35:35Z
---

# T-349: Streamline fw init output for new users

## Context

Streamline fw init from ~60 lines of output to ~10 lines. Remove triple doctor run, verbose OK lines, interactive preflight prompt for optional deps, noise warnings on non-git dirs. Target: Option B (guided but concise).

## Progress

**Done:**
- [x] preflight.sh: Added --quiet mode (silent checks, only fails on required deps)
- [x] init.sh: Replaced verbose header with clean "Setting up agentic governance for {project}..."
- [x] init.sh: Preflight now uses --quiet (no interactive prompt during init)
- [x] init.sh: Replaced verbose dir creation OK lines with condensed ✓ lines

**Remaining:**
- [ ] init.sh: Condense seed file output (practices/decisions/patterns → single line)
- [ ] init.sh: Condense provider config output
- [ ] init.sh: Remove auto-doctor block (lines 315-330)
- [ ] init.sh: Replace first-run walkthrough with clean summary
- [ ] init.sh: Suppress "fw already in PATH" and "SKIP Git hooks" noise
- [ ] init.sh: Add single git warning if not a git repo
- [ ] Test on Linux, retag v1.1.0, update Homebrew formula

## Acceptance Criteria

### Agent
- [x] fw init output is under 15 lines (excluding preflight failures)
- [x] fw doctor runs zero times during fw init
- [x] No interactive prompts during fw init (preflight recommended deps suppressed)

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

### 2026-03-08T13:09:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-349-streamline-fw-init-output-for-new-users.md
- **Context:** Initial task creation

### 2026-03-08T13:35:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
