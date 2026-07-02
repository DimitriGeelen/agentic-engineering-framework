---
id: T-304
name: "Build opt-out first-run experience after fw init"
description: >
  After fw init completes, automatically run a guided first-governance-cycle walkthrough
  (5 steps: create task, make change, commit with traceability, run audit, generate
  handover). Opt-out via --no-first-run flag on fw init. Shows the user the framework
  doing something useful immediately — closes the 'cargo run gap' from DX comparison.
  Prints each step, executes it, validates result. Source: T-294 DX comparison, Area
  6B.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:27:33Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T18:44:14Z
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
---

# T-304: Build opt-out first-run experience after fw init

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/first-run.sh` created with 3-step walkthrough (doctor, context init, next steps)
- [x] `fw init` calls first-run automatically in interactive mode
- [x] `--no-first-run` flag skips walkthrough
- [x] Non-interactive (piped/CI) skips walkthrough, shows static next steps

### Human
- [x] Walkthrough output is clear and encouraging for new users

## Verification

test -f /opt/999-Agentic-Engineering-Framework/lib/first-run.sh
grep -q "first_run" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "no-first-run" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:27:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-304-build-opt-out-first-run-experience-after.md
- **Context:** Initial task creation

### 2026-03-04T18:40:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:44:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b428234e
- **Timestamp:** 2026-06-02T15:02:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
