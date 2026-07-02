---
id: T-142
name: Fix fw init missing directives.yaml and gaps.yaml
description: >
  Fix fw init missing directives.yaml and gaps.yaml

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-18T09:05:24Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-02-18T09:05:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
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

# T-142: Fix fw init missing directives.yaml and gaps.yaml

## Context

T-124 cycle 4: Watchtower Govern pages (Directives, Gaps) were empty because `fw init` didn't create directives.yaml or gaps.yaml.

## Acceptance Criteria

- [x] init.sh creates directives.yaml with 4 constitutional directives (D1-D4)
- [x] init.sh creates gaps.yaml with empty register
- [x] Sprechloop directives page shows D1-D4 on Watchtower :3001

## Verification

grep -q 'directives.yaml' lib/init.sh
grep -q 'gaps.yaml' lib/init.sh
python3 -c "import yaml; d=yaml.safe_load(open('/opt/001-sprechloop/.context/project/directives.yaml')); assert len(d.get('directives', [])) == 4"

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

### 2026-02-18T09:05:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-142-fix-fw-init-missing-directivesyaml-and-g.md
- **Context:** Initial task creation

### 2026-02-18T09:05:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fa6044a5
- **Timestamp:** 2026-06-02T14:57:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
