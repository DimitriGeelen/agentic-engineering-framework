---
id: T-1269
name: "Monitor termlink hub + Claude instance liveness via cron (1-min + startup)"
description: >
  Build: cron job that pings termlink hub and running claude instance every 1 min
  and on startup, logs results for observability

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/monitor/liveness-check.sh]
related_tasks: []
created: 2026-04-15T21:19:51Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-15T21:25:38Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1269: Monitor termlink hub + Claude instance liveness via cron (1-min + startup)

## Context

Operator wants 1-min cadence liveness signals for: (a) TermLink hub, (b) Claude Code instance count, (c) Watchtower. Also triggered on boot. Output goes to `.context/monitors/` as append-only JSONL + latest YAML snapshot.

## Acceptance Criteria

### Agent
- [x] `agents/monitor/liveness-check.sh` exists, executable, runs without error
- [x] Outputs append to `.context/monitors/liveness.jsonl` (one JSON object per run)
- [x] Writes snapshot to `.context/monitors/liveness-latest.yaml` with termlink.hub, claude_instances, watchtower fields
- [x] Registered in `.context/cron-registry.yaml` as `liveness-1m` (schedule `* * * * *`) and `liveness-boot` (schedule `@reboot`)
- [x] `fw cron generate` regenerates `.context/cron/agentic-audit.crontab` with both entries
- [x] Dry-run of the script produces valid JSONL (jq parseable) and valid YAML (yaml.safe_load)
- [x] Retention: file caps at 10080 lines (~1 week at 1-per-min)
- [x] Installed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw cron install` — verified entries present

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-15T21:19:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1269-monitor-termlink-hub--claude-instance-li.md
- **Context:** Initial task creation

### 2026-04-15T21:25:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-664e414d
- **Timestamp:** 2026-06-02T14:56:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/monitor/liveness-check.sh` exists, executable, runs without error
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/monitor/liveness-check.sh in: `agents/monitor/liveness-check.sh` exists, executable, runs without error`
- **AC#2 (Agent)** — Outputs append to `.context/monitors/liveness.jsonl` (one JSON object per run)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/monitors/liveness.jsonl in: Outputs append to `.context/monitors/liveness.jsonl` (one JSON object per run)`
- **AC#3 (Agent)** — Writes snapshot to `.context/monitors/liveness-latest.yaml` with termlink.hub, claude_instances, watchtower fields
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/monitors/liveness-latest.yaml in: Writes snapshot to `.context/monitors/liveness-latest.yaml` with termlink.hub, claude_instances, watchtower fields`
- **AC#4 (Agent)** — Registered in `.context/cron-registry.yaml` as `liveness-1m` (schedule `* * * * *`) and `liveness-boot` (schedule `@reboot`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/cron-registry.yaml in: Registered in `.context/cron-registry.yaml` as `liveness-1m` (schedule `* * * * *`) and `liveness-boot` (schedule `@reboot`)`
- **AC#8 (Agent)** — Installed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw cron install` — verified entries present
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: Installed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw cron install` — verified entries present`
