---
id: T-857
name: "fw upgrade sync gap — lib/, agents/task-create/, agents/handover/, agents/git/
  not vendored to consumer projects"
description: >
  fw upgrade syncs lib/*.sh to global ~/.agentic-framework but NOT to consumer vendored
  .agentic-framework/lib/. Same gap for agents/task-create/, agents/handover/, agents/git/,
  agents/healing/, agents/fabric/, agents/dispatch/. Root cause of 3021-Bilderkarte
  T-504 sovereignty gate failure — consumer had pre-T-637 inception.sh. Evidence:
  upgrade.sh lines 322-365 (vendored sync) only covers agents/context/ and bin/fw.
  Lines 415-478 (global sync) covers lib/*.sh but not vendored. Related: G-023 (consumer
  governance decay). Fix: add lib/*.sh and agent script sync to vendored dir section
  of upgrade.sh.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-04T19:00:27Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-04T21:59:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-857: fw upgrade sync gap — lib/, agents/task-create/, agents/handover/, agents/git/ not vendored to consumer projects

## Context

RCA from 3021-Bilderkarte-tool-llm agent session: `fw inception decide T-504 go` hit sovereignty gate because consumer's vendored `lib/inception.sh` lacked the T-637 `--force` fix. Root cause: `upgrade.sh` vendored sync (lines 322-365) only covers `agents/context/` and `bin/fw`. The global sync (lines 415-478) covers `lib/*.sh` but the vendored consumer sync does not. Related: G-023 (consumer governance decay).

**What's missing from vendored sync:**
- `lib/*.sh` (inception.sh, upgrade.sh, harvest.sh, init.sh, etc.)
- `agents/task-create/*.sh` (update-task.sh, create-task.sh)
- `agents/handover/handover.sh`
- `agents/git/git.sh`
- `agents/healing/healing.sh`
- `agents/fabric/fabric.sh`
- `agents/dispatch/preamble.md`
- `agents/resume/resume.sh`

## Acceptance Criteria

### Agent
- [x] `upgrade.sh` vendored sync section syncs `lib/*.sh` to consumer `.agentic-framework/lib/`
- [x] `upgrade.sh` vendored sync section syncs agent scripts (task-create, handover, git, healing, fabric, dispatch, resume) to consumer `.agentic-framework/agents/`
- [x] `upgrade.sh --dry-run` reports the new sync targets without modifying files (verified: 40 vendored scripts detected)
- [x] Existing vendored sync (agents/context/, bin/fw) still works
- [x] Run upgrade on a consumer project and verify lib/inception.sh is current (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

# lib/*.sh synced to vendored dir
grep -q 'lib/\*.sh' lib/upgrade.sh
# agents/task-create synced
grep -q 'task-create' lib/upgrade.sh
# agents/handover synced
grep -q 'handover.*git.*healing' lib/upgrade.sh
test -f lib/inception.sh

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

### 2026-04-04T19:00:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-857-fw-upgrade-sync-gap--lib-agentstask-crea.md
- **Context:** Initial task creation

### 2026-04-04T21:59:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5bfa689
- **Timestamp:** 2026-06-02T15:05:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
