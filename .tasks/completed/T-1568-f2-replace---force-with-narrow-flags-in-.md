---
id: T-1568
name: "F2: Replace --force with narrow flags in Watchtower complete-task endpoints (RCA + Recommendation gate bypass fix)"
description: >
  F2: Replace --force with narrow flags in Watchtower complete-task endpoints (RCA + Recommendation gate bypass fix)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T21:02:49Z
last_update: 2026-04-27T21:04:23Z
date_finished: 2026-04-27T21:04:23Z
---

# T-1568: F2: Replace --force with narrow flags in Watchtower complete-task endpoints (RCA + Recommendation gate bypass fix)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `web/blueprints/tasks.py:676` (`/api/task/<id>/complete`): replace `--force` with `--skip-sovereignty --skip-verification`. Rationale: human clicked from /tasks page → sovereignty bypass justified; UI has no shell context for verification commands. Recommendation + RCA gates MUST fire (they enforce missing artefacts, not authorization).
- [x] `web/blueprints/approvals.py:529` (`/api/approvals/complete-batch`): same replacement plus `--skip-acceptance-criteria` (the batch endpoint operates on partial-complete tasks where the human is explicitly authorising closure regardless of unchecked Human ACs — same auth-flag pattern T-1559 fixed).
- [x] No remaining `"--force"` literal strings in web/ source. (grep audit.)
- [x] python3 syntax-check both files parse.

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

grep -rn '"--force"' web/blueprints/ && exit 1 || echo "OK no --force literals"
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"

## RCA

**Symptom:** Human clicking "Complete Task" or "Complete Batch" in Watchtower UI completed bug-class tasks without ever firing the RCA gate (T-1550, G-019 structural fix) or the Recommendation gate (T-679/T-1529). Surfaced by T-1565 audit (F2, severity HIGH).

**Root cause:** Both UI endpoints invoked `fw task update --status work-completed --force ...`. `--force` is documented in `update-task.sh:435-443` as deprecated; it sets EVERY `--skip-*` flag at once including `--skip-recommendation` and `--skip-rca`. So the very gates the framework was hardened to enforce got bypassed by the well-named "Complete Task" button.

**Why structurally allowed:** The UI endpoints predate the granular --skip-* flags. When `--force` was added (T-640, "human clicked it") only sovereignty and AC gates existed. T-1529 (Recommendation gate) and T-1550 (RCA gate) added new gates but the UI plumbing was never re-audited. No regression test verified UI completion paths fired the same gates as CLI completion. The bypass log entry shows only `--force`, not the implicit list of gates skipped — invisible.

**Prevention:**
- Verification command (this task) `grep -rn '"--force"' web/blueprints/` exits non-zero if anyone re-introduces the literal — runs on every completion via P-011.
- L-308 captured: "When deprecating an aggregate flag (`--force` = all skips), audit ALL callers — UI/API/cron — for replacements; aggregate flags hide gate semantics from later gates added independently."

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

### 2026-04-27T21:02:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1568-f2-replace---force-with-narrow-flags-in-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-4ba7ba0b
- **Timestamp:** 2026-04-27T21:04:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-27T21:04:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
