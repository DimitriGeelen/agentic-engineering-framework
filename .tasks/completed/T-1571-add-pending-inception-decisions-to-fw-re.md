---
id: T-1571
name: "Add pending inception decisions to fw review-queue (F5 from T-1565 audit)"
description: >
  Add pending inception decisions to fw review-queue (F5 from T-1565 audit)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-27T21:38:10Z
last_update: 2026-04-27T21:41:10Z
date_finished: 2026-04-27T21:41:10Z
---

# T-1571: Add pending inception decisions to fw review-queue (F5 from T-1565 audit)

## Context

F5 from the T-1565 approval-arc audit. `fw review-queue` is documented at
`bin/fw:3343` as "terminal mirror of Watchtower /approvals" but only lists
tasks with unchecked Human ACs. /approvals' `Decisions` section also includes
`pending_go` (inception decisions awaiting GO/NO-GO), which the CLI silently
omits — same class of bug as T-1559 (asymmetric surface).

Adding a DECISIONS section before the VERDICT table closes the gap.

## Acceptance Criteria

### Agent
- [x] `fw review-queue` includes a DECISIONS table listing active inception
      tasks where `_extract_decision(body) == "pending"` (mirrors /approvals'
      `_load_pending_go_decisions` filter, with the same F4 inclusion rule:
      started-work without recommendation visible).
- [x] DECISIONS table renders before the VERDICT table; same column format.
- [x] Empty DECISIONS section is omitted entirely.
- [x] No regression: VERDICT table renders unchanged. Live verification: 3
      DECISIONS (T-1538 GO, T-1544 GO, T-1565 ?) + 46 VERDICT rows.
- [x] `fw review-queue --help` text mentions both DECISIONS and VERDICT.

## Verification

bin/fw review-queue 2>&1 | grep -q "DECISIONS" && echo decisions-section-rendered
bin/fw review-queue 2>&1 | grep -q "VERDICT" && echo verdict-section-rendered
bin/fw review-queue 2>&1 | grep -q "T-1565" && echo audit-task-listed
bin/fw review-queue --help 2>&1 | grep -qi "decision" && echo help-mentions-decisions

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Recommendation

**Recommendation:** GO

**Rationale:** F5 closes the asymmetric-surface bug (same class as T-1559).
The CLI now mirrors /approvals' Decisions section. The two passes share a
single frontmatter parse for efficiency.

**Evidence:**
- `bin/fw review-queue` now shows DECISIONS (3) before VERDICT (46) on the
  live corpus. Empty DECISIONS section correctly omitted on test paths.
- `fw review-queue --help` documents both sections.
- F4 inclusion rule (T-1570) honoured: started-work inceptions without
  Recommendation surface as `?` in DECISIONS.

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

### 2026-04-27T21:38:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1571-add-pending-inception-decisions-to-fw-re.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d01a7865
- **Timestamp:** 2026-06-02T14:58:23Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw review-queue 2>&1 | grep -q "DECISIONS" && echo decisions-section-rendered`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw review-queue 2>&1 | grep -q "VERDICT" && echo verdict-section-rendered`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw review-queue 2>&1 | grep -q "T-1565" && echo audit-task-listed`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw review-queue --help 2>&1 | grep -qi "decision" && echo help-mentions-decisions`
### 2026-04-27T21:41:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** F5 implemented and verified live
