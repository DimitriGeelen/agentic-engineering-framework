---
id: T-885
name: "Configurable Watchtower port + project service port registry in Watchtower
  UI"
description: >
  Inception: Configurable Watchtower port + project service port registry in Watchtower
  UI

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-05T09:38:47Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-13T13:20:24Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-885: Configurable Watchtower port + project service port registry in Watchtower UI

## Problem Statement

**Multi-project port collision.** With 11+ consumer projects, every project's Watchtower defaults to :3000. Starting work on project B kills project A's Watchtower. Same for application services — two Flask APIs both defaulting to :8080 stomp on each other.

The core problem has four parts:

1. **Per-project Watchtower port** — Set once (e.g., project A = :3001, project B = :3002), persists across sessions, restarts, and agent changes. Watchtower always starts on the configured port for that project.

2. **Per-project application service ports** — Apps developed within a project (Flask API, React frontend, workers) also get persistent port assignments. No more "which port was that API on?"

3. **Transparency** — A Watchtower page showing what's configured to run in this project and on which ports. At-a-glance visibility into the project's service landscape.

4. **Port conflict prevention** — When starting a service, check if the port is already in use. Warn or suggest an available port instead of silently killing the other process.

**For whom:** Framework users running multiple consumer projects simultaneously.
**Why now:** 11 consumer projects exist. Port collisions are a daily friction point.

### Configuration UX

How and where does the user set ports? Options to explore:

- **CLI:** `fw config set watchtower.port 3001` / `fw service register --name "my-api" --port 8080`
- **Config file:** Direct edit of `.framework.yaml` in the project root (already exists in consumer projects)
- **Watchtower UI:** `/config` or `/services` page with editable port fields
- **During init:** `fw init` or `fw context init` could prompt for port if not yet configured
- **Auto-assign:** Framework picks next available port on first init (user can override later)

Persistence target: `.framework.yaml` in the project root. Example:

```yaml
# .framework.yaml
framework_path: /opt/999-Agentic-Engineering-Framework
watchtower:
  port: 3001
services:
  - name: api
    port: 8080
    protocol: http
  - name: frontend
    port: 3010
    protocol: http
```

All approaches should converge on this file as the single source of truth per project.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-885 -->

- A-1: `.framework.yaml` is the right place for per-project port config (already exists in consumer projects)
- A-2: Watchtower startup code can read port from project config and bind to it automatically
- A-3: Application services can be registered declaratively (name + port + optional health endpoint)
- A-4: Port conflict detection via `ss -tlnp` is reliable enough for startup checks
- A-5: The existing `lib/config.sh` 3-tier resolution (CLI flag > env var > config file) works for this — config file becomes the persistent tier

## Exploration Plan

**Spike 1 — Port persistence mechanism (30 min):**
- How does `lib/config.sh` currently resolve `FW_PORT`? Map all code paths that read it
- What tools generate Watchtower URLs? (handover, `fw task review`, QR codes, Watchtower startup)
- How does Watchtower start today? Where does it read its port? Can it read from `.framework.yaml`?
- Prototype: set port in `.framework.yaml`, verify Watchtower starts on that port

**Spike 2 — Service registry + port conflict detection (30 min):**
- Design YAML schema for `.framework.yaml` service entries (name, port, protocol, start command)
- How to detect port conflicts at startup (`ss -tlnp` or equivalent)
- How to suggest available ports when conflict detected
- How does `fw doctor` extend to check registered service availability?

**Spike 3 — Watchtower services page (30 min):**
- UI showing: service name, configured port, status (up/down/conflict), clickable URL
- Per-project view — what services does THIS project own?
- Port configuration from UI? Or config-file-only with UI as read-only display?
- How consumer projects declare their services (`.framework.yaml` already exists there)

## Technical Constraints

- Watchtower runs as Flask app — service page is a standard route
- Consumer projects access framework via vendored copy or global install — config must work in both modes
- LXC deployment (prod on :5050, dev on :5051) already uses non-default ports via systemd env
- 11+ consumer projects may run simultaneously — port space must not collide
- Port scanning (`ss -tlnp`) requires no special privileges on Linux
- Config must survive: session restarts, agent changes, compactions, `fw context init`
- **Firewall (UFW):** When services start on a configured port, the firewall port must also be opened for LAN access. `watchtower.sh` already calls `ensure_firewall_open` — this pattern should extend to registered services

