---
id: T-302
name: "Complete fw init generated artifacts (cron dir, bypass-log, hooks)"
description: >
  fw init misses artifacts that cause audit warnings on day 1: (1) .context/audits/cron/
  directory not created (CTL-020), (2) .context/bypass-log.yaml not created (CTL-010),
  (3) SessionStart:compact hook not in .claude/settings.json template (CTL-007). Fix:
  add mkdir for cron dir, create empty bypass-log.yaml, add SessionStart hook to settings.json
  generation in lib/init.sh. Source: T-294 simulation O-009.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:18:55Z
last_update: '2026-08-16T22:25:26Z'
date_finished: 2026-03-04T18:33:44Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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
  - ts: '2026-08-16T22:25:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-302: Complete fw init generated artifacts (cron dir, bypass-log, hooks)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw init` creates `.context/audits/cron/` directory
- [x] `fw init` creates `.context/bypass-log.yaml` with empty bypasses array
- [x] `fw init` settings.json includes SessionStart:compact hook

## Verification

grep -q "audits/cron" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "bypass-log.yaml" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "SessionStart" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:18:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-302-complete-fw-init-generated-artifacts-cro.md
- **Context:** Initial task creation

### 2026-03-04T18:30:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:33:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e4d2d887
- **Timestamp:** 2026-06-02T15:02:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — `fw init` creates `.context/bypass-log.yaml` with empty bypasses array
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/bypass-log.yaml in: `fw init` creates `.context/bypass-log.yaml` with empty bypasses array`
