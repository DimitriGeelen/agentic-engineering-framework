# /new-project - Initialize New Project

Guided onboarding for setting up a new project with the Agentic Engineering Framework.

## Step 1: Gather Info

Ask the user (using AskUserQuestion with two questions):

1. **Project path** — "What is the path to your project directory?"
   - Options: "Current directory", "Enter path"
2. **AI provider** — "Which AI provider will you use?"
   - Options: "Claude (Recommended)", "Cursor", "Generic (any provider)"

Map provider answers: "Claude" → `claude`, "Cursor" → `cursor`, "Generic" → `generic`.

## Step 2: Verify Prerequisites

Run in parallel:
1. `fw doctor` — check framework health
2. `ls {project_path}` — verify path exists (create with `mkdir -p` if not)
3. Check if path already has `.framework.yaml` — warn if re-initializing

If `fw doctor` shows failures, stop and help fix them first.

## Step 3: Initialize Git (if needed)

Check if the project directory has a git repo:
```bash
git -C {project_path} rev-parse --git-dir 2>/dev/null
```

If not, initialize:
```bash
git init {project_path}
```

## Step 4: Run fw init

```bash
fw init {project_path} --provider {provider}
```

Report what was created. If init fails, diagnose and fix.

## Step 5: Verify Setup

```bash
cd {project_path}
fw doctor
```

Report results. All checks should pass. Fix any failures before proceeding.

## Step 6: Start First Session

```bash
cd {project_path}
fw context init
```

## Step 7: Create First Task

Ask the user: "What's the first thing you want to work on?"

Then run:
```bash
cd {project_path}
fw work-on "{user_description}" --type build
```

Print confirmation:
```
Project initialized and ready!
- Path: {project_path}
- Provider: {provider}
- First task: T-XXX ({task_name})

You're all set. Start coding!
```

## Rules

- This skill is for NEW projects only. For existing projects, use `fw work-on`.
- Always create a git repo before running `fw init` (it requires git hooks).
- If the directory doesn't exist, create it with `mkdir -p`.
- If re-initializing an existing project, warn the user and require confirmation.
- Run `fw doctor` both before (framework check) and after (project check) init.
- The skill ends by creating the first task — the user should be ready to work immediately.
