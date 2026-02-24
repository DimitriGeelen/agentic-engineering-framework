---
id: T-264
name: "fw ask CLI — synchronous RAG+LLM wrapper"
description: >
  Build fw ask CLI command: synchronous wrapper around rag_retrieve() + non-streaming Ollama call. Keystone for all framework integrations. Create lib/ask-api.py (~80 lines: wrapper + non-streaming Ollama + JSON output), lib/ask.sh (~30 lines: arg parsing + Python invocation), add route in bin/fw. Support: --scope {all,patterns,episodic,specs,tasks} to bias retrieval, --json for programmatic consumption, --concise for brief answers. Net: ~150 new lines. Ref: docs/reports/T-261-framework-enhancement.md §1 (onboarding), §Architectural Notes. Predecessor: T-255 (RAG), T-256 (ask endpoint). Enables: T-266 (healing integration), T-267 (session briefing).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, cli, framework]
components: []
related_tasks: []
created: 2026-02-24T08:37:00Z
last_update: 2026-02-24T08:37:00Z
date_finished: null
---

# T-264: fw ask CLI — synchronous RAG+LLM wrapper

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

### 2026-02-24T08:37:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-264-fw-ask-cli--synchronous-ragllm-wrapper.md
- **Context:** Initial task creation
