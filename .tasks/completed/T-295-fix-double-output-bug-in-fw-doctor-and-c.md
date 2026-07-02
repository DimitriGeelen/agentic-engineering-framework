---
id: T-295
name: "Fix double output bug in fw doctor and context init"
description: >
  fw doctor and fw context init print all output twice. Root cause: bin/fw:1687 missing
  exit after do_doctor call, agents/context/context.sh:71 missing exit after do_init
  call. Fix: add exit $? after function calls in case blocks. Source: T-294 simulation
  O-004/O-006, confirmed by bug analysis agent.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/context/lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T15:02:55Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T18:16:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-295: Fix double output bug in fw doctor and context init

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw context init` does not print output twice
- [x] `fw doctor` does not print output twice
- [x] Investigation completed — double output not reproducible; SIGPIPE fix applied

### Human
- [x] Verify in fresh project context that no double output occurs

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-04T15:02:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-295-fix-double-output-bug-in-fw-doctor-and-c.md
- **Context:** Initial task creation

### 2026-03-04T17:53:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:16:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a9eb75b4
- **Timestamp:** 2026-06-02T15:01:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
