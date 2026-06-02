---
id: T-1113
name: "Placeholder audit chokepoint: _audit_placeholders + wire fw inception decide + fw task review + bats invariant tests (T-1111 build)"
description: >
  Placeholder audit chokepoint: _audit_placeholders + wire fw inception decide + fw task review + bats invariant tests (T-1111 build)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/inception.sh, lib/task-audit.sh, tests/integration/audit_blocks_review_and_decide.bats, tests/unit/lib_task_audit.bats]
related_tasks: []
created: 2026-04-11T21:53:34Z
last_update: 2026-04-11T22:13:19Z
date_finished: 2026-04-11T22:13:19Z
---

# T-1113: Placeholder audit chokepoint: _audit_placeholders + wire fw inception decide + fw task review + bats invariant tests (T-1111 build)

## Context

Build task implementing T-1111 GO decision (inception RCA captured in
`docs/reports/T-1111-placeholder-sections-rca.md`). Adds a chokepoint that
blocks `fw task review` and `fw inception decide` when task files still
contain unfilled template boilerplate (the literal bracket-Criterion-digit-
bracket, bracket-TODO-bracket, bracket-PLACEHOLDER-bracket, and
bracket-REQUIRED-before patterns). Closes G-018 silent quality decay.

## Acceptance Criteria

### Agent
- [x] `lib/task-audit.sh` exists with `audit_task_placeholders()` that returns
      non-zero when a task file contains literal template placeholder patterns
      in non-exempt sections (exempts `## Updates`, `## Dialogue Log`, fenced
      code blocks).
- [x] `bin/fw task review` sources `lib/task-audit.sh` and calls the audit
      BEFORE `emit_review` — a task file with placeholders fails with
      non-zero exit and no review marker is created.
- [x] `lib/inception.sh:do_inception_decide` calls the audit BEFORE the
      review-marker and recommendation checks — a task file with
      placeholders blocks the decide command even if a marker exists.
- [x] Unit test `tests/unit/lib_task_audit.bats` passes: exercises the helper
      on clean, placeholder-containing, and edge-case (Updates-section,
      fenced-code, multi-pattern) fixtures.
- [x] Integration test `tests/integration/audit_blocks_review_and_decide.bats`
      passes: creates a task with a literal Criterion-N bracket stub in
      Go/No-Go, runs `fw task review` and `fw inception decide`, asserts
      both are blocked with non-zero exit and no review marker created.
- [x] `bin/fw test unit tests/unit/lib_task_audit.bats` green.
- [x] `bin/fw test integration tests/integration/audit_blocks_review_and_decide.bats` green.
- [x] `.context/project/concerns.yaml`: G-018 marked resolved_by: T-1113.

## Verification

bash -c "source lib/task-audit.sh && type audit_task_placeholders >/dev/null"
grep -q 'source.*task-audit.sh' bin/fw
grep -q 'audit_task_placeholders' lib/inception.sh
test -f tests/unit/lib_task_audit.bats
test -f tests/integration/audit_blocks_review_and_decide.bats
bats tests/unit/lib_task_audit.bats
bats tests/integration/audit_blocks_review_and_decide.bats

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

### 2026-04-11T21:53:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1113-placeholder-audit-chokepoint-auditplaceh.md
- **Context:** Initial task creation

### 2026-04-11T22:13:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c26b8771
- **Timestamp:** 2026-06-02T14:55:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#8 (Agent)** — `.context/project/concerns.yaml`: G-018 marked resolved_by: T-1113.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/concerns.yaml in: `.context/project/concerns.yaml`: G-018 marked resolved_by: T-1113.`
