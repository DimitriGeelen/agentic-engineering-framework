---
id: T-1492
name: "Pickup: review.sh emit_review silent-exit on missing top-level Recommendation
  line + pipefail interaction (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-154. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [pickup, bug-report]
components: [lib/review.sh, tests/unit/lib_review.bats]
related_tasks: []
created: 2026-04-26T10:57:02Z
last_update: '2026-08-16T22:24:34Z'
date_finished: 2026-04-26T11:04:56Z
source_task_id_in_origin: T-154
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1492: Pickup: review.sh emit_review silent-exit on missing top-level Recommendation line + pipefail interaction (from 003-NTB-ATC-Plugin)

## Context

Pickup from `003-NTB-ATC-Plugin/T-154`. Inception task body lacked an unindented
`**Recommendation:**` line; `lib/review.sh:130`'s grep pipeline returned non-zero
under `set -euo pipefail`, aborting `emit_review` mid-flight via command
substitution. The `.context/working/.reviewed-T-XXX` marker was never created,
so `fw inception decide` later refused with "Task review required" — with no
clue that review.sh had silently aborted. Same family as L-282 (silent gate
failure). Fix variant (c): widen pattern + neutralize pipefail + log warning.

## Acceptance Criteria

### Agent
- [x] `lib/review.sh:130` grep pipeline ends with `|| true` so command-substitution exit code can never abort emit_review under `set -euo pipefail`
- [x] Pattern widened to match indented `**Recommendation:**` and skip HTML-commented variants
- [x] When no recommendation is found, emit_review prints a clear YELLOW warning to stderr (not silent fallback)
- [x] Regression bats test added that runs emit_review under `set -euo pipefail` on an inception task with no `**Recommendation:**` line and asserts (a) exit 0, (b) `.reviewed-T-XXX` marker exists, (c) warning text appears in stderr
- [x] Existing `tests/unit/lib_review.bats` tests still pass (12/13; test 7 Watchtower URL was pre-existing failure unrelated to this change — confirmed by `git stash` baseline)

## Verification

bash -n lib/review.sh
bats --filter "T-1492" tests/unit/lib_review.bats

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

### 2026-04-26T10:57:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1492-pickup-reviewsh-emitreview-silent-exit-o.md
- **Context:** Initial task creation

### 2026-04-26T11:03:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** applying fix (c)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-828fba40
- **Timestamp:** 2026-06-02T14:57:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T11:04:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** fix (c) applied + 3 regression bats tests green
