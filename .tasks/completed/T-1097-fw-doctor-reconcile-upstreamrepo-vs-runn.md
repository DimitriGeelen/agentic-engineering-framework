---
id: T-1097
name: "fw doctor: reconcile upstream_repo vs running fw resolution path — flag ambiguity
  (G-028)"
description: >
  When .framework.yaml carries upstream_repo: <path> and the running fw resolves through
  a different path (host install, brew Cellar, vendored .agentic-framework/), fw doctor
  should print BOTH paths and flag if they diverge. Currently agents have no way to
  know which is canonical. Origin: G-028. Trigger: cross-session ring20-dashboard
  onboarding incident 2026-04-11 — three potential framework paths in play (.framework.yaml
  upstream_repo + ~/.local/bin/fw symlink target + actual running install) with no
  surface to reconcile them.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: [T-1093]
created: 2026-04-11T12:15:51Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-12T07:25:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1097: fw doctor: reconcile upstream_repo vs running fw resolution path — flag ambiguity (G-028)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw doctor` in consumer project mode compares upstream_repo
      from .framework.yaml with running FRAMEWORK_ROOT
- [x] Warns when paths diverge (with both paths printed)
- [x] Silent when paths match or upstream_repo is absent
- [x] `fw doctor` still passes in framework repo (no regression)

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -cE "FAIL" | grep -q "^0$"'

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

### 2026-04-11T12:15:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1097-fw-doctor-reconcile-upstreamrepo-vs-runn.md
- **Context:** Initial task creation

### 2026-04-12T07:23:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:25:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7d2cd96e
- **Timestamp:** 2026-06-02T14:55:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep -cE "FAIL" | grep -q "^0$"'`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
