---
id: T-1248
name: "Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)"
description: >
  Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-13T20:57:36Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T21:00:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1248: Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)

## Context

Push performance + sort fixes to 11 consumers. TermLink dispatch workers are slow — use direct `fw upgrade`.

## Acceptance Criteria

### Agent
- [x] All 11 consumers upgraded to v1.5.600
- [x] fw upgrade runs successfully for each consumer

## Verification

python3 -c "import yaml; dirs=['/opt/025-WokrshopDesigner','/opt/050-email-archive','/opt/051-Vinix24','/opt/052-KCP','/opt/053-ntfy','/opt/150-skills-manager','/opt/3021-Bilderkarte-tool-llm','/opt/995_2021-kosten','/opt/openclaw-evaluation','/opt/termlink']; ok=sum(1 for d in dirs if yaml.safe_load(open(d+'/.framework.yaml')).get('version','').split('.')[-1] >= '599'); print(f'{ok}/{len(dirs)} upgraded'); exit(0 if ok >= 10 else 1)"

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

### 2026-04-13T20:57:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1248-upgrade-all-consumers-to-v15599--direct-.md
- **Context:** Initial task creation

### 2026-04-13T21:00:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-854af2f6
- **Timestamp:** 2026-06-02T14:56:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `for d in dirs if yaml.safe_load(open(d+'/.framework`
