---
id: T-1079
name: "Fix hook VERSION drift — git.sh shows 1.4 but templates write 1.5 causing install
  mismatches"
description: >
  Fix hook VERSION drift — git.sh shows 1.4 but templates write 1.5 causing install
  mismatches

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-11T08:27:45Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T08:29:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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

# T-1079: Fix hook VERSION drift — git.sh shows 1.4 but templates write 1.5 causing install mismatches

## Context

`agents/git/git.sh` has `VERSION="1.4"` but commit-msg and post-commit templates in `agents/git/lib/hooks.sh` write `# VERSION=1.5`. Pre-push template is at VERSION=1.0 and was modified in T-1078 without a bump. Install-hooks compares commit-msg VERSION against `$VERSION`, so consumer projects with the old 1.4 hook never auto-update on `fw upgrade`. Discovered during T-1078 propagation when 001-sprechloop refused reinstall without `--force`.

## Acceptance Criteria

### Agent
- [x] `git.sh` VERSION matches commit-msg template VERSION
- [x] Pre-push template VERSION bumped to reflect T-1078 change
- [x] Comment explains: bump template VERSION when editing any hook in `agents/git/lib/hooks.sh`

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
# Lines starting with # are comments (skipped). Empty lines ignored.
grep -q '^VERSION="1.5"' agents/git/git.sh
grep -q '# VERSION=1.1' agents/git/lib/hooks.sh

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

### 2026-04-11T08:27:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1079-fix-hook-version-drift--gitsh-shows-14-b.md
- **Context:** Initial task creation

### 2026-04-11T08:29:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0990bdf8
- **Timestamp:** 2026-06-02T14:55:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
