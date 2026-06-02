---
id: T-824
name: "fw verify-acs CLI — automated Human AC evidence collection for stale tasks"
description: >
  fw verify-acs CLI — automated Human AC evidence collection for stale tasks

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-03T23:11:43Z
last_update: 2026-04-03T23:18:53Z
date_finished: 2026-04-03T23:18:53Z
---

# T-824: fw verify-acs CLI — automated Human AC evidence collection for stale tasks

## Context

Build task from T-823 GO decision. Creates `fw verify-acs` command that runs automated verification of RUBBER-STAMP Human ACs on stale tasks, collects evidence, and presents results for human batch approval.

## Acceptance Criteria

### Agent
- [x] `fw verify-acs` command exists and runs without errors
- [x] Scans all work-completed tasks with unchecked Human ACs
- [x] Identifies RUBBER-STAMP vs REVIEW ACs
- [x] Runs HTTP checks for Watchtower-related ACs (page loads, elements present)
- [x] Runs shell command checks for CLI-related ACs
- [x] Outputs per-task PASS/FAIL/SKIP with evidence
- [x] Shows summary with counts and Watchtower review links
- [x] Added to CLAUDE.md quick reference table
- [x] Unit tests for verification logic (6 bats tests)

### Human
- [x] [RUBBER-STAMP] Run `fw verify-acs` and verify output makes sense
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw verify-acs`
  2. Verify it finds stale tasks and runs checks
  3. Verify PASS/FAIL/SKIP results have clear evidence
  **Expected:** Output shows tasks with verification results and Watchtower links
  **If not:** Note which checks produce incorrect results

## Verification

bin/fw verify-acs --help 2>&1 | grep -q "verify"
bin/fw verify-acs 2>&1 | grep -qE "PASS|SKIP|FAIL|verified"

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

### 2026-04-03T23:11:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-824-fw-verify-acs-cli--automated-human-ac-ev.md
- **Context:** Initial task creation

### 2026-04-03T23:18:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-32199211
- **Timestamp:** 2026-06-02T15:05:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw verify-acs --help 2>&1 | grep -q "verify"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw verify-acs 2>&1 | grep -qE "PASS|SKIP|FAIL|verified"`
