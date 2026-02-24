---
id: T-270
name: "Healing agent integration — semantic pattern matching via fw ask"
description: >
  Replace healing agent's 126 lines of bash keyword-matching (diagnose.sh find_similar_patterns) with a single fw ask --json --scope patterns call. The LLM understands semantic similarity (e.g. 'context explosion' matches 'memory overflow' even without keyword overlap). Also enhance context agent: on fw context focus T-XXX, generate a 200-word briefing from episodic predecessors + related patterns + CLAUDE.md sections. Files: agents/healing/healing.sh (simplify), agents/context/context.sh (add briefing). Ref: docs/reports/T-261-framework-enhancement.md §4 (programmatic access), §6 (session briefing). Depends on: T-264 (fw ask CLI).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [qa, framework, healing, agents]
components: []
related_tasks: []
created: 2026-02-24T08:38:16Z
last_update: 2026-02-24T08:38:16Z
date_finished: null
---

# T-270: Healing agent integration — semantic pattern matching via fw ask

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

### 2026-02-24T08:38:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-270-healing-agent-integration--semantic-patt.md
- **Context:** Initial task creation
