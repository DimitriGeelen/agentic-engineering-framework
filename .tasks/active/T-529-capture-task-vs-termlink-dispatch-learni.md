---
id: T-529
name: "Capture Task vs TermLink dispatch learning"
description: >
  Capture Task vs TermLink dispatch learning

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T23:24:22Z
last_update: 2026-03-17T23:24:22Z
date_finished: null
---

# T-529: Capture Task vs TermLink dispatch learning

## Context

Cross-session reflection: framework agent was using Task tool agents for work that TermLink dispatch would handle better. Capture the decision matrix.

## Acceptance Criteria

### Agent
- [x] MEMORY.md updated with Task vs TermLink dispatch decision matrix
- [x] Learning recorded via fw context add-learning
- [x] CLAUDE.md Sub-Agent Dispatch Protocol updated with Task vs TermLink section
- [x] Decision rule added: 3+ agents with >1K output → use TermLink dispatch
- [x] TermLink dispatch pattern added to Dispatch Patterns section

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

### 2026-03-17T23:24:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-529-capture-task-vs-termlink-dispatch-learni.md
- **Context:** Initial task creation
