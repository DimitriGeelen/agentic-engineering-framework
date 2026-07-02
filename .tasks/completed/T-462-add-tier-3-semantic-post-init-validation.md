---
id: T-462
name: "Add Tier 3 semantic post-init validation"
description: >
  Extend validate-init.sh with semantic checks: governance files contain no framework-specific
  IDs (no D-030+, no L-068+), component fabric is empty (no framework internals),
  onboarding tasks reference project name not 'the framework', .framework.yaml has
  correct provider setting. These catch knowledge leakage — the core problem T-455
  identified.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-12T17:01:01Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-14T10:27:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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

# T-462: Add Tier 3 semantic post-init validation

## Context

Tier 3 semantic checks catch "knowledge leakage" — framework-specific items that shouldn't appear in consumer projects. Only runs when target is a consumer project (has `.framework.yaml`), skipped for the framework repo itself.

## Acceptance Criteria

### Agent
- [x] validate-init.sh has Tier 3 semantic section
- [x] Checks: no `__PROJECT_NAME__` literals remaining, no `scope: project` in seeded files, .framework.yaml provider matches
- [x] Tier 3 only runs for consumer projects (skipped when target == framework)
- [x] Syntax check passes

## Verification

grep -q 'Tier 3' lib/validate-init.sh
grep -q '__PROJECT_NAME__' lib/validate-init.sh
grep -q 'scope: project' lib/validate-init.sh
bash -n lib/validate-init.sh

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

### 2026-03-12T17:01:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-462-add-tier-3-semantic-post-init-validation.md
- **Context:** Initial task creation

### 2026-03-14T10:26:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T10:27:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-46b9cf03
- **Timestamp:** 2026-06-02T15:02:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
