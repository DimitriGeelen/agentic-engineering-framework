---
id: T-481
name: "Fix install.sh update path — handle dirty state and macOS filemode"
description: >
  install.sh do_install() fails on update when ~/.agentic-framework has dirty files.
  Root causes: (1) git pull with no stash/reset — framework install dir is not user
  code, should always match origin. (2) macOS core.fileMode=true reports permission
  diffs as local changes. Fix: make update path robust.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [portability, bugfix, installer]
components: []
related_tasks: []
created: 2026-03-14T14:48:51Z
last_update: '2026-08-16T22:25:31Z'
date_finished: 2026-03-14T14:52:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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
  - ts: '2026-08-16T22:25:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-481: Fix install.sh update path — handle dirty state and macOS filemode

## Context

macOS field report: `curl ... | bash` installer fails on second run. `do_install()` does bare `git pull` which fails when `core.fileMode=true` (macOS default) reports permission diffs as local changes. The framework install dir (`~/.agentic-framework`) is not user code — it should always match origin. Related: T-480 (macOS compat), T-482 (install model inception).

## Acceptance Criteria

### Agent
- [x] `do_install()` update path resets to origin (not `git pull`)
- [x] `core.fileMode` set to false on fresh clones (macOS compat)
- [x] `core.fileMode` fixed on existing installs during update
- [x] Update shows old→new version (commit hash or tag)
- [x] install.sh passes `bash -n` syntax check

### Human
- [ ] [RUBBER-STAMP] Run installer twice on macOS — second run succeeds
  **Steps:**
  1. `rm -rf ~/.agentic-framework` (clean slate)
  2. `curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash`
  3. Run the same curl command again
  **Expected:** Second run shows "Existing installation found — updating..." and completes without error
  **If not:** Paste the error output

## Verification

bash -n install.sh
grep -q 'core.fileMode' install.sh
grep -q 'reset --hard' install.sh
! grep -q 'git.*pull' install.sh

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified — install path resets to origin (not pull), `core.fileMode` handled on fresh+existing installs, version delta surfaced, syntax clean. The `[RUBBER-STAMP]` Human AC is a deterministic two-curl-runs check on macOS — could honestly be an Agent AC if a macOS gate-host were available; per AC Classification it's RUBBER-STAMP because the framework's gate doesn't run on macOS.

**Evidence:**
- `do_install()` uses `git fetch + git reset --hard origin/master` (no pull)
- `git config core.fileMode false` on both fresh and update paths
- Update output shows old→new commit hash
- `bash -n install.sh` passes

## Updates

### 2026-03-14T14:48:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-481-fix-installsh-update-path--handle-dirty-.md
- **Context:** Initial task creation

### 2026-03-14T14:52:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-28e96992
- **Timestamp:** 2026-06-02T15:03:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
