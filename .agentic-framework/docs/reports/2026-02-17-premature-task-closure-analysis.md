---
title: "Premature Task Closure: Forensic Analysis and Mitigations"
date: 2026-02-17
task: T-112
trigger: "User noticed T-108 in completed/ despite expecting open work"
type: governance-analysis
---

# Premature Task Closure: Forensic Analysis and Mitigations

## Summary

Forensic investigation of T-108 revealed that the task was marked `work-completed` at 11:22 but 6 commits carrying the T-108 tag were made over the following 173 minutes. This exposed 5 governance violations and a structural gap: `work-completed` is an unvalidated flag with no pre-closure gate and no post-closure guardrails.

## Evidence

### Timeline

| Time | Commit | Event | Task Status |
|------|--------|-------|-------------|
| 10:12 | — | T-108 created | captured |
| 11:22 | — | `fw task update --status work-completed` | **closed** |
| 11:23 | 9377b42 | Fix 3 onboarding bugs | closed |
| 11:49 | a8e5a11 | Research doc (agent communication bus) | closed |
| 12:24 | b253cf1 | Episodic + move to completed/ | closed |
| 12:25 | 4c889dc | Learning: context budget rule | closed |
| 12:33 | cf4b5bc | CLAUDE.md rules, T-109 decomp, spawn T-110/T-111 | closed |
| 14:12 | f0d5dc8 | Fix commit.sh "updated" message | closed |

### Governance Violations

1. **Premature closure** — Status set before delivery commits
2. **Empty Updates log** — Only 2 entries: "created" and "work-completed"
3. **Post-closure commits** — 3 substantive commits after closure, no warning
4. **Stale episodic** — Claims 2 commits/69min; reality 6 commits/173min
5. **Orphaned decisions** — T-109 decomposition, T-110/T-111 creation, Work Proposal Rule all decided post-closure with no task home

## Root Causes

| Root Cause | Current State |
|------------|---------------|
| No acceptance criteria validation before `work-completed` | `update-task.sh` changes status unconditionally |
| commit-msg hook doesn't check task status | Allows commits against completed tasks silently |
| Episodic snapshot is one-time | No mechanism to refresh on post-closure activity |
| Task Updates log relies on agent discipline | No enforcement hook |
| `work-completed` is a flag, not a gate | No pre-transition checks |

## Risk Assessment

**Autonomous mode amplification:** Without a human observer, an agent can:
1. Mark a task complete prematurely
2. Continue working under the closed task ID
3. Hit context exhaustion
4. Lose all post-closure work (uncommitted or poorly traced)
5. Next session trusts the stale episodic and moves on
6. Work is silently lost

This is the highest-severity governance gap identified to date for autonomous agent operations.

## Proposed Mitigations

### M-1: Acceptance Criteria Gate (High Priority)

**Change:** Task template includes `## Acceptance Criteria` with checkboxes. `update-task.sh` refuses `work-completed` unless all criteria checked (or `--force` bypass with logging).

**Files:** `.tasks/templates/default.md`, `agents/task-create/update-task.sh`

**Prevents:** Premature closure

### M-2: Closed Task Commit Warning (High Priority)

**Change:** `commit-msg` hook checks if referenced task ID is in `completed/`. If so, prints warning: "Task T-XXX is closed. Create a new task or reopen."

**Files:** `agents/git/hooks/commit-msg`

**Prevents:** Silent post-closure work accumulation

### M-3: Episodic Refresh (Medium Priority)

**Change:** When post-commit hook detects a commit referencing a completed task, append to its episodic YAML under `post_closure_commits:` section.

**Files:** `agents/git/hooks/post-commit`, episodic generation logic

**Prevents:** Stale episodic metrics

### M-4: Update Log Convention (Low Priority)

**Change:** Document rule in CLAUDE.md: "Every commit should have a corresponding Updates entry." Auditable but not hook-enforced (false positive cost too high).

**Prevents:** Empty task histories

## Escalation Classification

**Level D** — Ways of working change. Not a technique failure (agent worked correctly), not a tooling failure (tools did what they were told). The process itself has a gap.

## References

- Learning: L-034
- Pattern: FP-006 (Premature task closure with post-closure drift)
- Decision: D-022
- Error Escalation Ladder: CLAUDE.md section "Error Escalation Ladder"
