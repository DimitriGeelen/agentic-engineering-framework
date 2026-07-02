---
id: T-1288
name: "Fix .fabric/watch-patterns.yaml YAML schema — exclude key misplaced inside
  patterns list"
description: >
  Fix .fabric/watch-patterns.yaml YAML schema — exclude key misplaced inside patterns
  list

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-17T20:02:23Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-21T11:00:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1288: Fix .fabric/watch-patterns.yaml YAML schema — exclude key misplaced inside patterns list

## Context

Fix applied externally to /opt/050-email-archive/.fabric/watch-patterns.yaml before this task revisit. Verified 2026-04-21 from framework repo (read-only path access permitted; edits are boundary-protected). YAML schema is now: top-level `patterns:` (list of {glob,...}) and top-level `exclude:` (list of globs). No parse errors.

## Acceptance Criteria

### Agent
- [x] `.fabric/watch-patterns.yaml` parses as valid YAML (no ParserError)
- [x] `exclude:` key is sibling of `patterns:` (top level), not inside patterns list
- [x] `fw fabric drift` runs without the YAML parse traceback in output — implied by AC1 (parse error is the only source of the traceback; parseable YAML cannot emit it)

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

# Shell commands that MUST pass before work-completed. One per line.
python3 -c "import yaml; d=yaml.safe_load(open('/opt/050-email-archive/.fabric/watch-patterns.yaml')); assert 'patterns' in d; assert 'exclude' in d; assert isinstance(d['exclude'], list)"
python3 -c "import yaml; d=yaml.safe_load(open('/opt/050-email-archive/.fabric/watch-patterns.yaml')); [p['glob'] for p in d['patterns']]"

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

### 2026-04-17T20:02:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1288-fix-fabricwatch-patternsyaml-yaml-schema.md
- **Context:** Initial task creation

### 2026-04-21T11:00:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-999babd5
- **Timestamp:** 2026-06-02T14:56:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
