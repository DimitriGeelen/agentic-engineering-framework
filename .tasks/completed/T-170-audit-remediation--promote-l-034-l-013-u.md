---
id: T-170
name: "Audit remediation — promote L-034, L-013, update G-008"
description: >
  Audit remediation — promote L-034, L-013, update G-008

status: work-completed
workflow_type: refactor
owner: claude-code
horizon: null
related_tasks: []
created: 2026-02-18T17:56:38Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-02-18T17:57:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-170: Audit remediation — promote L-034, L-013, update G-008

## Context

Address 2 audit warnings + 1 gap from `fw audit` run on 2026-02-18.

## Acceptance Criteria

- [x] L-034 promoted to practice (P-011: Validate AC before closure)
- [x] L-013 promoted to practice (P-012: Structural enforcement over markdown)
- [x] G-008 updated with Playwright evidence (3rd instance), status → decided-build
- [x] L-054 recorded: Playwright snapshot context explosion pattern
- [x] Temp Playwright screenshots cleaned up

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/practices.yaml'))"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/gaps.yaml')); g8=[g for g in d['gaps'] if g['id']=='G-008'][0]; assert g8['status']=='decided-build', f'G-008 status: {g8[\"status\"]}'"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); assert any(l['id']=='L-054' for l in d['learnings'])"

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

### 2026-02-18T17:56:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-170-audit-remediation--promote-l-034-l-013-u.md
- **Context:** Initial task creation

### 2026-02-18T17:57:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cbe74259
- **Timestamp:** 2026-06-02T14:59:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
