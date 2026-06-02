---
id: T-1163
name: "T-1109b: Invariant test — upgrade vendor completeness check"
description: >
  T-1109b: Invariant test — upgrade vendor completeness check

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T12:17:38Z
last_update: 2026-04-12T12:19:26Z
date_finished: 2026-04-12T12:19:26Z
---

# T-1163: T-1109b: Invariant test — upgrade vendor completeness check

## Context

Invariant test pair for T-1157 (collapse upgrade step 4b). Two tests: (1) upgrade-vendor-complete: lib/upgrade.sh uses do_vendor, not its own enumeration; (2) single-vendor-writer: lib/upgrade.sh must NOT contain its own web/blueprints enumeration. Per T-1105 chokepoint+invariant-test discipline.

## Acceptance Criteria

### Agent
- [x] `tests/lint/single-vendor-writer.bats` exists with structural guard tests
- [x] All bats tests pass

## Verification

bash -c 'test -f tests/lint/single-vendor-writer.bats'
bash -c 'cd /opt/999-Agentic-Engineering-Framework && bats tests/lint/single-vendor-writer.bats'

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

### 2026-04-12T12:17:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1163-t-1109b-invariant-test--upgrade-vendor-c.md
- **Context:** Initial task creation

### 2026-04-12T12:19:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c9e7fe99
- **Timestamp:** 2026-06-02T14:55:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
