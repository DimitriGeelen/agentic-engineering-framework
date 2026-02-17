# /plan - Lightweight Implementation Plan

Create a concise implementation plan for the current task.
Use after exploration is done and direction is chosen, before starting to build.

## Prerequisites

1. Verify an active task exists (`cat .context/working/focus.yaml`)
2. Task should have a clear direction — if not, run `/explore` first

## Workflow

### Step 1: Assess Scope
Read the active task file. Count deliverables. If more than 3 independent deliverables, suggest decomposition before planning.

### Step 2: Write the Plan

Create `docs/plans/{date}-{task-slug}.md` with this structure:

```markdown
# Plan: {Task Name}

**Task:** T-XXX
**Goal:** One sentence.
**Approach:** One paragraph explaining the chosen approach and why.

## Tasks

1. **{What to build}** — {what to verify} — {files touched}
2. **{What to build}** — {what to verify} — {files touched}
...

## Technical Notes

- {Key decision or constraint, one line each}

## Open Questions

- {Anything unresolved, if any}
```

**Plan rules:**
- Target: **under 100 lines**. If longer, the plan is too detailed.
- One line per task. No step-by-step instructions — the agent doing the work decides HOW.
- No complete code in plans. Code belongs in implementation, not planning.
- No TDD ceremony per task. Testing is part of each task's verification, not a separate step.
- No embedded skill directives ("REQUIRED SUB-SKILL", etc.) — the plan is for humans and agents alike.

### Step 3: Present for Approval

Print a summary (task list + key decisions) in conversation.
Ask: "Plan written to {path}. Ready to start, or changes needed?"

**Wait for user approval before any implementation begins.**

## Rules

- This skill does ONE thing: plan. It does not start building.
- No skill chaining — do not invoke `/explore` or any other skill from within this skill.
- Plans are living documents — update them as work progresses, don't treat them as contracts.
- If the task is small enough to not need a plan (single file, obvious change), say so instead of writing one.
