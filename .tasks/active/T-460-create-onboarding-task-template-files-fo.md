---
id: T-460
name: "Create onboarding task template files for both init modes"
description: >
  Create lib/seeds/tasks/existing-project/ and lib/seeds/tasks/greenfield/ directories with full markdown task files (frontmatter + ACs + verification). Existing-project: 6-7 tasks (orientation, fw doctor, audit baseline, first governed commit, complete task cycle, generate handover, ingest codebase). Greenfield: 6 tasks (orientation, outline tasks, create structure, set up tooling, complete cycle, generate handover). Templates use __PROJECT_NAME__ placeholder. Deterministic, reviewable, maintainable.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [init, onboarding, templates]
components: []
related_tasks: []
created: 2026-03-12T17:00:54Z
last_update: 2026-03-13T10:06:19Z
date_finished: 2026-03-13T10:06:19Z
---

# T-460: Create onboarding task template files for both init modes

## Context

Create template onboarding tasks for `fw init`. Two modes: existing-project (has code) and greenfield (no code). Templates use `__PROJECT_NAME__` and `__DATE__` placeholders. Init copies them into `.tasks/active/` with substitution.

## Acceptance Criteria

### Agent
- [x] `lib/seeds/tasks/existing-project/` directory exists with 6+ task template files
- [x] `lib/seeds/tasks/greenfield/` directory exists with 5+ task template files
- [x] All template files have valid YAML frontmatter (id, name, status, workflow_type, owner)
- [x] All template files use `__PROJECT_NAME__` placeholder (not hardcoded project names)
- [x] init.sh copies appropriate template set into `.tasks/active/` based on code detection
- [x] init.sh performs `__PROJECT_NAME__` and `__DATE__` substitution when copying

### Human
- [ ] [REVIEW] Onboarding task content is useful for new framework users
  **Steps:**
  1. Read `lib/seeds/tasks/existing-project/` task files
  2. Assess whether tasks guide a new user through framework adoption
  **Expected:** Tasks progressively introduce framework concepts — orientation, health check, first commit, task lifecycle, handover
  **If not:** Note which tasks are missing or have unclear instructions

## Verification

# Template directories exist
test -d lib/seeds/tasks/existing-project
test -d lib/seeds/tasks/greenfield
# Existing-project has at least 6 templates
test "$(ls lib/seeds/tasks/existing-project/T-*.md 2>/dev/null | wc -l)" -ge "6"
# Greenfield has at least 5 templates
test "$(ls lib/seeds/tasks/greenfield/T-*.md 2>/dev/null | wc -l)" -ge "5"
# All templates have valid frontmatter
python3 -c "import yaml, glob; [yaml.safe_load(open(f).read().split('---')[1]) for f in glob.glob('lib/seeds/tasks/**/*.md', recursive=True)]"
# All templates use __PROJECT_NAME__ placeholder
test "$(grep -rl '__PROJECT_NAME__' lib/seeds/tasks/ | wc -l)" -ge "5"
# init.sh has template copying logic
grep -q 'seeds/tasks' lib/init.sh

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

### 2026-03-12T17:00:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-460-create-onboarding-task-template-files-fo.md
- **Context:** Initial task creation

### 2026-03-13T10:03:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T10:06:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
