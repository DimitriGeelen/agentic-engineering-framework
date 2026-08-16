---
id: T-231
name: "Update git hook messages and register enforcement gaps"
description: >
  Follow-up from T-228/T-229 enforcement hardening: (1) Update commit-msg and pre-push
  hook messages — they still say 'Emergency bypass: git commit --no-verify' but Tier
  0 now blocks --no-verify. Update messaging to reference 'fw tier0 approve'. (2)
  Register remaining bypass vectors (B-002, B-006, B-009) in gaps.yaml. (3) Run unit
  tests to verify no regressions.

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-02-21T14:35:37Z
last_update: '2026-08-16T22:25:01Z'
date_finished: 2026-02-21T14:38:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:15Z'
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
  - ts: '2026-08-16T22:25:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-231: Update git hook messages and register enforcement gaps

## Context

Follow-up from T-228/T-229/T-230 enforcement hardening. See `docs/reports/T-228-enforcement-bypass-analysis.md`.

## Acceptance Criteria

### Agent
- [x] commit-msg hook references `fw tier0 approve` instead of bare `--no-verify` for bypass
- [x] pre-push hook references `fw tier0 approve` instead of bare `--no-verify` for bypass
- [x] Remaining bypass vectors registered in gaps.yaml (G-011 for B-009, G-012 for B-012)
- [x] Unit tests pass (84/84, no regressions from enforcement changes)

## Verification

grep -q "tier0 approve" /opt/999-Agentic-Engineering-Framework/.git/hooks/commit-msg
grep -q "tier0 approve" /opt/999-Agentic-Engineering-Framework/.git/hooks/pre-push
python3 -c "import yaml; yaml.safe_load(open('/opt/999-Agentic-Engineering-Framework/.context/project/gaps.yaml'))"

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

### 2026-02-21T14:35:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-231-update-git-hook-messages-and-register-en.md
- **Context:** Initial task creation

### 2026-02-21T14:38:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-68525770
- **Timestamp:** 2026-06-02T15:01:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
