---
id: T-282
name: "Remap Traefik routes from Swarm to LXC"
description: >
  Update deploy/traefik-routes.yml to point watchtower services to LXC IP (192.168.10.141:5050 for prod, 192.168.10.141:5051 for dev) instead of Swarm nodes (.201/.202). Sync to both Traefik nodes (.51 and .53) via SCP. Verify both FQDNs resolve and return /health OK. Critical: L-TRF-02 — sync to BOTH nodes. Depends on T-281 (services running on LXC). See T-279 research. Parent: T-279.

status: captured
workflow_type: build
owner: human
horizon: now
tags: [deployment, traefik, networking]
components: []
related_tasks: []
created: 2026-02-25T17:48:31Z
last_update: 2026-02-25T17:48:31Z
date_finished: null
---

# T-282: Remap Traefik routes from Swarm to LXC

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

### 2026-02-25T17:48:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-282-remap-traefik-routes-from-swarm-to-lxc.md
- **Context:** Initial task creation
