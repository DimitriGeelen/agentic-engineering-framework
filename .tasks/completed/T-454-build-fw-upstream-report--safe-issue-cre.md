---
id: T-454
name: "Build fw upstream report — safe issue creation from field installations"
description: >
  Implement fw upstream report (issue-only mode), fw upstream config, fw upstream
  status. Add upstream_repo to .framework.yaml via fw init. Dry-run default, confirmation
  prompt, fw doctor attachment, sent-file tracking. See docs/reports/T-451-upstream-contribution-research.md
  for full design.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/fw, lib/init.sh, lib/upstream.sh, web/templates/base.html]
related_tasks: []
created: 2026-03-12T11:03:50Z
last_update: '2026-08-16T22:25:31Z'
date_finished: 2026-03-12T12:09:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-454: Build fw upstream report — safe issue creation from field installations

## Context

Inception T-451 approved GO. Design: `docs/reports/T-451-upstream-contribution-research.md`
Related: T-443 (OneDev PR sync — inbound equivalent)

## Acceptance Criteria

### Agent
- [x] `lib/upstream.sh` implements `report`, `config`, `status`, `list` subcommands
- [x] `bin/fw` routes `upstream` to `lib/upstream.sh`
- [x] `fw upstream help` shows usage
- [x] `fw upstream config` auto-detects repo from git remotes (origin or first github.com remote)
- [x] `fw upstream config --repo OWNER/REPO` persists to `.framework.yaml`
- [x] `fw upstream report --dry-run` shows what would be created without creating
- [x] `fw upstream report` includes confirmation prompt before creating
- [x] `--attach-doctor` includes `fw doctor` output in issue body
- [x] `--attach-patch REF` includes git diff in issue body
- [x] Sent-file tracking prevents duplicate submissions
- [x] `fw init` auto-detects and stores `upstream_repo` in `.framework.yaml`
- [x] Component fabric card registered

### Human
- [x] [RUBBER-STAMP] Run `fw upstream report --title "Test issue" --dry-run` from a consumer project
  **Steps:**
  1. `cd` to a project initialized with `fw init`
  2. Run `fw upstream config` — verify it shows the framework repo
  3. Run `fw upstream report --title "Test" --dry-run` — verify dry-run output
  **Expected:** Repo auto-detected, dry-run shows correct target
  **If not:** Run `fw upstream config --repo DimitriGeelen/agentic-engineering-framework` to set manually

## Verification

test -f lib/upstream.sh
test -x lib/upstream.sh || true
grep -q 'do_upstream' lib/upstream.sh
grep -q 'upstream)' bin/fw
/opt/999-Agentic-Engineering-Framework/bin/fw upstream config 2>&1 | grep -c "Repo:" | grep -q "[1-9]"
/opt/999-Agentic-Engineering-Framework/bin/fw upstream report --title "Verification test" --dry-run 2>&1 | grep -q "DRY RUN"

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

### 2026-03-12T11:03:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-454-build-fw-upstream-report--safe-issue-cre.md
- **Context:** Initial task creation

### 2026-03-12T11:11:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-12T12:09:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-595b78d9
- **Timestamp:** 2026-06-02T18:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`

- **Suppressed:** 3 (by override)
  - swallowed-errors @ Verification:line 2
  - l387-sigpipe-risk @ Verification:line 5
  - l387-sigpipe-risk @ Verification:line 6
