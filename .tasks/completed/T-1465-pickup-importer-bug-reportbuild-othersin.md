---
id: T-1465
name: "Pickup importer: bug-report→build, others→inception (T-1455 GO follow-on, constrained
  Option A)"
description: >
  Pickup importer: bug-report→build, others→inception (T-1455 GO follow-on, constrained
  Option A)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T18:06:41Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T18:08:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
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
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1465: Pickup importer: bug-report→build, others→inception (T-1455 GO follow-on, constrained Option A)

## Context

T-1455 GO authorized constrained Option A: pickup envelope `type: bug-report` should
create a `build` task; all other types (`learning`, `feature-proposal`, `pattern`)
keep the current `inception` mapping. The hardcoded `--type inception` lives at
lib/pickup.sh:262 inside `pickup_create_inception()`.

Evidence: 12 closed bug-fix tasks were classified as inception (per T-1455
Recommendation), causing audit C-001 noise about absent docs/reports artifacts.

## Acceptance Criteria

### Agent
- [x] `pickup_create_inception()` in lib/pickup.sh routes `bug-report` envelopes to `--type build` and all other valid types to `--type inception`
- [x] New bats test verifies the routing for both branches (bug-report → build, feature-proposal → inception)
- [x] Existing pickup tests still pass (no regression in pickup_origin_frontmatter, pickup_self_deferred)
- [x] Tags still include the original `pickup_type` so audit/reporting can filter by envelope type

## Verification

bash -n lib/pickup.sh
bats tests/unit/pickup_origin_frontmatter.bats
bats tests/unit/pickup_self_deferred.bats
bats tests/unit/pickup_type_routing.bats

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

### 2026-04-25T18:06:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1465-pickup-importer-bug-reportbuild-othersin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5ae14c2e
- **Timestamp:** 2026-06-02T14:57:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T18:08:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
