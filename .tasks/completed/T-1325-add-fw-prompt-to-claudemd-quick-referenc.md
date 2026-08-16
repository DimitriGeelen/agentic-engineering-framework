---
id: T-1325
name: "Add fw prompt to CLAUDE.md Quick Reference (doc drift fix)"
description: >
  fw doctor flagged: 'fw prompt' subcommand missing from CLAUDE.md Quick Reference
  table. One-line addition under Vendor framework row. Cites the prompt register (create/list/show/copy/edit/delete/backfill-qid).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-18T23:20:40Z
last_update: '2026-08-16T22:24:29Z'
date_finished: 2026-04-18T23:22:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1325: Add fw prompt to CLAUDE.md Quick Reference (doc drift fix)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] CLAUDE.md Quick Reference contains a row for `fw prompt`
- [x] `fw doctor` no longer warns "Doc drift: 1 fw subcommand(s) missing from CLAUDE.md Quick Reference"

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

grep -q '^| Prompt register | `fw prompt list`' CLAUDE.md

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

### 2026-04-18T23:20:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1325-add-fw-prompt-to-claudemd-quick-referenc.md
- **Context:** Initial task creation

### 2026-04-18T23:22:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** One-line addition; doctor warning gone

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cc074a0f
- **Timestamp:** 2026-06-02T14:56:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
