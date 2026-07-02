---
id: T-1340
name: "G-047 mitigation: record source_task_id_in_origin on pickup-created inception
  tasks"
description: >
  G-047 mitigation: record source_task_id_in_origin on pickup-created inception tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T16:56:09Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T17:40:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1340: G-047 mitigation: record source_task_id_in_origin on pickup-created inception tasks

## Context

G-047 mitigation. When pickup pipeline creates an inception from an envelope, the origin project's task_id is only captured in the `--description` prose (unstructured). This makes it impossible to query "what originated from source T-X?" and hides T-ID renumbering conflicts. Fix: after `fw task create` returns, parse the new task ID from its output and inject structured frontmatter fields (`source_task_id_in_origin:` and `source_project_in_origin:`) into the created task file.

## Acceptance Criteria

### Agent
- [x] `pickup_create_inception` in `lib/pickup.sh` captures `fw task create` output and extracts the new T-XXX ID
- [x] After creation, appends structured fields to task frontmatter: `source_task_id_in_origin: T-XXX` and `source_project_in_origin: <name>` (only when source_task is non-empty)
- [x] Unit test (bats) — feed a fake envelope with source_task, run pickup_create_inception, assert created task has both frontmatter fields
- [x] `bash -n lib/pickup.sh` passes
- [x] Regression: envelope without source_task still creates task successfully (no frontmatter injection)

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

bash -n lib/pickup.sh
bats tests/unit/pickup_origin_frontmatter.bats

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

### 2026-04-19T16:56:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1340-g-047-mitigation-record-sourcetaskidinor.md
- **Context:** Initial task creation

### 2026-04-19T17:40:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca72ad4a
- **Timestamp:** 2026-06-02T14:56:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
