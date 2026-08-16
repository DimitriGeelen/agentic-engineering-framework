---
id: T-040
name: Wire fw note into audit, handover, and session-capture
description: >
  Integration touchpoints for observation inbox: audit warns on stale observations
  (>7d pending), handover shows pending count, session-capture checklist includes
  inbox triage. Prevents inbox from becoming a graveyard.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T09:32:00Z
last_update: '2026-08-16T22:24:17Z'
date_finished: 2026-02-14T09:34:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-040: Wire fw note into audit, handover, and session-capture

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T09:32:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-040-wire-fw-note-into-audit-handover-and-ses.md
- **Context:** Initial task creation

### 2026-02-14T09:34:00Z — build-completed [claude-code]
- **Action:** Wired observation inbox into 3 structural enforcement points
- **Changes:**
  - `agents/audit/audit.sh`: Added Section 7 (Observation Inbox Checks) — warns on urgent pending and stale (>7d) observations
  - `agents/handover/handover.sh`: Added inbox status to console output and generated document (lists pending observations with urgent flags)
  - `agents/session-capture/AGENT.md`: Added 2 checklist items for inbox review and in-session capture
- **Tested:** Audit correctly detects OBS-002 as urgent; handover generates observation section with item list; LATEST.md restored after test

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cf27c09c
- **Timestamp:** 2026-06-02T14:54:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
