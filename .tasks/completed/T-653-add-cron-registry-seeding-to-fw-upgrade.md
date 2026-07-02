---
id: T-653
name: "Add cron registry seeding to fw upgrade"
description: >
  Add cron registry seeding to fw upgrade

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-03-28T15:35:55Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T15:37:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-653: Add cron registry seeding to fw upgrade

## Context

Consumer projects get `.context/cron/` dir and empty `cron-registry.yaml` during `fw upgrade` so they can use `fw cron generate` and the Watchtower cron page. Companion to T-448 (cron registry v2) and the `fw init` seeding already added.

## Acceptance Criteria

### Agent
- [x] `fw upgrade --dry-run` shows "WOULD SEED Cron registry + directory" for projects missing `.context/cron-registry.yaml`
- [x] `fw upgrade` creates `.context/cron/` dir and `.context/cron-registry.yaml` with empty jobs list
- [x] Existing projects with cron-registry.yaml are not overwritten

## Verification

grep -q 'cron-registry.yaml' lib/upgrade.sh
grep -q 'CRONREGEOF' lib/upgrade.sh

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

### 2026-03-28T15:35:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-653-add-cron-registry-seeding-to-fw-upgrade.md
- **Context:** Initial task creation

### 2026-03-28T15:37:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5689ebce
- **Timestamp:** 2026-06-02T15:04:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `fw upgrade --dry-run` shows "WOULD SEED Cron registry + directory" for projects missing `.context/cron-registry.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/cron-registry.yaml in: `fw upgrade --dry-run` shows "WOULD SEED Cron registry + directory" for projects missing `.context/cron-registry.yaml``
- **AC#2 (Agent)** — `fw upgrade` creates `.context/cron/` dir and `.context/cron-registry.yaml` with empty jobs list
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/cron-registry.yaml in: `fw upgrade` creates `.context/cron/` dir and `.context/cron-registry.yaml` with empty jobs list`
