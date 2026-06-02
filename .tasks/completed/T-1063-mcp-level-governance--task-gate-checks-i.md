---
id: T-1063
name: "MCP-level governance — task-gate checks in TermLink MCP tools"
description: >
  Phase 2 from T-1061: Add task-gate checks to TermLink MCP tools (termlink_exec, termlink_spawn, termlink_dispatch) so cross-session operations are governed. Structured, reliable, blockable. 2-4 weeks.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [termlink, governance, mcp]
components: [agents/context/lib/focus.sh, agents/termlink/termlink.sh]
related_tasks: [T-1061]
created: 2026-04-08T05:32:10Z
last_update: 2026-04-24T09:15:08Z
date_finished: 2026-04-24T09:15:08Z
---

# T-1063: MCP-level governance — task-gate checks in TermLink MCP tools

## Context

Phase 2 from T-1061 inception (GO). Add task-gate governance checks to TermLink's MCP tools so cross-session operations are governed at the structured API level. When an agent calls `termlink_exec`, `termlink_spawn`, or `termlink_dispatch` via MCP, TermLink checks for an active task context before executing. Research: `docs/reports/T-1061-termlink-governance-substrate.md`, `docs/reports/T-1061-termlink-review-feedback.md`.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-mcp/src/tools.rs`
**Dispatch:** This task should be executed in the TermLink project via `fw termlink dispatch`

## Acceptance Criteria

### Agent
- [x] MCP tools `termlink_exec`, `termlink_spawn`, `termlink_dispatch` accept optional `task_id` parameter
- [x] When task governance is enabled (env var or config), tools without `task_id` return structured error
- [x] Governance mode is opt-in (default: no enforcement) to avoid breaking existing usage
- [x] Task context passed through to session tags for observability
- [x] Existing tests still pass (`cargo test`)
- [x] New tests for governance gate: with task_id passes, without task_id in strict mode fails
- [x] `termlink_interact` also governed (bonus — 4 tools total)

### Human
- [x] [REVIEW] Governance integration design review — opt-in model is appropriate, error messages are actionable
  **Steps:**
  1. Read the implementation PR/diff in the TermLink repo
  2. Check that opt-in mechanism is clean (env var or config, not hardcoded)
  3. Verify error messages tell the agent what to do (not just "denied")
  **Expected:** Clean opt-in design, actionable errors, no breaking changes
  **If not:** Note specific concerns for revision

## Verification

# Verification runs in /opt/termlink, not here
# cd /opt/termlink && cargo test
# cd /opt/termlink && cargo build

## Recommendation

**Recommendation:** Agent ACs complete — ready for human design review
**Rationale:** TermLink dispatch worker (T-902 in /opt/termlink) successfully implemented MCP task governance. 16 new tests added, all 174 pass. Opt-in via `TERMLINK_TASK_GOVERNANCE=1`, backward compatible, actionable error messages.
**Evidence:**
- Worker exit code: 0
- Tests: 76 unit + 98 integration = 174 pass (16 new)
- Report: `/opt/termlink/docs/reports/T-902-mcp-governance.md`
- 4 tools governed: termlink_exec, termlink_spawn, termlink_interact, termlink_dispatch
- Task IDs propagate to session tags as `task:<id>`

## Decisions

### 2026-04-08 — Governance activation mechanism
- **Chose:** Environment variable `TERMLINK_TASK_GOVERNANCE=1`
- **Why:** Env vars are standard, no config file dependency, easy to set per-session or globally
- **Rejected:** Config file (adds TermLink config schema dependency), always-on (breaks existing usage)

## Updates

### 2026-04-08T05:32:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1063-mcp-level-governance--task-gate-checks-i.md
- **Context:** Initial task creation

### 2026-04-08T05:51:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T10:42:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-24T09:15:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-197f979c
- **Timestamp:** 2026-06-02T14:54:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
