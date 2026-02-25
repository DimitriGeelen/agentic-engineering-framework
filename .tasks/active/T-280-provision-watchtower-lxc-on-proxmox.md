---
id: T-280
name: "Provision Watchtower LXC on Proxmox"
description: >
  Create LXC container on proxmox2 for Watchtower. IP: 192.168.10.141, hostname: watchtower. Install Python 3.12, git, curl, pip, gunicorn, sqlite-vec deps. Configure static IP, DNS. Enable Proxmox HA for auto-restart on node failure. See T-279 research: docs/reports/T-279-watchtower-deployment-model.md. Parent: T-279.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [deployment, infrastructure, lxc]
components: []
related_tasks: []
created: 2026-02-25T17:48:11Z
last_update: 2026-02-25T17:50:07Z
date_finished: null
---

# T-280: Provision Watchtower LXC on Proxmox

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

### 2026-02-25T17:48:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-280-provision-watchtower-lxc-on-proxmox.md
- **Context:** Initial task creation

### 2026-02-25T17:50:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
