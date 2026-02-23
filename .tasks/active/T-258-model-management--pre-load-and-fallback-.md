---
id: T-258
name: "Model management — pre-load and fallback logic"
description: >
  Add model management to the Ask endpoint: pre-load qwen2.5-coder-32b on Watchtower startup (ollama pull/warm), detect if model unavailable or GPU memory <2GB, auto-fallback to dolphin-llama3:8b. Unload unused model to free VRAM. ~30 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-4. Predecessor: T-256.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:50Z
last_update: 2026-02-23T20:38:50Z
date_finished: null
---

# T-258: Model management — pre-load and fallback logic

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

### 2026-02-23T20:38:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-258-model-management--pre-load-and-fallback-.md
- **Context:** Initial task creation
