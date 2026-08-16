---
id: T-1385
name: "Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin
  + /opt/002-Claude-Partner-Network"
description: >
  Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin
  + /opt/002-Claude-Partner-Network

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-22T20:39:20Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-04-22T20:41:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1385: Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin + /opt/002-Claude-Partner-Network

## Context

Verifies T-1383 / G-056 fix detects drift on actual consumer projects without modifying them. TermLink dispatch to dev-box agent (tl-bubfbc3w) was considered but the session has no pickup/data_plane capabilities — it is a stale registration. Verification via read-only `fw upgrade --dry-run` against each consumer instead.

## Acceptance Criteria

### Agent
- [x] `fw upgrade --dry-run /003-NTB-ATC-Plugin` reports `WOULD UPDATE resume.md (drift from template detected)` at step 7/10 (verified 2026-04-22T21:57Z)
- [x] `fw upgrade --dry-run /opt/002-Claude-Partner-Network` reports same drift at step 7/10 (verified 2026-04-22T21:57Z)
- [x] No consumer files modified (dry-run only — respects no-cross-repo-edits rule)
- [x] Future action noted: when each consumer agent re-launches, a non-dry `fw upgrade` will auto-refresh their resume.md with .bak preserved

## Verification

bin/fw upgrade --dry-run /003-NTB-ATC-Plugin >/tmp/t1385-ntb.out 2>&1 && grep -q 'WOULD UPDATE.*resume.md' /tmp/t1385-ntb.out
bin/fw upgrade --dry-run /opt/002-Claude-Partner-Network >/tmp/t1385-cpn.out 2>&1 && grep -q 'WOULD UPDATE.*resume.md' /tmp/t1385-cpn.out

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

### 2026-04-22T20:39:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1385-verify-g-056-fix-propagates-to-consumer-.md
- **Context:** Initial task creation

### 2026-04-22T20:41:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-732c9314
- **Timestamp:** 2026-06-02T14:57:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`
