---
id: T-1596
name: "Hygiene — vendor sync + cron install + CLAUDE.md mirror entry (T-1594/T-1595 follow-up)"
description: >
  Hygiene — vendor sync + cron install + CLAUDE.md mirror entry (T-1594/T-1595 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-28T22:30:06Z
last_update: 2026-04-28T22:36:51Z
date_finished: 2026-04-28T22:36:51Z
---

# T-1596: Hygiene — vendor sync + cron install + CLAUDE.md mirror entry (T-1594/T-1595 follow-up)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/` synced with current source (`fw doctor` reports no vendored-source drift) — verified
- [x] Cron registry installed to system crontab so `mirror-sync-15m` is active (no cron registry drift / flock parity warning) — `fw cron install` (not `fw audit schedule install` which uses a stale template) deployed 10 flock-wrapped entries including mirror-sync-15m
- [x] CLAUDE.md Quick Reference lists `fw mirror sync|status` so consumers know about the new subcommand (no doc drift) — verified

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

# All three hygiene warnings should be gone from `fw doctor`
bin/fw doctor 2>&1 | grep -qv "Vendored-source drift" || (bin/fw doctor 2>&1 | grep "Vendored-source drift" && exit 1) ; bin/fw doctor 2>&1 | grep -qE "Vendored-source drift" && exit 1 || true
bin/fw doctor 2>&1 | grep -qE "Cron registry drift" && exit 1 || true
bin/fw doctor 2>&1 | grep -qE "Cron flock parity" && exit 1 || true
bin/fw doctor 2>&1 | grep -qE "Doc drift.*mirror" && exit 1 || true
# Mirror entry actually deployed
grep -q "mirror-sync-15m" /etc/cron.d/agentic-audit-999-agentic-engineering-framework
# CLAUDE.md has the new line
grep -q "fw mirror sync|status" CLAUDE.md

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

### 2026-04-28T22:30:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1596-hygiene--vendor-sync--cron-install--clau.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-ccb6de4e
- **Timestamp:** 2026-04-28T22:39:52Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **swallowed-errors** (severe, deterministic) @ Verification:line 2
     - evidence: `bin/fw doctor 2>&1 | grep -qv "Vendored-source drift" || (bin/fw doctor 2>&1 | grep "Vendored-source drift" && exit 1) ; bin/fw doctor 2>&1 | grep -qE "Vendored-source drift" && exit 1 || true`
  2. **swallowed-errors** (severe, deterministic) @ Verification:line 3
     - evidence: `bin/fw doctor 2>&1 | grep -qE "Cron registry drift" && exit 1 || true`
  3. **swallowed-errors** (severe, deterministic) @ Verification:line 4
     - evidence: `bin/fw doctor 2>&1 | grep -qE "Cron flock parity" && exit 1 || true`
  4. **swallowed-errors** (severe, deterministic) @ Verification:line 5
     - evidence: `bin/fw doctor 2>&1 | grep -qE "Doc drift.*mirror" && exit 1 || true`

### 2026-04-28T22:36:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
