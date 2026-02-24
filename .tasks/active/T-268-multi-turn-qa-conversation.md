---
id: T-268
name: "Multi-turn Q&A conversation"
description: >
  Add chat history to Q&A. Client-side history array sent via POST body. Switch from EventSource (GET-only) to fetch + ReadableStream for SSE consumption. Modify stream_answer() to accept history parameter (last 6 turns). Context window management: system prompt (~200 tokens) + RAG context (~3000) + 3 exchanges (~2000) = ~5200 tokens. Frontend: conversation thread display, 'New conversation' button, follow-up input. Ref: docs/reports/T-261-arch-improvements.md §1 (full architecture design, code sketches for both Python and JS). Predecessor: T-256 (endpoint), T-257 (frontend). Note: EventSource→fetch is a one-way door — changes SSE client code significantly.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [qa, frontend, chat]
components: []
related_tasks: []
created: 2026-02-24T08:37:50Z
last_update: 2026-02-24T08:37:50Z
date_finished: null
---

# T-268: Multi-turn Q&A conversation

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

### 2026-02-24T08:37:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-268-multi-turn-qa-conversation.md
- **Context:** Initial task creation
