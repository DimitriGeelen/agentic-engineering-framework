---
id: T-587
name: "Keyed async queue — per-key serialization primitive for concurrent operations"
description: >
  OpenClaw keyed-async-queue.ts (50 LOC): per-key serialization with cross-key parallelism. Map<string, Promise<void>> chains tasks per key. Rejection in one doesnt block next. Use cases: serialize task operations per task-id (prevent concurrent completion by TermLink workers), serialize hook execution per hook-name, serialize healing operations per error-class. Bash equivalent: flock-based per-key locking (~30 LOC). Implementation language pending T-586 (TypeScript strategy). If TS: direct port from OpenClaw. If bash: flock wrapper. Research source: /opt/openclaw-evaluation/.context/working/round2-T-022.md (Pattern 2, rated 5 stars most reusable primitive). OpenClaw source: src/util/keyed-async-queue.ts. Related: T-586 (language strategy), T-582 (session isolation — concurrent agent operations).

status: captured
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:35:21Z
last_update: 2026-03-23T21:35:21Z
date_finished: null
---

# T-587: Keyed async queue — per-key serialization primitive for concurrent operations

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-03-23T21:35:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-587-keyed-async-queue--per-key-serialization.md
- **Context:** Initial task creation
