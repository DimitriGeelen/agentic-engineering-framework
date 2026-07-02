---
id: T-1471
name: "Doc drift fix — add gpu subcommand to CLAUDE.md Quick Reference"
description: >
  Doc drift fix — add gpu subcommand to CLAUDE.md Quick Reference

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-25T19:34:58Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T19:36:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
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

# T-1471: Doc drift fix — add gpu subcommand to CLAUDE.md Quick Reference

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Add `gpu` to the rarely-used commands list in CLAUDE.md Quick Reference (line 830)
- [x] `fw doctor` reports zero CLAUDE.md doc drift warnings

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

# Doctor must not report doc drift on the gpu subcommand
cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -E "Doc drift.*gpu" >/dev/null && exit 1 || true
# CLAUDE.md mentions gpu in the rarely-used list
cd /opt/999-Agentic-Engineering-Framework && grep -q ", gpu)" CLAUDE.md

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

### 2026-04-25T19:34:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1471-doc-drift-fix--add-gpu-subcommand-to-cla.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-abe67c30
- **Timestamp:** 2026-06-02T14:57:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T19:36:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
