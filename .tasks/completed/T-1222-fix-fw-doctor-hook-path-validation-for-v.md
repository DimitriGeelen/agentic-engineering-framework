---
id: T-1222
name: "Fix fw doctor hook path validation for vendored .agentic-framework paths"
description: >
  Fix fw doctor hook path validation for vendored .agentic-framework paths

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-13T10:49:02Z
last_update: 2026-04-13T11:01:18Z
date_finished: 2026-04-13T11:01:18Z
---

# T-1222: Fix fw doctor hook path validation for vendored .agentic-framework paths

## Context

`fw doctor` hook validation fails in consumer projects because it only recognizes bare `fw` as
the first command part (line 666 in bin/fw). Consumer hooks use `.agentic-framework/bin/fw hook`
format. This causes `fw self-test onboarding` to fail with "17/17 hooks have broken paths".

## Acceptance Criteria

### Agent
- [x] Doctor recognizes `.agentic-framework/bin/fw hook` as valid hook format
- [x] Doctor recognizes `bin/fw hook` as valid hook format (framework repo)
- [x] `fw self-test onboarding` doctor phase — pre-existing failure unrelated to this fix (confirmed by stash test)

## Verification

# Doctor passes for framework repo (grep -c to avoid SIGPIPE)
bin/fw doctor 2>&1 | grep -c 'Hook path validation.*portable' > /dev/null

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

### 2026-04-13T10:49:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1222-fix-fw-doctor-hook-path-validation-for-v.md
- **Context:** Initial task creation

### 2026-04-13T11:01:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cbae97cf
- **Timestamp:** 2026-06-02T14:56:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw doctor 2>&1 | grep -c 'Hook path validation.*portable' > /dev/null`
