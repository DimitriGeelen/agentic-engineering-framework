# T-1178: Structural Bugfix-Learning Enforcement (G-016)

## Problem

0% of 145 bugfix tasks have captured learnings (`fw audit` reports `Bugfix-learning coverage: 0% (0/145)`). G-016 has been watching since 2026-02-22. Decision trigger: ratio stays below 35%.

## Current State

### What Exists
1. **`fw fix-learned T-XXX "text"`** — CLI command that wraps `fw context add-learning` with task reference. Created by T-329.
2. **`update-task.sh` learning prompt** — On task completion, if the task looks like a bugfix (workflow_type: build/refactor AND commit messages suggest a fix), prints:
   ```
   LEARNING PROMPT — This looks like a bugfix task
   No learning entry references T-XXX.
   Consider: fw context add-learning "what was learned" --task T-XXX
   ```
3. **Audit check** — `agents/audit/audit.sh` has a `Bugfix-learning coverage` check (WARN level).

### Why It Doesn't Work
- The learning prompt is **non-blocking** — agents skip it under context pressure
- The prompt is **generic** — doesn't help the agent decide what to capture
- `fw fix-learned` requires a **manual invocation** after task completion — context has already moved on
- The audit check is **WARN only** — visible in reports but not actionable in the moment

## Options Evaluated

### Option A: Blocking gate (REJECTED)
Block task completion if no learning captured for bugfix tasks. Too disruptive — most bugfixes are routine and the learning is "nothing new". Would create `--force` fatigue.

### Option B: Enhanced prompt (RECOMMENDED)
Replace the generic prompt with:
1. Pre-filled `fw fix-learned T-XXX "..."` command
2. Guidance questions: "What class of bug was this? Would a future agent benefit?"
3. Visual prominence (colored bordered box, not plain text)

### Option C: Audit escalation (RECOMMENDED, additive)
Escalate from WARN to FAIL when ratio drops below 10%. Makes it visible in `fw doctor` and pre-push audit. Combined with Option B.

### Option D: Post-completion hook (CONSIDERED)
Add a PostToolUse hook that detects `fw task update --status work-completed` for bugfix tasks and injects a learning prompt. Too complex — crossing tool boundaries.

## Recommendation

GO — implement Options B + C:
1. Enhance the learning prompt in `update-task.sh` (visual, pre-filled command, guidance questions)
2. Escalate audit check to FAIL below 10%

Bounded: ~50 lines in update-task.sh, ~10 lines in audit.sh. No new files.
