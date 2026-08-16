---
id: T-1430
name: "backfill 35 missing episodic summaries (audit EPISODIC MEMORY warnings)"
description: >
  backfill 35 missing episodic summaries (audit EPISODIC MEMORY warnings)

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:26:58Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-24T15:32:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1430: backfill 35 missing episodic summaries (audit EPISODIC MEMORY warnings)

## Context

`fw audit` reports 35 completed tasks with no `.context/episodic/T-XXX.yaml` summary (EPISODIC MEMORY CHECKS section). These are historic gaps from sessions where `update-task.sh` aborted before calling `generate-episodic` (see T-1372 G-054 diag). Backfilling regenerates summaries from git log + completed task body — the data source is the task file itself, not runtime state, so regeneration is deterministic and idempotent. Targets: T-837, T-1107, T-1115, T-1123, T-1145, T-1200, T-1213, T-1251, T-1252, T-1253, T-1255, T-1260, T-1261, T-1302–T-1305, T-1311–T-1316, T-1319, T-1321, T-1322, T-1345, T-1348–T-1353, T-1357, T-1358.

## Acceptance Criteria

### Agent
- [x] `./agents/context/context.sh generate-episodic` produced a yaml for each of the 35 tasks
- [x] Post-backfill `fw audit` reports zero "has no episodic summary" warnings in EPISODIC MEMORY CHECKS
- [x] New episodic files committed together with this task's completion

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -f .context/episodic/T-837.yaml
test -f .context/episodic/T-1107.yaml
test -f .context/episodic/T-1145.yaml
test -f .context/episodic/T-1357.yaml
test -f .context/episodic/T-1358.yaml
! bin/fw audit 2>&1 | grep -q "has no episodic summary"

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

### 2026-04-24T15:26:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1430-backfill-35-missing-episodic-summaries-a.md
- **Context:** Initial task creation

### 2026-04-24T15:32:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2b9d6837
- **Timestamp:** 2026-06-02T14:57:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `./agents/context/context.sh generate-episodic` produced a yaml for each of the 35 tasks
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/context/context.sh in: `./agents/context/context.sh generate-episodic` produced a yaml for each of the 35 tasks`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `! bin/fw audit 2>&1 | grep -q "has no episodic summary"`
