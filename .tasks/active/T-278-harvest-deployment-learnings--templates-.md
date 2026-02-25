---
id: T-278
name: "Harvest deployment learnings — templates to learnings.yaml"
description: >
  Extract deployment learnings hardcoded in ring20-deployer Jinja2 templates (L-BUILD-01, L-CICD-05, L-CICD-21, L-SWM-06, L-SWM-08, L-TRF-02) into framework learnings.yaml. Record T-277 deployment experience as new learnings. Feed back into fw deploy quality gates. Depends on T-277 (needs real deployment experience). See docs/reports/T-272-deploy-watchtower-ring20.md RQ-5.

status: captured
workflow_type: refactor
owner: human
horizon: now
tags: [deployment, learnings, antifragility]
components: [.context/project/learnings.yaml, agents/audit/audit.sh, bin/fw]
related_tasks: [T-272, T-277, T-100]
created: 2026-02-25T08:09:57Z
last_update: 2026-02-25T08:09:57Z
date_finished: null
---

# T-278: Harvest deployment learnings — templates to learnings.yaml

## Context

The antifragility loop: deployment experience should feed back into the framework. Ring20-deployer templates contain hardcoded learnings (L-BUILD-01, L-CICD-05, L-CICD-21, L-SWM-06, L-SWM-08, L-TRF-02) that were never captured in the framework's learnings.yaml. Additionally, T-277's deployment experience will produce new learnings that should be recorded.

This is a Level D error escalation (change ways of working) — codifying deployment practices into the framework's governance system. See Error Escalation Ladder in CLAUDE.md.

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md) (RQ-5)
**Parent inception:** T-272 | **Depends on:** T-277 (needs real deployment experience) | **Pattern:** T-097/T-100 (Operational Reflection)

### Learnings to harvest from templates
- **L-BUILD-01:** Use dedicated build container for isolation
- **L-CICD-05:** Always verify registry push before deploying
- **L-CICD-21:** Build containers can't reach LAN hosts — use host-networked helper
- **L-SWM-06:** Swarm must use `mode: host` (ingress broken on Proxmox 9.1)
- **L-SWM-08:** Use `stop-first` update order (no spare node for `start-first`)
- **L-TRF-02:** Always sync Traefik routes to BOTH nodes

### New learnings from T-272..T-277 experience
- To be captured after deployment completes

## Acceptance Criteria

### Agent
- [ ] 6 template learnings (L-BUILD-01 through L-TRF-02) added to learnings.yaml with `source: template-harvest` and `task: T-278`
- [ ] Each harvested learning includes: description, source, task reference, date
- [ ] New learnings from T-277 deployment experience captured (at least 2)
- [ ] Audit passes after learnings added (`fw audit` exit 0 or 1)
- [ ] Learning count in learnings.yaml increased by >= 8

### Human
- [ ] Harvested learnings are accurate and useful (not copied blindly from templates)
- [ ] New deployment learnings reflect actual experience, not predictions

## Verification

# Learnings file valid YAML
python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"

# Template learnings harvested (at least 6 new entries with T-278 reference)
grep -c "T-278" .context/project/learnings.yaml | python3 -c "import sys; n=int(sys.stdin.read()); assert n >= 6, f'Only {n} T-278 learnings found'; print(f'{n} learnings harvested')"

# Audit passes
bin/fw audit 2>&1 | tail -5 | grep -qv "Fail: [1-9]"

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

### 2026-02-25T08:09:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-278-harvest-deployment-learnings--templates-.md
- **Context:** Initial task creation
