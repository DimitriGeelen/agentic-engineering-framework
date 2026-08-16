---
id: T-1096
name: "Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message
  (G-027)"
description: >
  Extend agents/context/check-project-boundary.sh BLOCK message (the same one updated
  in T-1089 for write ops) to mention 'fw termlink dispatch --project /path --prompt
  cat README.md' as the read-only escape pattern. Currently agents must ask the human
  to authorize each cross-project read individually. Origin: G-027. Trigger: cross-session
  ring20-dashboard onboarding incident 2026-04-11 — agent needed to read sibling READMEs
  and had no documented escape.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-project-boundary.sh]
related_tasks: [T-1093, T-1089]
created: 2026-04-11T12:15:46Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-12T07:18:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 4
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1096: Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message (G-027)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Write/Edit block message in check-project-boundary.sh mentions
      TermLink dispatch as escape route for cross-project reads
- [x] Block message includes copy-pasteable example command
- [x] Existing tests still pass

## Verification

bash -c 'echo '"'"'{"tool_name":"Write","tool_input":{"file_path":"/opt/other/file.txt"}}'"'"' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash agents/context/check-project-boundary.sh 2>&1 | grep -q "termlink"'
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-11T12:15:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1096-boundary-hook-surface-termlink-dispatch-.md
- **Context:** Initial task creation

### 2026-04-12T07:16:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:18:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cdc4e627
- **Timestamp:** 2026-06-02T14:55:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'echo '"'"'{"tool_name":"Write","tool_input":{"file_path":"/opt/other/file.txt"}}'"'"' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash agents/context/check-project-boundary.sh 2>&1 `

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
