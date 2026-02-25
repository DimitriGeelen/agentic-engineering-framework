---
id: T-281
name: "Deploy Watchtower to LXC — dev and prod services"
description: >
  Clone framework repo from OneDev into LXC: /opt/watchtower-dev (master) and /opt/watchtower-prod (tagged release). Create two systemd services: watchtower-dev on :5051, watchtower on :5050. Configure env vars (OLLAMA_HOST, FW_SECRET_KEY, FW_PORT). Install Python deps via pip. Verify both services start and respond on /health. Depends on T-280 (LXC provisioned). See T-279 research. Parent: T-279.

status: captured
workflow_type: build
owner: human
horizon: now
tags: [deployment, lxc, systemd]
components: []
related_tasks: []
created: 2026-02-25T17:48:21Z
last_update: 2026-02-25T17:48:21Z
date_finished: null
---

# T-281: Deploy Watchtower to LXC — dev and prod services

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

### 2026-02-25T17:48:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-281-deploy-watchtower-to-lxc--dev-and-prod-s.md
- **Context:** Initial task creation
