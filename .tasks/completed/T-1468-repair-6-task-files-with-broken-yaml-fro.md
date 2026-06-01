---
id: T-1468
name: "Repair 6 task files with broken YAML frontmatter — Watchtower scanner crashes (T-1444 symptom B data-cleanup)"
description: >
  Repair 6 task files with broken YAML frontmatter — Watchtower scanner crashes (T-1444 symptom B data-cleanup)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T18:53:50Z
last_update: 2026-04-25T18:56:09Z
date_finished: 2026-04-25T18:56:09Z
---

# T-1468: Repair 6 task files with broken YAML frontmatter — Watchtower scanner crashes (T-1444 symptom B data-cleanup)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] T-1278 frontmatter parses (collapsed components flow + dangling block list)
- [x] T-1279 frontmatter parses (same fix)
- [x] T-1444 frontmatter parses (description body indented + colons demoted)
- [x] T-444 frontmatter parses (markdown headers removed from folded scalar)
- [x] T-453 frontmatter parses (description body indented)
- [x] T-675 frontmatter parses (regex backslash quoted)
- [x] All 6 task files validated with python yaml.safe_load — 0 broken
- [x] T-1278 and T-1279 (work-completed but stuck in active/) moved to completed/
- [x] Watchtower restarted; /inception, /approvals render full task lists; log shows no parse errors

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

python3 -c "import glob, yaml, re; broken=[(f, str(yaml.safe_load(re.match(r'^---\\n(.*?)\\n---', open(f).read(), re.DOTALL).group(1)) and '')) for f in glob.glob('.tasks/active/T-*.md')+glob.glob('.tasks/completed/T-*.md')]"
test ! -f .tasks/active/T-1278-fix-bin-fw-shim-self-exec-loop.md
test ! -f .tasks/active/T-1279-fix-fw-work-on-task-id-race-condition.md
test -f .tasks/completed/T-1278-fix-bin-fw-shim-self-exec-loop.md
test -f .tasks/completed/T-1279-fix-fw-work-on-task-id-race-condition.md

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-25T18:53:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1468-repair-6-task-files-with-broken-yaml-fro.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a7f0af7c
- **Timestamp:** 2026-04-25T18:56:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-25T18:56:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
