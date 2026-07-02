---
id: T-797
name: "Shellcheck cleanup: audit.sh and remaining framework scripts"
description: >
  Shellcheck cleanup: audit.sh and remaining framework scripts

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [C-004, agents/audit/plugin-audit.sh, agents/audit/self-audit.sh, 
      C-007, agents/context/check-agent-dispatch.sh, C-008, 
      agents/handover/handover.sh, agents/resume/resume.sh, 
      agents/task-create/update-task.sh, bin/fw, lib/bus.sh, lib/errors.sh, 
      lib/harvest.sh, lib/init.sh, lib/keylock.sh, lib/review.sh, lib/update.sh, 
      lib/upgrade.sh, lib/upstream.sh, lib/validate-init.sh, lib/version.sh]
related_tasks: []
created: 2026-03-30T17:52:22Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T18:54:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 2
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-797: Shellcheck cleanup: audit.sh and remaining framework scripts

## Context

Continuation of T-794/T-795/T-796 shellcheck cleanup. Scope expanded beyond audit.sh to all core framework scripts. Fixed 22 files total, reducing warnings from 100+ to 38 (remaining 38 are in 4 peripheral agents).

## Acceptance Criteria

### Agent
- [x] audit.sh shellcheck warnings reduced (31→0 excluding SC1091)
- [x] lib/errors.sh shellcheck warnings reduced (1→0 excluding SC1091)
- [x] All existing bats tests still pass (464/464)
- [x] audit.sh runs without errors
- [x] All core framework scripts clean: bin/fw (11→0), lib/*.sh (all→0), agents/context/*.sh (all→0), agents/audit/*.sh (all→0), agents/handover/*.sh (all→0), agents/resume/*.sh (all→0), agents/task-create/*.sh (all→0)

## Verification

test "$(shellcheck agents/audit/audit.sh 2>&1 | grep -v SC1091 | grep -c 'SC[0-9]' || true)" -eq 0
test "$(shellcheck bin/fw 2>&1 | grep -v SC1091 | grep -c 'SC[0-9]' || true)" -eq 0
bash -n bin/fw

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

### 2026-03-30T17:52:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-797-shellcheck-cleanup-auditsh-and-remaining.md
- **Context:** Initial task creation

### 2026-03-30T18:54:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2cb0937c
- **Timestamp:** 2026-06-02T15:04:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — lib/errors.sh shellcheck warnings reduced (1→0 excluding SC1091)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/errors.sh in: lib/errors.sh shellcheck warnings reduced (1→0 excluding SC1091)`
