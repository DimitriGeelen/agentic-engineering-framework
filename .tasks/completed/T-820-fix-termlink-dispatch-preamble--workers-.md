---
id: T-820
name: "Fix TermLink dispatch preamble — workers write to target files"
description: >
  Fix TermLink dispatch preamble — workers write to target files

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/dispatch/preamble.md, agents/handover/handover.sh]
related_tasks: []
created: 2026-04-03T21:46:22Z
last_update: '2026-08-16T22:25:40Z'
date_finished: 2026-04-03T21:48:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 1
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=1 
      (body:hand-wired-dispatch); F3=1 (body/components:prompt-incidental); F1=1
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-820: Fix TermLink dispatch preamble — workers write to target files

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Dispatch preamble has TermLink-specific output rules section
- [x] TermLink section instructs workers to write directly to target files
- [x] Handover agent checks for orphaned /tmp/fw-agent-* outputs

### Human
<!-- No human ACs — this is a documentation/script change with no UI.
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

### 2026-04-03T21:46:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-820-fix-termlink-dispatch-preamble--workers-.md
- **Context:** Initial task creation

### 2026-04-03T21:48:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38cb03ff
- **Timestamp:** 2026-06-02T15:05:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
