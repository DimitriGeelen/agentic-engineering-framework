---
id: T-275
name: "Pre-deploy quality gate — audit section + gated fw deploy"
description: >
  Add deployment section to audit.sh (clean git, task traceability, deployment files exist, test suite). Replace fw deploy exec passthrough with gated flow that runs pre-deploy audit, blocks on failure, logs to .context/deployments/. Add Swarm rollback to buildspec template. Depends on T-274 (needs deployment files to validate). See docs/reports/T-272-deploy-watchtower-ring20.md RQ-4.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [deployment, audit, quality-gate, governance]
components: [agents/audit/audit.sh, bin/fw, .context/deployments/]
related_tasks: [T-272, T-274, T-276, T-277]
created: 2026-02-25T08:09:44Z
last_update: 2026-02-25T09:34:47Z
date_finished: null
---

# T-275: Pre-deploy quality gate — audit section + gated fw deploy

## Context

The biggest governance gap: `fw deploy` is a raw `exec` passthrough that bypasses all framework gates (task, audit, Tier 0). Deployment is classified as Tier 0 in 011-EnforcementConfig.md but has zero enforcement. This task closes that gap with a pre-deploy audit section and a gated `fw deploy` flow.

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md) (RQ-4: Quality Gates)
**Parent inception:** T-272 | **Depends on:** T-274 (needs deployment files to validate) | **Unblocks:** T-276, T-277

### Changes
1. **audit.sh** — Add `deployment` section with gates: active task, clean git, HEAD traceability, deployment files exist
2. **bin/fw** — Replace `exec` passthrough with gated flow: run pre-deploy audit, block on fail, delegate to ring20-deployer, log deployment record
3. **Deployment records** — Create `.context/deployments/` directory, YAML schema for deployment logs
4. **Swarm rollback** — Add `docker service rollback` to buildspec-swarm template on convergence failure

## Acceptance Criteria

### Agent
- [x] `fw audit --section deployment` runs and produces pass/warn/fail results
- [x] Audit checks: active task, clean git, HEAD commit has T-XXX, deployment files exist
- [x] `fw deploy` no longer uses raw `exec` — runs audit gates first
- [x] `fw deploy` blocks (exit 1) when pre-deploy audit fails
- [x] `fw deploy` logs deployment record to `.context/deployments/YYYY-MM-DD-HHMM.yaml`
- [x] Deployment record schema includes: app, tier, version, task, commit, gates, result
- [x] `fw deploy status` still works (passthrough for status/ports subcommands preserved)
- [x] Swarm buildspec template includes `docker service rollback` on convergence failure
- [x] Existing audit sections unaffected (regression test)

### Human
- [ ] Pre-deploy audit output is clear and actionable when gates fail
- [ ] Deployment record YAML is human-readable and useful for post-mortems

## Verification

# Audit section exists
grep -q "deployment" agents/audit/audit.sh

# fw deploy has gated flow (not just raw exec)
grep -q "Pre-Deploy Audit" bin/fw

# Deployment records directory exists
test -d .context/deployments || mkdir -p .context/deployments

# Audit still works
bin/fw audit --section structure --quiet

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

### 2026-02-25T08:09:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-275-pre-deploy-quality-gate--audit-section--.md
- **Context:** Initial task creation

### 2026-02-25T09:24:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T09:34:47Z — status-update [task-update-agent]
- **Change:** owner: human → agent
