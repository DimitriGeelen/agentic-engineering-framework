---
id: T-333
name: "Create CONTRIBUTING.md and tag good first issues"
description: >
  Write CONTRIBUTING.md with: setup instructions, PR process, code style, architecture overview (500 words). Tag 5-10 existing issues/tasks as good-first-issue. Create issue templates (bug report, feature request). Ref: docs/reports/T-327-visibility-strategy.md

status: started-work
workflow_type: build
owner: claude
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:44Z
last_update: 2026-03-05T01:22:04Z
date_finished: null
---

# T-333: Create CONTRIBUTING.md and tag good first issues

## Context

Contributor onboarding for external visibility (T-327 GO). Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [ ] CONTRIBUTING.md exists with setup instructions, PR process, architecture overview
- [ ] Bug report issue template created (.github/ISSUE_TEMPLATE/)
- [ ] Feature request issue template created
- [ ] GitHub issues created for good first issues (5+)

### Human
- [ ] CONTRIBUTING.md reads well for a first-time contributor

## Verification

test -f CONTRIBUTING.md
test -f .github/ISSUE_TEMPLATE/bug-report.yml
test -f .github/ISSUE_TEMPLATE/feature-request.yml
grep -q "Getting Started" CONTRIBUTING.md
grep -q "Pull Request" CONTRIBUTING.md

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

### 2026-03-05T01:12:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-333-create-contributingmd-and-tag-good-first.md
- **Context:** Initial task creation

### 2026-03-05T01:22:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
