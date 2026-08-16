---
id: T-287
name: "Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification"
description: >
  Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-01T11:13:51Z
last_update: '2026-08-16T22:25:21Z'
date_finished: 2026-03-01T11:31:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-287: Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification

## Context

Fix CTL-013 false positive (T-278 verification too broad) and enrich 11 edgeless fabric cards.

## Acceptance Criteria

### Agent
- [x] CTL-013 passes for T-278 (no more false positive)
- [x] Zero edgeless fabric cards (was 11)
- [x] T-278 verification narrowed to task-specific checks

## Verification

# T-278 verification commands all pass (was failing before fix)
python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/practices.yaml'))"
# No edgeless cards
python3 -c "import yaml,os;d='.fabric/components';e=[f for f in os.listdir(d) if f.endswith('.yaml') and not(yaml.safe_load(open(os.path.join(d,f))).get('depends_on') or yaml.safe_load(open(os.path.join(d,f))).get('depended_by'))];assert len(e)==0,f'{len(e)} edgeless'"

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

### 2026-03-01T11:13:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-287-fix-audit-warnings-enrich-edgeless-fabri.md
- **Context:** Initial task creation

### 2026-03-01T11:31:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cb037176
- **Timestamp:** 2026-06-02T15:01:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
