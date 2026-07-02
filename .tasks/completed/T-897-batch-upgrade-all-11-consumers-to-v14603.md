---
id: T-897
name: "Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)"
description: >
  Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-05T13:32:17Z
last_update: '2026-06-11T22:24:32Z'
date_finished: 2026-04-05T13:36:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 5
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=5 (body:substrate-expand); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-897: Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)

## Context

All 11 consumers at v1.4.581, framework now at v1.4.603. Use TermLink parallel dispatch (same approach as T-887). Consumers: sprechloop, WokrshopDesigner, email-archive, Vinix24, KCP, ntfy, skills-manager, Bilderkarte, kosten, openclaw, termlink.

## Acceptance Criteria

### Agent
- [x] All 11 consumer projects upgraded to current framework version
- [x] `fw doctor` shows no version mismatch warnings for consumers

## Verification

python3 -c "import yaml; projects=['/opt/001-sprechloop','/opt/025-WokrshopDesigner','/opt/050-email-archive','/opt/051-Vinix24','/opt/052-KCP','/opt/053-ntfy','/opt/150-skills-manager','/opt/3021-Bilderkarte-tool-llm','/opt/995_2021-kosten','/opt/openclaw-evaluation','/opt/termlink']; versions=set(); [versions.add(yaml.safe_load(open(p+'/.framework.yaml')).get('version','?')) for p in projects]; print(f'All at: {versions}'); exit(0 if len(versions)==1 else 1)"

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

### 2026-04-05T13:32:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-897-batch-upgrade-all-11-consumers-to-v14603.md
- **Context:** Initial task creation

### 2026-04-05T13:36:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a6453a4a
- **Timestamp:** 2026-06-02T15:05:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
