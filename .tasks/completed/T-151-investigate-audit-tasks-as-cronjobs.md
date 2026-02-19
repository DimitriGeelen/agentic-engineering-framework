---
id: T-151
name: "Investigate audit tasks as cronjobs"
description: >
  There are a number of other tasks that we currently idly mainly trigger or should be at the end of a session or start of session which actually isn't also not always reliably happens. So I have a thought that it would be a good possibility to have contracts. Running that for instance, regularly check check task quality or commit quality, another quality criteria standards that we have set if they are adhered to and then report out when they have findings. And this report is always checked at the end or a beginning of a session. So I want to explore that more in detail and also identify which. Enforcement rules or quality requirements, We would be good candidates for all the rents per Chrome job.

status: work-completed
workflow_type: specification
owner: human
horizon: later
tags: []
related_tasks: []
created: 2026-02-18T12:05:00Z
last_update: 2026-02-19T20:57:11Z
date_finished: 2026-02-19T20:57:11Z
---

# T-151: Investigate audit tasks as cronjobs

## Context

Quality checks currently rely on session-start/end discipline (agent remembers to run `fw audit`). This is unreliable. Investigate using scheduled background jobs (cron-style) to run quality checks independently, producing reports that sessions consume.

## Acceptance Criteria

- [x] Inventory of existing quality checks and their current trigger mechanisms
- [x] Analysis of which checks are good cron candidates vs session-only
- [x] Proposed scheduling model (frequencies, report format, consumption pattern)
- [x] Recommendation: go/no-go with rationale

## Verification

# Investigation output exists in task body
grep -q "Cron Candidate Analysis" /opt/999-Agentic-Engineering-Framework/.tasks/active/T-151-investigate-audit-tasks-as-cronjobs.md

## Investigation Findings

### Current Quality Check Inventory

| Check | What it does | Current trigger | Reliable? |
|-------|-------------|-----------------|-----------|
| `fw audit` (9 sections) | Task compliance, git traceability, enforcement, learning capture, episodic completeness, observation inbox, gaps register, graduation pipeline | Agent runs manually at session start/end | No — often skipped |
| `check-active-task.sh` | Blocks Write/Edit without task focus | PreToolUse hook (automatic) | Yes |
| `check-tier0.sh` | Blocks destructive Bash commands | PreToolUse hook (automatic) | Yes |
| `budget-gate.sh` | Token monitoring + blocks at critical | PreToolUse hook (automatic) | Yes |
| `checkpoint.sh` | Tool counter + auto-handover at critical | PostToolUse hook (automatic) | Yes |
| `error-watchdog.sh` | Detects Bash errors | PostToolUse hook (automatic) | Yes |
| Web `/api/audit/run` | Runs audit, shows in Watchtower | Manual web button | No — rarely used |
| Web `/api/tests/run` | Runs pytest | Manual web button | No — rarely used |

**Key insight:** Hook-based enforcement (PreToolUse/PostToolUse) is 100% reliable. Manual checks (`fw audit`, web buttons) are unreliable because they depend on agent discipline.

### Cron Candidate Analysis

**Good cron candidates** (stateless, file-based, no session context needed):

| Check | Frequency | Why |
|-------|-----------|-----|
| Task quality (fields, placeholders, stale tasks) | Every 30min | Catches decay between sessions |
| Git traceability % | Every 1h | Trend monitoring |
| Episodic completeness | Every 1h | Catches missed episodics |
| Observation inbox staleness | Every 6h | Time-sensitive by nature |
| Gaps register triggers | Every 6h | Condition thresholds |
| Graduation pipeline | Daily | Slow-moving metric |
| YAML/file integrity | Every 30min | Catches corruption early |

**Poor cron candidates** (need session context):

| Check | Why not cron |
|-------|-------------|
| Active task enforcement | Only meaningful during editing (hook-based) |
| Token budget monitoring | Per-session, per-conversation (hook-based) |
| Tier 0 destructive command blocking | Real-time only (hook-based) |
| Error watchdog | Real-time only (hook-based) |

### Proposed Scheduling Model

**Implementation: `fw audit --daemon` or systemd timer**

```
# /etc/cron.d/agentic-framework-audit (or systemd .timer units)
*/30 * * * *  fw audit --section structure,quality,integrity --output .context/audits/cron/
0    * * * *  fw audit --section traceability,episodic --output .context/audits/cron/
0  */6 * * *  fw audit --section observations,gaps --output .context/audits/cron/
0    8 * * *  fw audit --full --output .context/audits/cron/
```

**Report format:** Write to `.context/audits/cron/YYYY-MM-DD-HHMM.yaml` with same schema as current audit output. A `LATEST-CRON.yaml` symlink points to most recent.

**Session consumption pattern:**
1. `fw context init` reads `LATEST-CRON.yaml` and displays summary
2. Handover agent includes cron audit findings in handover
3. Watchtower quality page shows both manual and cron audit results

### Technical Considerations

1. **No new dependencies** — cron/systemd timers are standard Linux tooling
2. **Audit already supports sectional execution** — `audit.sh` is structured in numbered sections; adding `--section` flag is straightforward
3. **Idempotent** — audit reads filesystem state, doesn't mutate; safe to run any time
4. **Report accumulation** — need a retention policy (keep last 7 days of cron audits, auto-prune)

### Recommendation: GO

**Rationale:** The framework already has a comprehensive audit system (`audit.sh` with 9 sections). The only gap is *when* it runs — currently relying on agent discipline, which is unreliable. Cron scheduling is a mechanical fix for a mechanical problem (D1: Antifragility — system shouldn't depend on agent remembering to audit itself).

**Minimal viable implementation:**
1. Add `--section` and `--output` flags to `audit.sh` (~30 lines)
2. Create `fw audit schedule` command to install/manage cron entries
3. Modify `fw context init` to read and display cron audit findings
4. Add cron audit results to Watchtower quality page

**Estimated effort:** 1 build task, ~2-3 hours

## Decisions

### 2026-02-19 — Scheduling mechanism
- **Chose:** System cron / systemd timers
- **Why:** Zero dependencies, battle-tested, works when no Claude session is active
- **Rejected:** In-process scheduling (APScheduler/celery) — adds dependencies, only runs when app is up; file-watcher based — overcomplicated for periodic checks

## Updates

### 2026-02-18T12:05:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-151-investigate-audit-tasks-as-cronjobs.md
- **Context:** Initial task creation

### 2026-02-18T12:05:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T13:37:54Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-02-18T13:38:12Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-02-18T23:22:43Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-02-19T00:27:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T00:29:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-02-19T15:49:57Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-02-19T20:57:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
