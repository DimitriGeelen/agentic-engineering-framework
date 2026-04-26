---
id: T-1508
name: "T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered fix a+b)"
description: >
  T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered fix a+b)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-26T11:38:01Z
last_update: 2026-04-26T11:38:01Z
date_finished: null
---

# T-1508: T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered fix a+b)

## Context

Implements T-1506 GO decision (recorded 2026-04-26T11:32:42Z). Two layers:

**Layer (b) — Tier 0 idempotency sentinel (`agents/context/check-tier0.sh`):**
On approval consumption, write `${APPROVAL_FILE}.consumed` with the consumed
hash + timestamp. Before blocking on missing approval, check `.consumed`: if
same hash + age < 5s, allow without re-blocking. Catches duplicate hook
firings within the same Bash invocation; expires fast enough that the next
legitimate command still requires a fresh approval.

**Layer (a) — Install-time + doctor dedup (`lib/hooks_dedup.sh` + wiring):**
Scan `.claude/settings.json` (project) + `~/.claude/settings.json` (user).
For each PreToolUse/PostToolUse hook with the SAME final command name (e.g.
`check-tier0`), keep the project entry and remove the user-side duplicate.
Wire into `fw doctor` (warn) and provide `fw upgrade --dedupe-hooks` (fix).

## Acceptance Criteria

### Agent
- [ ] `agents/context/check-tier0.sh` writes `${APPROVAL_FILE}.consumed` (hash + timestamp) on consumption AND short-circuits to allow when a matching `.consumed` sentinel exists with age < 5s for the same hash
- [ ] Bats test: simulate two-call sequence (approve → invoke twice) and assert both invocations exit 0; second call must not write a new `.pending`
- [ ] Bats test: sentinel expires — after 5s, second invocation BLOCKS as if no approval (sentinel must not silently re-allow stale approvals)
- [ ] `lib/hooks_dedup.sh` exposes `fw_hooks_audit` (read-only, returns duplicate hook table) and `fw_hooks_dedupe` (mutating, removes user-side duplicates of project-side hooks)
- [ ] `fw doctor` warns when duplicate hook registrations are detected, with mitigation `fw upgrade --dedupe-hooks`
- [ ] `fw upgrade --dedupe-hooks` invokes `fw_hooks_dedupe` and reports the count removed
- [ ] Bats test: synthesize two settings.json files with overlapping hooks → audit reports correct duplicates → dedupe removes user-side entries → re-audit reports zero duplicates
- [ ] All existing unit + bats tests still pass (no regression in tier0 single-fire behavior or fw doctor output)

## Verification

bash -n agents/context/check-tier0.sh
bash -n lib/hooks_dedup.sh
bats --filter "tier0_idempotency" tests/unit/
bats --filter "hooks_dedup" tests/unit/

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

### 2026-04-26T11:38:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1508-t-1506-build--tier-0-idempotency-sentine.md
- **Context:** Initial task creation
