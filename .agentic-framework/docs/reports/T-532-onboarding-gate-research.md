# T-532: Onboarding Gate Research

## Problem
`fw init` creates onboarding tasks but nothing enforces their completion before other work.

## Agent Research Findings (3 parallel agents, 2026-03-23)

### Agent 1: Current Init Flow
- `lib/init.sh:372-424` creates 5-6 seed tasks from `lib/seeds/tasks/{greenfield,existing-project}/`
- All created with `horizon: now`, T-001 gets `status: started-work`
- **No blocking mechanism** — task gate checks for *any* active task, not *which* task
- No `blockedBy`/`blocks` fields enforced structurally

### Agent 2: Enforcement Patterns Available
- **PreToolUse hook** (best pattern): check-active-task.sh already blocks Write/Edit without task context
- Could extend to check: "if onboarding tasks exist and are incomplete, block focus on non-onboarding tasks"
- Exempt paths pattern (`.context/*`, `.tasks/*`) already exists for framework operations
- Budget gate shows how to cache status for hot-path performance

### Agent 3: Consumer Project Evidence
- Bilderkarte project has onboarding tasks completed — but by agent discipline, not structural enforcement
- Handover "Suggested First Action" sorts by horizon+ID (T-001 first) — soft guidance only
- Onboarding test suite (`agents/onboarding-test/`) validates the flow but doesn't enforce ordering

## Design Options

### Option A: Tag-based gate in check-active-task.sh
- Add `tags: [onboarding]` to seed tasks
- check-active-task.sh checks: if any `tags: [onboarding]` tasks in `.tasks/active/` are not `work-completed`, block focus on non-onboarding tasks
- **Pro:** Minimal change, uses existing tag infrastructure
- **Con:** Tags are metadata, not a first-class concept

### Option B: Dedicated onboarding-gate.sh PreToolUse hook
- Separate hook, separate matcher (Write|Edit)
- Checks for `.tasks/active/T-*-onboarding*` or a `.context/working/.onboarding-complete` marker
- **Pro:** Clean separation, can be removed after onboarding
- **Con:** Another hook in the chain, latency concern

### Option C: horizon: immediate
- New horizon value that sorts before `now`
- Handover and task commands enforce: if any `immediate` tasks exist, block creation/focus of non-immediate tasks
- **Pro:** General-purpose, not onboarding-specific
- **Con:** Larger change surface, affects sorting, resume, handover

## Dialogue Log

- Human identified the gap: onboarding tasks exist but Claude skips them
- Human noted another project where it "worked perfectly" — this was behavioral, not structural
- Human wants structural enforcement, not stronger guidance
- Human suggested `horizon: immediate` or similar mechanism
