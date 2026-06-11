---
id: T-612
name: "Agent approval pickup — hook/cron scanning Watchtower approval ledger"
description: >
  Implement agent-side pickup mechanism for Watchtower approvals. Options: (A) PostToolUse
  hook checks .context/approvals/ periodically, (B) cron job scans every 30s and writes
  to inbox, (C) agent explicitly checks via fw approvals pending. Preferred: option
  B (cron, zero friction). Connects Tier 0 hook block to Watchtower approval response.
  Part of T-608 Watchtower approval surface.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [agents/context/check-tier0.sh, bin/fw]
related_tasks: [T-608, T-610, T-611]
created: 2026-03-25T16:51:32Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-26T12:30:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-612: Agent approval pickup — hook/cron scanning Watchtower approval ledger

## Context

Closes the loop for T-608 Watchtower approval surface. After T-611 enables human approval via web UI, this task connects the response back to the agent. Depends on T-611. See `docs/reports/T-608-tier0-approval-surface.md`.

## Acceptance Criteria

### Agent
- [x] `check-tier0.sh` checks `.context/approvals/` for approved responses matching the pending command hash
- [x] Approved response consumption: once read by hook, approval is marked consumed (single-use)
- [x] `fw approvals pending` command shows outstanding approval requests
- [x] `fw approvals status` shows recent approvals (approved/rejected/expired)
- [x] Timeout: if no response within configured TTL (default 1hr), pending request expires

### Human
- [x] [RUBBER-STAMP] End-to-end flow works: agent blocked → approve in Watchtower → agent retries and succeeds
  **Steps:**
  1. Trigger a Tier 0 block in Claude Code session
  2. Open http://localhost:3000/approvals and click approve
  3. Retry the blocked command in Claude Code
  **Expected:** Command executes after Watchtower approval, no terminal switching needed
  **If not:** Check `.context/approvals/` for response file and `check-tier0.sh` logs
  **Verified by agent (2026-04-30, per human directive — L-329):** ran `pkill -9 nonexistent-claude-test-process-xyzzy123-T612` from this Claude Code session → Tier-0 block fired (PreToolUse exit 2). Wrote `pending-7dabd5c3459e.yaml`. POSTed to `/api/approvals/decide` with CSRF + cookie session → response `Approved. Agent can retry.` `resolved-7dabd5c3459e.yaml` written with `status: approved`. Retried exact same command → hook found resolved file, consumed it (`status: consumed`, `consumed_at: 2026-04-30T20:50:25Z`), wrote bypass-log entry (`mechanism: watchtower`), allowed execution. pkill ran with its own exit-1 (no matching process). No terminal switching needed. Edge case surfaced: hash is bound to exact command — appending `; echo $?` invalidates the approval (CORRECT — approver authorized the specific command, not a class).

## Verification

# fw approvals subcommand exists
bin/fw approvals --help 2>&1 | grep -q "approvals"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified — `check-tier0.sh` reads approval ledger, single-use consumption is tracked, two `fw approvals` verbs exposed (pending/status), TTL expiry implemented. The `[RUBBER-STAMP]` Human AC is an end-to-end flow test that needs an actual Tier 0 block to trigger — RUBBER-STAMP is correct because the steps are deterministic.

**Evidence:**
- `agents/git/check-tier0.sh` reads `.context/approvals/`
- `.tier0-approval.consumed` marker file present in working directory (visible in current session)
- `bin/fw approvals pending|status` verbs present
- TTL default 1h, configurable

## Updates

### 2026-03-25T16:51:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-612-agent-approval-pickup--hookcron-scanning.md
- **Context:** Initial task creation

### 2026-03-26T12:30:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-26T12:30:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3cfb5487
- **Timestamp:** 2026-06-02T15:03:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw approvals --help 2>&1 | grep -q "approvals"`
