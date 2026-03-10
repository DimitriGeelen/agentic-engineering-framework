---
id: T-431
name: "Architecture cleanup — blueprint imports, metrics retention, audit helpers (A2+A3+A7+A8+A9+A11)"
description: >
  A2: Standardize blueprint imports via __init__.py. A3: Implement metrics-history.yaml retention (currently 1684 lines, growing unbounded). A7: Extract audit_utils.py (load_latest_audit used in 3 blueprints). A8: Split discovery.py (711 lines) into knowledge/patterns/qa. A9: Standardize subprocess timeouts. A11: Ensure fabric drift runs regularly. Directive scores: A2=6, A3=6, A7=5, A8=5, A9=5, A11=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: next
tags: [refactoring, python, watchtower, reliability]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:13Z
last_update: 2026-03-10T21:04:13Z
date_finished: null
---

# T-431: Architecture cleanup — blueprint imports, metrics retention, audit helpers (A2+A3+A7+A8+A9+A11)

## Context

Architecture cleanup (A2+A3+A7+A8+A9+A11). See `docs/reports/T-411-refactoring-directive-scoring.md` § ARCHITECTURE rows A2-A11 (scores 5-6). Six medium-priority findings bundled. Largest: A8 splits discovery.py (711 lines) into domain-specific blueprints.

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

### 2026-03-10T21:04:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-431-architecture-cleanup--blueprint-imports-.md
- **Context:** Initial task creation
