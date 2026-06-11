---
id: T-1292
name: "fw doctor surfaces stale watchtower triple (T-1284 B4)"
description: >
  fw doctor surfaces stale watchtower triple (T-1284 B4)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-17T22:13:32Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-18T08:50:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
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
---

# T-1292: fw doctor surfaces stale watchtower triple (T-1284 B4)

## Context

B4 of T-1284. Make `fw doctor` observe the new triple (B2) and the
identity endpoint (B1). States to report:

- `OK` — triple present, pid alive, /api/_identity matches our project
- `WARN` — triple file(s) exist but pid is dead or identity mismatches
  (recommend `fw serve`)
- `SKIP` — no triple at all (Watchtower simply not running, no concern)

Keeps doctor fast: only one curl to `/api/_identity`, 2s timeout.

## Acceptance Criteria

### Agent
- [x] `bin/fw` has a Watchtower discovery triple check block added
      (lines ~882-908) that emits OK / WARN / SKIP based on triple +
      identity endpoint
- [x] The new block reports OK when triple valid and /api/_identity
      returns matching project_root
- [x] The new block reports WARN (with `run: bin/watchtower.sh restart`
      hint) when triple present but pid dead or identity mismatches
- [x] The new block reports SKIP when no triple present (Watchtower
      simply not running — not an error)
- [x] `bash -n bin/fw` passes (syntax clean)

## Verification

bash -n bin/fw
grep -q 'Watchtower discovery triple' bin/fw
grep -q 'Watchtower running' bin/fw
grep -q 'Stale Watchtower triple' bin/fw
grep -q 'Watchtower not running (no triple)' bin/fw

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

### 2026-04-17T22:13:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1292-fw-doctor-surfaces-stale-watchtower-trip.md
- **Context:** Initial task creation

### 2026-04-18T08:50:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-48450162
- **Timestamp:** 2026-06-02T14:56:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — The new block reports WARN (with `run: bin/watchtower.sh restart`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=bin/watchtower.sh in: The new block reports WARN (with `run: bin/watchtower.sh restart``
