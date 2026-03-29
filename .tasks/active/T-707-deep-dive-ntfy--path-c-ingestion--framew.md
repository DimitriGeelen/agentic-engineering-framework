---
id: T-707
name: "Deep-dive: ntfy — Path C ingestion + framework notification enhancement"
description: >
  Path C deep-dive on github.com/binwiederhier/ntfy (push notification service). Two deliverables: (1) Ingest codebase, harvest patterns, score against D1-D4. (2) Build natural enhancement — wire ntfy into framework notification surface (Tier 0 approvals, task completions, audit alerts). Third Path C experiment validating template.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [path-c, deep-dive, external, ntfy, notifications]
components: []
related_tasks: [T-696, T-697, T-698]
created: 2026-03-29T09:52:55Z
last_update: 2026-03-29T09:52:55Z
date_finished: null
---

# T-707: Deep-dive: ntfy — Path C ingestion + framework notification enhancement

## Problem Statement

The framework has no push notification channel. When a Tier 0 approval is needed, the agent prints a message and waits. When a task completes, it's visible only in the terminal. When an audit fires warnings, they go to a log file. The human discovers these events only when they look.

ntfy (`github.com/binwiederhier/ntfy`) is a simple HTTP-based pub/sub notification service — `curl -d "message" ntfy.sh/topic`. It supports mobile push, desktop notifications, and webhooks. Self-hostable, no account needed.

**Two deliverables:**
1. Path C deep-dive — ingest ntfy codebase, harvest patterns, score against D1-D4
2. Enhancement design — identify where ntfy notifications plug into the framework (hooks, Watchtower, CLI)

**Source:** https://github.com/binwiederhier/ntfy
**Clone target:** /opt/053-ntfy

## Key Rules

1. Never cd into the target from framework session
2. Never analyze target code from framework session
3. Always use TermLink for cross-project commands
4. TermLink session cd's INTO the consumer project
5. Keep original project hooks as `.pre-fw`
6. Framework hooks must be applied
7. Human must approve before writes to external project (L-117)
8. Friction points become framework tasks

## Phase 1: Setup (FROM framework project)

- [x] Pick directory number: 053
- [x] Verify clone target doesn't exist
- [x] Verify TermLink installed: termlink 0.9.33
- [x] Clone target repo to /opt/053-ntfy
- [x] Spawn TermLink session: ntfy-dive
- [x] cd into target inside TermLink
- [x] Set git identity in TermLink session
- [x] Init framework governance: 36/40 checks OK
- [x] Verify doctor: 0 failures, 3 warnings
- [x] Verify framework hooks: configured
- [x] Verify seed tasks: 6 tasks (existing project mode, T-001 through T-006)

## Phase 2: Execute (INSIDE target project via TermLink)

- [x] Dispatch worker: `fw termlink dispatch --name ntfy-worker --task T-707`
- [ ] Worker completed but result.md was 0 bytes — check /tmp/tl-dispatch/ntfy-worker/ and /tmp/fw-agent-ntfy-worker.md next session
- [ ] Seed tasks NOT completed — all 6 still in .tasks/active/
- [ ] Run `fw doctor` — expect 0 failures
- [ ] Run `fw audit` — expect majority PASS

**Friction log:**

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|

## Phase 3: Harvest + Enhancement Design (BACK in framework project)

- [ ] Read target project findings via TermLink
- [ ] Dispatch 5 discovery agents (patterns, API design, notification UX, self-hosting, Go patterns)
- [ ] Score patterns against D1-D4
- [ ] Create research artifact: `docs/reports/T-707-ntfy-deep-dive.md`
- [ ] Design enhancement: which framework events → ntfy notifications
- [ ] Identify integration points (checkpoint.sh, Watchtower, fw CLI)
- [ ] Record learnings
- [ ] Cleanup TermLink sessions

## Acceptance Criteria

### Agent
- [ ] Phase 1 complete — framework governance initialized in ntfy project
- [ ] Phase 2 complete — seed tasks executed, friction points logged
- [ ] Phase 3 complete — patterns harvested, enhancement designed
- [ ] Research artifact written with scored patterns
- [ ] Enhancement integration points identified
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review deep-dive findings and enhancement design
  **Steps:**
  1. Read `docs/reports/T-707-ntfy-deep-dive.md`
  2. Evaluate enhancement design — does ntfy integration make sense?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-707 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, enhancement tasks created if GO
  **If not:** Note concerns about integration approach

## Go/No-Go Criteria

**GO if:**
- ntfy integration is simple (HTTP POST, no complex auth)
- Clear framework events that benefit from push notifications
- Self-hosting is straightforward (single binary or Docker)
- Enhancement is bounded (< 1 session to build)

**NO-GO if:**
- ntfy requires complex setup defeating the simplicity advantage
- Framework events don't map cleanly to notifications
- Existing Watchtower polling (htmx every 5-10s) is sufficient

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
