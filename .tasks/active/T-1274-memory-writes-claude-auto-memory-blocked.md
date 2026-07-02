---
id: T-1274
name: "Memory writes (claude auto-memory) blocked by onboarding task gate — agent
  on consumer project couldn't save memory about wrong fw path because T-001-T-005
  weren't complete. Memory is the exact mechanism that would prevent recurrence of
  the problem being observed. Memory should not be gated by task onboarding."
description: >
  Promoted from observation OBS-013

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-16T05:29:24Z
last_update: '2026-07-02T16:15:02Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T16:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1274: Memory writes (claude auto-memory) blocked by onboarding task gate — agent on consumer project couldn't save memory about wrong fw path because T-001-T-005 weren't complete. Memory is the exact mechanism that would prevent recurrence of the problem being observed. Memory should not be gated by task onboarding.

## Context

Observation: on a consumer project mid-onboarding (T-001–T-005 not complete, no focus set), Claude auto-memory writes to `/root/.claude/projects/<project>/memory/*.md` were blocked by `check-active-task.sh` because memory paths live outside PROJECT_ROOT and the exempt list is PROJECT_ROOT-anchored.

### Proposed fix (T-1431, 2026-04-24)

T-1431 added a global exempt case for `*/.claude/projects/*/memory/*` in `agents/context/check-active-task.sh` — the pattern matches any user prefix (`/root/`, `/home/alice/`, etc.) and only the auto-memory directory, nothing else under `.claude/`. Six bats regression tests in `tests/unit/check_active_task_memory_exempt.bats` cover:

- memory writes allowed without task (root + non-root user)
- MEMORY.md at root of memory/ allowed
- non-memory writes under /root/.claude/ still blocked
- arbitrary outside-project writes still blocked
- project-root .context/ still allowed

T-1431 is a proposal — this task (T-1274) remains human-owned. Review the fix and decide whether it resolves the observation.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-active-task.sh` exempts `*/.claude/projects/*/memory/*` paths — verified at line 123-129 (T-1431 fix)
- [x] Exemption matches any user prefix (`/root/`, `/home/<user>/`) and only the auto-memory directory, not arbitrary `.claude/` paths
- [x] Bats regression coverage exists at `tests/unit/check_active_task_memory_exempt.bats` (6 tests)
- [x] Regression tests pass: 6/6 in `bin/fw test unit -- tests/unit/check_active_task_memory_exempt.bats`
- [x] Negative cases still blocked: non-memory `.claude/` writes blocked, arbitrary outside-project writes blocked

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

# T-1431 fix landed — verify exempt clause exists
grep -q "/.claude/projects/.*/memory/" agents/context/check-active-task.sh
# Regression tests pass
bin/fw test unit -- tests/unit/check_active_task_memory_exempt.bats >/tmp/T-1274-bats.log 2>&1
! grep -qE "^not ok" /tmp/T-1274-bats.log

## Recommendation

**Recommendation:** GO

**Rationale:** Observation OBS-013 is already resolved by T-1431 (work-completed 2026-04-24, agent-owned). The exempt clause at `agents/context/check-active-task.sh:123-129` matches the pattern proposed in this task's body. All 6 bats regression tests pass; negative cases (non-memory `.claude/` writes, outside-project writes) remain blocked. No further work needed.

**Evidence:**
- `agents/context/check-active-task.sh:123-129` — `*/.claude/projects/*/memory/*)` exempt branch
- `tests/unit/check_active_task_memory_exempt.bats` — 6/6 pass (auto-memory allowed for /root, /home/alice, MEMORY.md at root; non-memory blocks; outside-project blocks; project-root .context still allowed)
- T-1431 in `.tasks/completed/` — `status: work-completed` with `date_finished: 2026-04-24T15:40:06Z`
- Drift class: captured-but-done (same pattern as T-334/T-464/T-544/T-967 sweep)

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

### 2026-04-16T05:29:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1274-memory-writes-claude-auto-memory-blocked.md
- **Context:** Initial task creation

### 2026-04-28T18:51:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
