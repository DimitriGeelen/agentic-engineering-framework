---
id: T-256
name: "Ask endpoint — /search/ask with ollama SSE streaming"
description: >
  Create /search/ask Flask endpoint: retrieve 10 chunks via rag_retrieve() (T-255), format as numbered Markdown context, call ollama.chat(stream=True) with qwen2.5-coder-32b, yield SSE events (data: {token}). Include system prompt instructing LLM to cite sources as [1][2]. Fallback to dolphin-llama3:8b if primary unavailable. ~100 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-1 + RQ-2. Predecessor: T-255.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:18Z
last_update: 2026-02-23T20:38:18Z
date_finished: null
---

# T-256: Ask endpoint — /search/ask with ollama SSE streaming

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

### 2026-02-23T20:38:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-256-ask-endpoint--searchask-with-ollama-sse-.md
- **Context:** Initial task creation
