---
id: T-282
name: "Remap Traefik routes from Swarm to LXC"
description: >
  Update deploy/traefik-routes.yml to point watchtower services to LXC IP (192.168.10.170:5050
  for prod, 192.168.10.170:5051 for dev) instead of Swarm nodes (.201/.202). Sync
  to both Traefik nodes (.51 and .53) via SCP. Verify both FQDNs resolve and return
  /health OK. Critical: L-TRF-02 — sync to BOTH nodes. Depends on T-281 (services
  running on LXC). See T-279 research. Parent: T-279.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [deployment, traefik, networking]
components: []
related_tasks: []
created: 2026-02-25T17:48:31Z
last_update: '2026-08-16T22:25:19Z'
date_finished: 2026-02-25T18:42:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-282: Remap Traefik routes from Swarm to LXC

## Context

Remap Traefik file-provider routes from Swarm nodes (.201/.202) to LXC (.170). See `docs/deployment-runbook.md` Traefik Routes section.

## Acceptance Criteria

### Agent
- [x] deploy/traefik-routes.yml updated: servers point to 192.168.10.170
- [x] Routes synced to Traefik node .51
- [x] Routes synced to Traefik node .53 (L-TRF-02: always sync BOTH)
- [x] Prod FQDN returns /health OK via HTTPS
- [x] Dev FQDN returns /health OK via HTTPS

## Verification

python3 -c "import yaml; yaml.safe_load(open('deploy/traefik-routes.yml'))"
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/health
curl -sf https://watchtower-dev.docker.ring20.geelenandcompany.com/health

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

### 2026-02-25T18:39:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25 — remapped [claude-code]
- **Action:** Updated traefik-routes.yml: .201/.202 → .170 (single LXC, no load balancer fan-out)
- **Synced:** SCP to both .51 and .53 Traefik nodes
- **Verified:** Both FQDNs return /health OK and dashboard HTTP 200

### 2026-02-25T18:42:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-28b993be
- **Timestamp:** 2026-06-02T15:01:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
