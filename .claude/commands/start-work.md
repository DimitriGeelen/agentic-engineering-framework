# /start-work - Task-First Gate for Agentic Engineering Framework

Before beginning ANY implementation work, execute this workflow.
This command enforces the core principle: "Nothing gets done without a task."

## When To Use

ALWAYS use before:
- Implementing a feature, bugfix, or refactor
- Following a plan
- Executing any skill that produces code changes (brainstorming → implementation, TDD, feature-dev, etc.)

## Step 1: Check Context

Run in parallel:
1. `cat .context/working/focus.yaml` — check if `current_task` is set
2. `ls .tasks/active/` — list active tasks

If `current_task` is already set and valid: skip to Step 3.

## Step 2: Create or Resume Task

If no active task for this work:

**New work:**
```bash
fw work-on "DESCRIPTION" --type TYPE
```

**Resuming known task:**
```bash
fw work-on T-XXX
```

TYPE is one of: build, specification, design, test, refactor, decommission

Do NOT proceed to implementation until this step completes successfully.

## Step 3: Confirm Gate

Verify:
- `current_task` in focus.yaml is set
- Task file exists in `.tasks/active/`
- Task status is `started-work`

Print confirmation:
```
Task gate passed: T-XXX ({task_name})
Proceeding with implementation.
```

## Step 4: Proceed

Now invoke whatever skills or workflows are needed (brainstorming, TDD, plans, etc.).

## Rules

- This gate takes precedence over ALL plugin skills
- "Invoke skills BEFORE any response" means: after this gate passes
- If a skill says "implement now" — this gate comes first
- The PreToolUse hook will block Write/Edit without an active task anyway
- This command exists to make the agent aware BEFORE hitting the hook
