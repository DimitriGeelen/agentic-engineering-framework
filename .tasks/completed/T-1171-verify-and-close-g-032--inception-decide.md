---
id: T-1171
name: "Verify and close G-032 — inception decide --force bypass already fixed"
description: >
  Verify and close G-032 — inception decide --force bypass already fixed

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T14:17:38Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T14:19:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1171: Verify and close G-032 — inception decide --force bypass already fixed

## Context

G-032 (CRITICAL): `fw inception decide` used `--force` internally, bypassing all gates. Already fixed — now uses `--skip-sovereignty` (T-1101/T-1142). Gap record in concerns.yaml needs to be marked resolved.

## Acceptance Criteria

### Agent
- [x] Verified `lib/inception.sh` uses `--skip-sovereignty` not `--force`
- [x] G-032 marked resolved in concerns.yaml
- [x] No `--force` in any `inception decide` path

## Verification

bash -c '! grep -q "\-\-force" lib/inception.sh'
grep -q "skip-sovereignty" lib/inception.sh
grep -q "resolved" .context/project/concerns.yaml

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

### 2026-04-12T14:17:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1171-verify-and-close-g-032--inception-decide.md
- **Context:** Initial task creation

### 2026-04-12T14:19:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-79e294ca
- **Timestamp:** 2026-06-02T14:55:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
