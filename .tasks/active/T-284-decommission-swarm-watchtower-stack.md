---
id: T-284
name: "Decommission Swarm watchtower stack"
description: >
  After LXC deployment verified and Traefik remapped: remove Swarm watchtower stack (docker stack rm watchtower), clean up registry images, update ring20-deployer ports.yaml to reflect LXC deployment. Keep Docker deployment files (Dockerfile, compose, buildspec) in repo history but mark as superseded. Depends on T-282 (Traefik remapped and verified). See T-279 research. Parent: T-279.

status: captured
workflow_type: decommission
owner: human
horizon: now
tags: [deployment, decommission, swarm]
components: []
related_tasks: []
created: 2026-02-25T17:48:42Z
last_update: 2026-02-25T17:48:42Z
date_finished: null
---

# T-284: Decommission Swarm watchtower stack

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

### 2026-02-25T17:48:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-284-decommission-swarm-watchtower-stack.md
- **Context:** Initial task creation
