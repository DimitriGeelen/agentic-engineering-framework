---
id: T-193
name: "Implement P-010 AC tagging — agent/human verification split"
description: >
  Build task from T-192 GO decision (G-010). Implement Option A: ### Agent / ### Human
  AC section headers in task templates. P-010 gate in update-task.sh scopes to ### Agent
  section only. Partial-complete behavior keeps task in active/ with owner: human when
  human ACs are unchecked. CLI command fw task verify. Web UI cockpit attention section.
  CLAUDE.md behavioral rule. Backward compatible with all 188+ existing tasks.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [gap, p-010, verification, g-010]
related_tasks: [T-192]
created: 2026-02-19T14:56:10Z
last_update: 2026-02-19T14:56:10Z
date_finished: null
---

# T-193: Implement P-010 AC tagging — agent/human verification split

## Context

Inception T-192 (GO). Origin: sprechloop G-006 / framework G-010.
Brief: `/opt/001-sprechloop/.context/briefs/G-006-behavior-verification-gap.md`
Decisions: T-192 task file in `.tasks/completed/`

## Acceptance Criteria

### Agent
- [ ] `update-task.sh` P-010 gate scopes to `### Agent` section when present
- [ ] Tasks without `### Agent` / `### Human` headers work as before (backward compat)
- [ ] Partial-complete: task stays in `active/` with `owner: human` when human ACs unchecked
- [ ] `work-completed` output reports human AC status: "Human: 0/N checked (not blocking)"
- [ ] `.tasks/templates/default.md` updated with `### Agent` / `### Human` sections
- [ ] `CLAUDE.md` updated with behavioral rule: never check a `### Human` AC
- [ ] `fw task verify` command lists tasks with unchecked human ACs
- [ ] Web UI cockpit shows "Awaiting Your Verification" attention section

### Human
- [ ] Create a test task with both AC sections, verify partial-complete behavior
- [ ] Verify `fw task verify` shows the right tasks
- [ ] Verify cockpit attention section renders correctly in browser

## Verification

# Backward compat: existing tasks without headers should pass P-010
grep -qE 'Agent|Human' .tasks/templates/default.md
# Template has both sections
grep -q '### Agent' .tasks/templates/default.md
grep -q '### Human' .tasks/templates/default.md
# CLAUDE.md has the behavioral rule
grep -q 'Human.*AC' CLAUDE.md

## Decisions

All decisions made in T-192 inception. See `.tasks/completed/T-192-*.md`

## Updates

### 2026-02-19T14:56:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
