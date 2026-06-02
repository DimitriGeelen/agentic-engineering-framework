---
id: T-1769
name: "cron generate shape — bats fixture pinning generator output (T-1720 follow-up)"
description: >
  cron generate shape — bats fixture pinning generator output (T-1720 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: ["cron", "T-1720-followup", "regression-test", "structural-fix"]
components: [tests/unit/test_cron_generate_shape.bats]
related_tasks: ["T-1720", "T-1767", "T-1687"]
arc_id: orchestrator-rethink
created: 2026-05-06T16:19:39Z
last_update: 2026-05-06T16:23:47Z
date_finished: 2026-05-06T16:23:47Z
---

# T-1769: cron generate shape — bats fixture pinning generator output (T-1720 follow-up)

## Context

T-1720 found the cron generator produced unrunnable lines (`python3 -m lib.X` failed at HOME cwd) and swallowed errors via `2>/dev/null`. Reviewer audit was effectively dead 9 days. Generator shape is now load-bearing — pin it with bats so the next regression in either direction (cd dropped, logger swallowed, paused-job emitted active) is caught at test-time rather than 9 days later in production.

## Acceptance Criteria

### Agent
- [x] `tests/unit/test_cron_generate_shape.bats` exists with at least 6 cases covering: fw command shape, non-fw python3 shape, `2>/dev/null` rewrite, idempotent logger preservation, double-cd documentation, paused-job comment emission
- [x] All cases pass: `bats tests/unit/test_cron_generate_shape.bats` exits 0
- [x] Tests use isolated `TEST_PROJECT` temp dir (no mutation of real `.context/cron-registry.yaml`)
- [x] Each case asserts on the actual generated `.context/cron/agentic-audit.crontab` content, not just exit code (T-1700/T-1707 lesson — "tighten Verification — assert content, not just exit code")

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -f tests/unit/test_cron_generate_shape.bats
bats tests/unit/test_cron_generate_shape.bats
grep -q "T-1720" tests/unit/test_cron_generate_shape.bats

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

## Evolution

### 2026-05-06 — registry hygiene surfaced as a 6th pinned case
- **What changed:** While inspecting the deployed crontab to confirm T-1720's fix, I found the two escalation-scan registry entries had `cd /opt/...` baked into their `command:` field as a workaround predating T-1720. Generator now adds its own cd → double-cd. Idempotent but exactly the kind of regression a shape fixture should pin.
- **Plan impact:** Added a 6th test case ("registry leading-cd produces double-cd — documents current behavior") explicitly so a future "fix" that strips the user's leading-cd or doubles up cd silently is caught.
- **Triggered:** Registry cleanup commit `ea8c78d34` stripped the workaround from `cron-registry.yaml`. Generator behavior unchanged — registry hygiene is the canonical fix, generator stays simple.

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

### 2026-05-06T16:19:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1769-cron-generate-shape--bats-fixture-pinnin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6c1c438e
- **Timestamp:** 2026-06-02T14:59:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Tests use isolated `TEST_PROJECT` temp dir (no mutation of real `.context/cron-registry.yaml`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/cron-registry.yaml in: Tests use isolated `TEST_PROJECT` temp dir (no mutation of real `.context/cron-registry.yaml`)`
### 2026-05-06T16:23:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
