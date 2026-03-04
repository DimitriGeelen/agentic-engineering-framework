---
id: T-303
name: "Create fw preflight command and integrate into fw init"
description: >
  New lib/preflight.sh that validates all OS dependencies before init.
  Two modes: (1) fw preflight — standalone check, (2) fw init calls it as first step.
  Check: python3 >= 3.8, PyYAML, git >= 2.0, bash >= 4.0, write perms, git identity.
  Classifies deps as required vs recommended. Shows exact install commands with
  why each dep is needed. Interactive install-with-consent: asks user before running
  any install commands (required [Y/n], recommended [y/N]). Follows sovereignty
  principle — detect silently, act only with consent. Same pattern as Tier 0.
  In non-interactive mode (CI/piped): print commands only, never auto-install.
  Source: T-294 simulation O-002, DX comparison (Terraform pattern).

status: started-work
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:21:42Z
last_update: 2026-03-04T18:36:02Z
date_finished: null
---

# T-303: Create fw preflight command and integrate into fw init

## Context

Sovereignty principle: framework detects gaps and proposes actions, human decides.
Same pattern as Tier 0 (detect, inform, ask, execute with approval).
See T-294 research artifact: `docs/reports/T-294-framework-onboarding-portable-bootstrap.md`

## Acceptance Criteria

### Agent
- [x] `fw preflight` checks: python3 version, PyYAML, git version, bash version, write perms, git identity
- [x] Each dep classified as required or recommended with explanation of why it's needed
- [x] Platform detection (apt/brew/pip) for install commands
- [x] Interactive mode: prompts user before installing (required [Y/n], recommended [y/N])
- [x] Non-interactive mode: prints commands only, exits with pass/fail code
- [x] `fw init` calls preflight as first step, stops if required deps missing
- [x] `fw preflight --check-only` skips install prompts (alias for non-interactive)

### Human
- [ ] Output is clear and actionable for someone who has never seen the framework

## Verification

fw preflight --check-only
test -f /opt/999-Agentic-Engineering-Framework/lib/preflight.sh
grep -q "do_preflight" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:21:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-303-create-fw-preflight-command-and-integrat.md
- **Context:** Initial task creation

### 2026-03-04T18:36:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
