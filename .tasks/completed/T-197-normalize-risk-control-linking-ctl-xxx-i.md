---
id: T-197
name: "Normalize risk-control linking (CTL-XXX IDs)"
description: >
  Migrate risks.yaml controls field from script names (e.g., check-active-task.sh)
  to CTL-XXX IDs (e.g., CTL-001). Ensures cross-register consistency between risks.yaml
  and controls.yaml. Reference: D-Phase2-004 follow-up.

status: work-completed
workflow_type: refactor
owner: claude-code
horizon:
tags: [assurance, normalization, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:19Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-02-19T19:33:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-197: Normalize risk-control linking (CTL-XXX IDs)

## Context

D-Phase2-004 follow-up. risks.yaml `controls` field previously used script names; now uses CTL-XXX IDs from controls.yaml. Reverse map built from controls.yaml `mitigates` field. 21/37 risks have formal controls, 16 rely on ad-hoc fixes (captured in residual_notes).

## Acceptance Criteria

- [x] All controls: fields in risks.yaml use CTL-XXX IDs (not script names)
- [x] Reverse map derived from controls.yaml mitigates field
- [x] YAML parses clean after changes
- [x] Inline comments preserved (scoring context)
- [x] Watchtower page renders correctly with normalized data

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/risks.yaml')); [exit(1) for r in d['risks'] if any(c for c in r.get('controls',[]) if not c.startswith('CTL-'))]"
python3 -c "import yaml; yaml.safe_load(open('.context/project/risks.yaml')); print('valid')"
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/risks').read().decode(); assert 'Risk Register' in r"

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

### 2026-02-19T19:29:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-197-normalize-risk-control-linking-ctl-xxx-i.md
- **Context:** Initial task creation

### 2026-02-19T19:30:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T19:33:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e4f604a3
- **Timestamp:** 2026-06-02T15:00:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
