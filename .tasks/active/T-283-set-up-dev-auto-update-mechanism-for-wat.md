---
id: T-283
name: "Set up dev auto-update mechanism for Watchtower LXC"
description: >
  Configure automatic updates for watchtower-dev on the LXC: OneDev webhook on push to master triggers git pull + systemctl restart watchtower-dev on the LXC. Alternative: cron job every 5 minutes checking for new commits. Prod updates remain manual/explicit only. Depends on T-281 (services deployed). See T-279 research. Parent: T-279.

status: captured
workflow_type: build
owner: human
horizon: now
tags: [deployment, automation, ci-cd]
components: []
related_tasks: []
created: 2026-02-25T17:48:38Z
last_update: 2026-02-25T17:48:38Z
date_finished: null
---

# T-283: Set up dev auto-update mechanism for Watchtower LXC

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

### 2026-02-25T17:48:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-283-set-up-dev-auto-update-mechanism-for-wat.md
- **Context:** Initial task creation
