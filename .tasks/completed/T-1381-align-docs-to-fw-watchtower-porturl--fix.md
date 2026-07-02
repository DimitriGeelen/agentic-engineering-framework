---
id: T-1381
name: "Align docs to fw watchtower port/url — fix CLAUDE.md self-contradiction + README
  + CONTRIBUTING"
description: >
  Align docs to fw watchtower port/url — fix CLAUDE.md self-contradiction + README
  + CONTRIBUTING

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-22T19:08:58Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-22T19:10:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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

# T-1381: Align docs to fw watchtower port/url — fix CLAUDE.md self-contradiction + README + CONTRIBUTING

## Context

T-1380 shipped `fw watchtower port`/`fw watchtower url` as the canonical accessors. Four doc sites still hardcode `http://localhost:3000` as the visible example — including CLAUDE.md line 130 which contradicts the anti-pattern rule stated on line 68 of the same file. Align the four docs so agents reading them learn the correct pattern.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md "What to verify" example no longer hardcodes `http://localhost:3000` — points at `fw watchtower url` or triple file
- [x] README.md mentions `fw watchtower port`/`url` or notes that `:3000` is the default port (not a fixed URL)
- [x] CONTRIBUTING.md mentions `fw watchtower port`/`url` or notes the default port
- [x] CLAUDE.md contains zero literal `http://localhost:3000/page` in verification examples
- [x] CLAUDE.md anti-pattern rule on line 68 still intact

## Verification

! grep -q 'curl -sf http://localhost:3000/page' CLAUDE.md
grep -q 'fw watchtower' README.md
grep -q 'fw watchtower' CONTRIBUTING.md
grep -q 'Do not write .curl http://localhost:3000' CLAUDE.md

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

### 2026-04-22T19:08:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1381-align-docs-to-fw-watchtower-porturl--fix.md
- **Context:** Initial task creation

### 2026-04-22T19:10:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f183e7ed
- **Timestamp:** 2026-06-02T14:57:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
