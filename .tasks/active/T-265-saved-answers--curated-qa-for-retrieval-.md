---
id: T-265
name: "Saved answers — curated Q&A for retrieval flywheel"
description: >
  Add 'Save Answer' button to Q&A UI. Saved answers stored as .context/qa/YYYY-MM-DD-{slug}.md with question, answer, sources, date. Files get indexed by existing BM25+vector search infrastructure on next rebuild. Creates a knowledge flywheel: good answers become first-class retrieval sources for future queries. Implementation: POST /search/save endpoint (~20 lines in discovery.py), save-answer JS function (~15 lines in search.html), .context/qa/ directory. Ref: conversation Q3 in docs/reports/T-261-qa-phase2-research.md §Dialogue Log Q3. Predecessor: T-256 (ask endpoint), T-257 (frontend).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, knowledge, search]
components: []
related_tasks: []
created: 2026-02-24T08:37:11Z
last_update: 2026-02-24T08:37:11Z
date_finished: null
---

# T-265: Saved answers — curated Q&A for retrieval flywheel

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

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

### 2026-02-24T08:37:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-265-saved-answers--curated-qa-for-retrieval-.md
- **Context:** Initial task creation