## Scope Fence

**IN scope:**
- Persistent per-project Watchtower port in `.framework.yaml`
- Watchtower auto-starts on configured port (no env var needed)
- Application service port registry in `.framework.yaml`
- Port conflict detection at startup (warn + suggest available port)
- Firewall port auto-open on service startup (extend `ensure_firewall_open` pattern)
- Watchtower services page showing configured services, ports, status
- `fw doctor` extension to check registered service availability
- All URL-generating tools read port from config (handover, task review, QR)

**OUT of scope:**
- Service start/stop/restart controls from Watchtower UI
- Uptime monitoring / health check polling loops
- Docker/container service discovery
- Cross-machine / cross-project port coordination
- Auto-assigning ports (user picks, framework remembers)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (A-1 through A-5)
- [x] Existing port usage in codebase mapped (7 dynamic + 3 hardcoded)
- [x] Service registry YAML schema proposed
- [x] Watchtower UI placement decided (/services page)
- [x] Recommendation written with rationale (GO)

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-885-service-registry.md`
  2. Evaluate: does the proposed service registry match your operational needs?
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-885 go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Per-project port config works cleanly with existing 3-tier resolution (CLI > env > config file)
- Watchtower startup can read `.framework.yaml` without new dependencies
- Port conflict detection is simple and reliable (`ss -tlnp`)
- Service registry schema fits naturally in `.framework.yaml` (< 15 lines per service)

**NO-GO if:**
- Config precedence becomes confusing (env var says :3000, config says :3001 — which wins?)
- Port scanning is unreliable or requires elevated privileges
- Requires process management / daemon infrastructure we don't have

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

## Recommendation

- **Recommendation:** GO
- **Rationale:** All three spikes confirm the work is bounded, achievable, and immediately useful. The multi-project port collision is a real daily friction (11 projects, all defaulting to :3000, watchtower.sh actively kills port holders). Fix requires adding one YAML tier to `fw_config`, extending `.framework.yaml` schema, and one new Watchtower page. No new dependencies. Backward compatible.
- **Evidence:**
  - 7 code paths already use `fw_config "PORT"` — adding a file tier catches them all
  - `watchtower.sh:159-178` actively kills port holders — proven collision mechanism
  - All 11 consumer projects have `.framework.yaml` — no setup needed
  - `web/config.py:20-27` already reads `settings.yaml` — same pattern applies
  - Proposed 7-task build decomposition, all small-to-medium effort

## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: GO
- Rationale: All three spikes confirm the work is bounded, achievable, and immediately useful. The multi-project port collision is a real daily friction (11 projects, all defaulting to :3000, watchtower.sh actively kills port holders). Fix requires adding one YAML tier to `fw_config`, extending `.framework.yaml` schema, and one new Watchtower page. No new dependencies. Backward compatible.
- Evidence:
  - 7 code paths already use `fw_config "PORT"` — adding a file tier catches them all
  - `watchtower.sh:159-178` actively kills port holders — proven collision mechanism
  - All 11 consumer projects have `.framework.yaml` — no setup needed
  - `web/config.py:20-27` already reads `settings.yaml` — same pattern applies
  - Proposed 7-task build decomposition, all small-to-medium effort

**Date**: 2026-04-13T11:27:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-05T11:52:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:25Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:27:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: GO
- Rationale: All three spikes confirm the work is bounded, achievable, and immediately useful. The multi-project port collision is a real daily friction (11 projects, all defaulting to :3000, watchtower.sh actively kills port holders). Fix requires adding one YAML tier to `fw_config`, extending `.framework.yaml` schema, and one new Watchtower page. No new dependencies. Backward compatible.
- Evidence:
  - 7 code paths already use `fw_config "PORT"` — adding a file tier catches them all
  - `watchtower.sh:159-178` actively kills port holders — proven collision mechanism
  - All 11 consumer projects have `.framework.yaml` — no setup needed
  - `web/config.py:20-27` already reads `settings.yaml` — same pattern applies
  - Proposed 7-task build decomposition, all small-to-medium effort

### 2026-04-13T13:20:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: Status fix for stuck inception

### 2026-04-13T13:20:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: NO-GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce56f39b
- **Timestamp:** 2026-06-02T15:05:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
