---
id: T-1309
name: "Ship watchtower.service systemd template + make fw watchtower start systemd-aware"
description: >
  Inception triggered by termlink T-1122 DEFER recommendation. Research artifact at
  /opt/termlink/docs/reports/T-1122-watchtower-wsgi-migration-recommendation.md. Core
  finding: the restart-race symptom that motivated WSGI migration is a process-management
  problem, not a WSGI-server problem. Swap is unwarranted on a single-host LAN tool
  with Flask-SocketIO threading mode. Real fix is systemd wrapping. See research artifact
  for full reasoning + 3 proposed follow-ups (systemd unit template, fw watchtower
  start systemd-aware, Werkzeug warning suppression).

status: captured
workflow_type: inception
owner: human
horizon: later
tags: [watchtower, systemd, reliability, from-termlink]
components: []
related_tasks: []
created: 2026-04-18T20:02:19Z
last_update: '2026-06-11T22:23:24Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
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
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1309: Ship watchtower.service systemd template + make fw watchtower start systemd-aware

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER — superseded by T-1312

**Rationale:** The same topic was re-ingested from termlink as T-1312 ("Pickup: Ship watchtower.service systemd template — fixes restart races without WSGI-server swap") and has already been triaged to `work-completed`. T-1309 was the originating framework-side inception (captured 2026-04-18); T-1312 is the pickup wrapper that carried the actual exploration through to completion. Running two parallel inceptions on the same question is duplicate governance overhead. Close T-1309 as DEFER with T-1312 as canonical; revisit if the pickup-side work is later revoked.

**Evidence:**
- T-1312 (`.tasks/active/T-1312-pickup-ship-watchtowerservice-systemd-te.md`): `status: work-completed`, same topic, created 2026-04-18T18:43:05Z (2 minutes after T-1309 at 20:02).
- T-1309's own body is mostly placeholder (empty Problem Statement, empty Assumptions, empty Exploration Plan) — the substantive work migrated to T-1312.
- Research artifact referenced in T-1309 frontmatter lives in the termlink repo (`/opt/termlink/docs/reports/T-1122-watchtower-wsgi-migration-recommendation.md`), which is T-1312's upstream source.
- Follows the G-046 anti-pattern (duplicate inceptions for the same underlying source_task) — T-1309 + T-1312 are the framework-side analogue of the G-059 cross-project-dedup gap filed this session.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — superseded by T-1312

Rationale: The same topic was re-ingested from termlink as T-1312 ("Pickup: Ship watchtower.service systemd template — fixes restart races without WSGI-server swap") and has already been triaged to `work-completed`. T-1309 was the originating framework-side inception (captured 2026-04-18); T-1312 is the pickup wrapper that carried the actual exploration through to completion. Running two parallel inceptions on the same question is duplicate governance overhead. Close T-1309 as DEFER with T-1312 as canonical; revisit if the pickup-side work is later revoked.

Evidence:
- T-1312 (`.tasks/active/T-1312-pickup-ship-watchtowerservice-systemd-te.md`): `status: work-completed`, same topic, created 2026-04-18T18:43:05Z (2 minutes after T-1309 at 20:02).
- T-1309's own body is mostly placeholder (empty Problem Statement, empty Assumptions, empty Exploration Plan) — the substantive work migrated to T-1312.
- Research artifact referenced in T-1309 frontmatter lives in the termlink repo (`/opt/termlink/docs/reports/T-1122-watchtower-wsgi-migration-recommendation.md`), which is T-1312's upstream source.
- Follows the G-046 anti-pattern (duplicate inceptions for the same underlying source_task) — T-1309 + T-1312 are the framework-side analogue of the G-059 cross-project-dedup gap filed this session.

**Date**: 2026-04-24T09:24:37Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-24T09:24:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — superseded by T-1312

Rationale: The same topic was re-ingested from termlink as T-1312 ("Pickup: Ship watchtower.service systemd template — fixes restart races without WSGI-server swap") and has already been triaged to `work-completed`. T-1309 was the originating framework-side inception (captured 2026-04-18); T-1312 is the pickup wrapper that carried the actual exploration through to completion. Running two parallel inceptions on the same question is duplicate governance overhead. Close T-1309 as DEFER with T-1312 as canonical; revisit if the pickup-side work is later revoked.

Evidence:
- T-1312 (`.tasks/active/T-1312-pickup-ship-watchtowerservice-systemd-te.md`): `status: work-completed`, same topic, created 2026-04-18T18:43:05Z (2 minutes after T-1309 at 20:02).
- T-1309's own body is mostly placeholder (empty Problem Statement, empty Assumptions, empty Exploration Plan) — the substantive work migrated to T-1312.
- Research artifact referenced in T-1309 frontmatter lives in the termlink repo (`/opt/termlink/docs/reports/T-1122-watchtower-wsgi-migration-recommendation.md`), which is T-1312's upstream source.
- Follows the G-046 anti-pattern (duplicate inceptions for the same underlying source_task) — T-1309 + T-1312 are the framework-side analogue of the G-059 cross-project-dedup gap filed this session.

### 2026-04-28T20:02:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-15T19:54:38Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** T-1865 sweep: DEFER limbo recovery
