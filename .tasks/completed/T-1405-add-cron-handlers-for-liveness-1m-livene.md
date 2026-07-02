---
id: T-1405
name: "Add /cron handlers for liveness-1m, liveness-boot, release-weekly (T-1241 follow-up
  surfaced by T-1404 sweep)"
description: >
  Add /cron handlers for liveness-1m, liveness-boot, release-weekly (T-1241 follow-up
  surfaced by T-1404 sweep)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [web/blueprints/cron.py]
related_tasks: []
created: 2026-04-23T16:58:51Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T17:02:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1405: Add /cron handlers for liveness-1m, liveness-boot, release-weekly (T-1241 follow-up surfaced by T-1404 sweep)

## Context

T-1404 backlog sweep ran T-1241's `## Verification` (curl /cron + count "no data") and got 5 hits vs the AC limit of 2. RCA in `web/blueprints/cron.py`:

1. `_last_run_info()` line 160 caps file scan at 200 (~2 days at 96 files/day) — too small for weekly jobs. **oe-weekly** ran Apr 20 9am (file `2026-04-20-0900.yaml` exists with `sections: oe-weekly`) but is outside the 200-file window.
2. `_match_job_to_output()` line 187 has handlers for docs-daily, pickup-process, retention-daily — **missing handlers for liveness-1m and release-weekly** (both have output on disk but no detection path).
3. **liveness-boot** is inherently overwritten by liveness-1m one minute after boot (boot_marker reset to 0). Out of scope — needs separate snapshot mechanism.

Surfaced regressions: T-1241 fix landed on Apr 13 with a 200-file cap that was sufficient at the time but no longer covers weekly cadence. Page bug, not infra bug — cron itself is running fine.

## Acceptance Criteria

### Agent
- [x] `_last_run_info()` scans up to 800 files (~8 days, covers weekly jobs)
- [x] `_match_job_to_output()` returns last-run for `liveness-1m` from `.context/monitors/liveness-latest.yaml`
- [x] `_match_job_to_output()` returns last-run for `release-weekly` from latest annotated git tag creator-date
- [x] T-1241 verification command (`curl /cron | python3 -c '...count <= 2'`) passes (≤2 no-data: pending-remind-daily paused + liveness-boot inherently overwritten)
- [x] Existing cron tests still pass (`fw test integration tests/integration/fw_cron.bats`)

## Verification

curl -sf http://localhost:3000/cron | python3 -c "import sys,re; html=sys.stdin.read(); count=len(re.findall(r'no data', html)); print(f'no-data count: {count}'); exit(0 if count <= 2 else 1)"
bats tests/integration/fw_cron.bats

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

### 2026-04-23T16:58:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1405-add-cron-handlers-for-liveness-1m-livene.md
- **Context:** Initial task creation

### 2026-04-23T17:02:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9e21cd6d
- **Timestamp:** 2026-06-02T14:57:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — `_match_job_to_output()` returns last-run for `liveness-1m` from `.context/monitors/liveness-latest.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/monitors/liveness-latest.yaml in: `_match_job_to_output()` returns last-run for `liveness-1m` from `.context/monitors/liveness-latest.yaml``
