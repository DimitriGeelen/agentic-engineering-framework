# T-993: Batch Operation Governance Research

## Problem

The agent proposed a batch horizon change for ~30 tasks without per-task justification or evidence. The user intervened ("HEY!!!! no batch move !!!!"). This represents a governance gap: the framework has no structural gate preventing agents from batch-modifying task metadata without justification.

## Prior Art

Previous attempts to control this:
- T-372/T-373: Human Task Completion Rule — prevents agent from completing human-owned tasks without evidence
- CLAUDE.md §Autonomous Mode Boundaries — lists what's "NOT delegated"
- CLAUDE.md §Human AC Format Requirements — requires evidence for task changes

But none of these specifically address **batch operations on task metadata** (horizon, tags, status across multiple tasks).

## Investigation

### What happened (T-992)
1. Agent observed 30+ tasks with `status: work-completed` and `horizon: now`
2. Agent proposed moving all to `horizon: next` as a batch
3. No per-task analysis was performed
4. User blocked it

### Root cause
No structural gate exists for batch task modifications. The agent can run `fw task update T-XXX --horizon next` in a loop without justification.

### Existing controls
1. **Sovereignty gate** — blocks agent from completing human-owned tasks (status change)
2. **Tier 0** — blocks destructive commands
3. **Task gate** — requires active task for file edits
4. **CLAUDE.md rules** — advisory, not enforced structurally

### Gap
Horizon changes are NOT covered by:
- Sovereignty gate (only blocks status → work-completed)
- Tier 0 (not classified as destructive)
- Task gate (task metadata changes don't trigger Write/Edit hooks)

## Options

### Option A: PreToolUse hook on Bash for `fw task update --horizon`
- Detect `fw task update .* --horizon` in bash commands
- Require a justification flag: `--reason "..."` for horizon changes
- Log all horizon changes to audit trail
- **Pro:** Structural enforcement, can't bypass
- **Con:** Text matching on bash commands (R-037 false positive risk)

### Option B: CLAUDE.md rule + learning
- Add explicit rule: "Never batch-modify task horizons. Each horizon change requires per-task evidence."
- Record as learning L-XXX
- **Pro:** Simple, immediate
- **Con:** Advisory only, agent can still batch-move

### Option C: `fw task update` gate — require `--reason` for horizon changes
- Modify `update-task.sh` to require `--reason` when changing horizon
- Log the reason in task Updates section
- **Pro:** Enforced at the fw CLI level, visible in task file
- **Con:** Adds friction to legitimate single-task horizon changes

### Option D: Batch detection hook
- Count how many `fw task update --horizon` calls happen in a session
- After N (e.g., 3) horizon changes, require human confirmation
- **Pro:** Allows individual changes but blocks mass operations
- **Con:** Complex, stateful, needs counter file

## Findings

1. The existing `check-active-task.sh` hook only fires on Write/Edit/Bash, not on fw CLI subcommands
2. `fw task update` runs via Bash tool, so Bash hooks CAN intercept it
3. The `check-tier0.sh` already pattern-matches bash commands — same mechanism could work for batch detection
4. Option C (--reason flag in update-task.sh) is the cleanest because it's enforcement at the point of action, not text matching
5. Option B (CLAUDE.md rule) should be done regardless as a complement
